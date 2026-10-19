#!/bin/sh
# Isoloom `setup` step for the Gitea machine (runs once, after Gitea is healthy, in the Gitea image,
# sharing its network namespace so Gitea is reachable at 127.0.0.1:3000). It provisions Wonderland's
# two repositories over the Gitea API and pushes the baked sample projects:
#   - Wonderland/mad-hatter           the APPLICATION (holds the Makefile): alice=WRITE, jenkins=read
#   - Wonderland/mad-hatter-pipeline  the PROTECTED pipeline (holds the Jenkinsfile): alice=read, jenkins=read
# alice is the attacker (write on the app, read-only on the pipeline), jenkins is the CI poller
# (read on both). No challenge secret is handled here; the flag is a Jenkins credential injected
# elsewhere.
set -eu

BASE="${GITEA_BASE_URL:-http://127.0.0.1:3000}"
ADMIN_USER="${GITEA_ADMIN_USER:-wonderland_admin}"
ADMIN_PASS="${GITEA_ADMIN_PASS:-W0nderland-admin}"
ORG="Wonderland"
APP_REPO="mad-hatter"
PIPE_REPO="mad-hatter-pipeline"
APP_SRC="${MH_APP_SRC:-/opt/mad-hatter-src}"
PIPE_SRC="${MH_PIPE_SRC:-/opt/mad-hatter-pipeline-src}"

ATTACKER_USER="alice"
ATTACKER_PASS="alice"
CI_USER="jenkins"
CI_PASS="jenkins"

AUTH="$ADMIN_USER:$ADMIN_PASS"
API="$BASE/api/v1"

log() { echo "seed: $1"; }

# POST/PUT JSON as admin; tolerate 'already exists' (409/422) so the job is idempotent on restart.
api() {  # method path json
  if [ -n "${3:-}" ]; then
    code=$(curl -s -o /tmp/seed.out -w '%{http_code}' -X "$1" \
           -H 'Content-Type: application/json' -u "$AUTH" \
           --data "$3" "$API$2" 2>/dev/null || echo 000)
  else
    code=$(curl -s -o /tmp/seed.out -w '%{http_code}' -X "$1" -u "$AUTH" "$API$2" 2>/dev/null || echo 000)
  fi
  case "$code" in
    2*) return 0 ;;
    409|422) log "exists ($code): $1 $2"; return 0 ;;
    *) log "WARN $code: $1 $2 -> $(tr -d '\n' < /tmp/seed.out | cut -c1-200)"; return 1 ;;
  esac
}

# push_repo REPO SRCDIR COMMIT-MESSAGE -> initialise SRCDIR as a git repo and push it to main.
push_repo() {
  repo="$1"; src="$2"; msg="$3"
  WORK="$(mktemp -d)"
  cp -a "$src/." "$WORK/"
  cd "$WORK"
  export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
  export GIT_AUTHOR_NAME="Wonderland Admin" GIT_AUTHOR_EMAIL="admin@wonderland.example"
  export GIT_COMMITTER_NAME="Wonderland Admin" GIT_COMMITTER_EMAIL="admin@wonderland.example"
  export GIT_AUTHOR_DATE="2024-05-04T18:00:00" GIT_COMMITTER_DATE="2024-05-04T18:00:00"
  git -c init.defaultBranch=main init -q
  git add -A
  git commit -q -m "$msg"
  git push -q "http://$ADMIN_USER:$ADMIN_PASS@127.0.0.1:3000/$ORG/$repo.git" main
  cd /
  rm -rf "$WORK"
}

# 1. Wait for the Gitea API.
i=0
while :; do
  c=$(curl -s -o /dev/null -w '%{http_code}' "$API/version" 2>/dev/null || echo 000)
  [ "$c" = "200" ] && break
  i=$((i+1)); [ "$i" -lt 120 ] || { log "FATAL: Gitea API never answered"; exit 1; }
  sleep 2
done
log "Gitea API is up"

# 2. Idempotency: if the application repo already has a main branch, everything below is already done.
c=$(curl -s -o /dev/null -w '%{http_code}' -u "$AUTH" "$API/repos/$ORG/$APP_REPO/branches/main" 2>/dev/null || echo 000)
if [ "$c" = "200" ]; then
  log "mad-hatter already seeded; nothing to do"
  exit 0
fi

# 3. Org, users, repositories.
api POST "/orgs" "{\"username\":\"$ORG\",\"visibility\":\"private\"}"
api POST "/admin/users" "{\"username\":\"$ATTACKER_USER\",\"email\":\"alice@wonderland.example\",\"password\":\"$ATTACKER_PASS\",\"must_change_password\":false}"
api POST "/admin/users" "{\"username\":\"$CI_USER\",\"email\":\"jenkins@wonderland.example\",\"password\":\"$CI_PASS\",\"must_change_password\":false}"
api POST "/orgs/$ORG/repos" "{\"name\":\"$APP_REPO\",\"private\":true,\"auto_init\":false,\"default_branch\":\"main\"}"
api POST "/orgs/$ORG/repos" "{\"name\":\"$PIPE_REPO\",\"private\":true,\"auto_init\":false,\"default_branch\":\"main\"}"

# 4. Access. The INDIRECT in I-PPE: alice writes the application (so she controls the Makefile) but
#    only reads the pipeline (so she cannot touch the Jenkinsfile). jenkins reads both (CI poller).
api PUT "/repos/$ORG/$APP_REPO/collaborators/$ATTACKER_USER"  "{\"permission\":\"write\"}"
api PUT "/repos/$ORG/$APP_REPO/collaborators/$CI_USER"        "{\"permission\":\"read\"}"
api PUT "/repos/$ORG/$PIPE_REPO/collaborators/$ATTACKER_USER" "{\"permission\":\"read\"}"
api PUT "/repos/$ORG/$PIPE_REPO/collaborators/$CI_USER"       "{\"permission\":\"read\"}"

# 5. Push the baked sample projects.
push_repo "$PIPE_REPO" "$PIPE_SRC" "Add the protected mad-hatter CI pipeline"
push_repo "$APP_REPO"  "$APP_SRC"  "Initial import of the teaparty package and its Makefile"

log "seeded: mad-hatter (alice=write, jenkins=read) + mad-hatter-pipeline (alice=read, jenkins=read)"
