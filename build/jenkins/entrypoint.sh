#!/bin/bash
# Wonderland Jenkins entrypoint. Stages the per-player flag into the directory JCasC reads file
# secrets from ($SECRETS), so the flag3 credential resolves at boot — WITHOUT the flag ever being an
# image layer, a spec value or a process environment variable (the pipeline must bind the credential
# to read it, which is the whole point of the challenge).
#
# Isoloom mounts the per-player input as a read-only file at /run/lab/secrets/flag3. When it is empty
# (an offline start — local, CI) the inert development placeholder is staged instead, so the lab
# still comes up and is solvable.
set -eu

DEV='mh-dev-flag-not-a-real-secret-0000'
SRC_FLAG='/run/lab/secrets/flag3'
SECRETS_DIR="${SECRETS:-/run/lab/casc_secrets}"

stage() {  # $1 = destination directory
  mkdir -p "$1"
  if [ -s "$SRC_FLAG" ]; then
    tr -d '\r\n' < "$SRC_FLAG" > "$1/flag3"
  else
    printf '%s' "$DEV" > "$1/flag3"
  fi
  chmod 0400 "$1/flag3"
}

stage "$SECRETS_DIR"
# Fallback: JCasC's Docker secret source defaults to /run/secrets when $SECRETS is unset.
stage /run/secrets 2>/dev/null || true

exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
