# Upstream

This lab reproduces one challenge — **Mad Hatter** — from CI/CD Goat.

| What | Source | Licence |
| --- | --- | --- |
| The "Mad Hatter" challenge (Indirect Poisoned Pipeline Execution: a protected pipeline runs a build script the attacker can modify) | [CI/CD Goat](https://github.com/cider-security-research/cicd-goat) by Cider Security (now Palo Alto Networks), v1.2.7 | Apache-2.0 |
| Security class | [OWASP CICD-SEC-4: Poisoned Pipeline Execution](https://owasp.org/www-project-top-10-ci-cd-security-risks/CICD-SEC-04-Poisoned-Pipeline-Execution) | — |

Only the *vulnerability* is reproduced, not upstream's eight-machine CI/CD stack. The lab is two
machines — a Jenkins controller and a Gitea git host — which is the minimum this attack needs: an
application repository the attacker can write, a *separate* pipeline repository they cannot, and a
pipeline that runs the application's build script (`make`) with a credential in scope.

Nothing is vendored from upstream. Upstream serves a copy of the `yagmail` project as the
`mad-hatter` application repository and bakes one fixed UUID flag into Jenkins. This lab instead
ships an **original** minimal sample package (`build/gitea/app-src/`, the `teaparty` package,
authored here, no third-party code) with an original `Makefile`, an original protected `Jenkinsfile`
(`build/gitea/pipeline-src/`), and injects a **per-player** flag into the Jenkins credential store
at run time, so each player exfiltrates their own flag and nothing but the challenge idea comes from
upstream.

## The attack is identical; three implementation choices differ

Upstream and this lab present the player with the same situation and the same solution: the
`Jenkinsfile` is in a repository you cannot modify, but it runs `make` against the application repo
you *can* modify, with `flag3` bound into the build — so you poison the **Makefile** to print the
flag, push a branch, and read the build console. Three mechanics are implemented differently, for a
lab family meant to run unattended.

### 1. The trigger (git multibranch instead of the Gitea plugin)

Upstream wires branch discovery with the Jenkins **Gitea** plugin and a periodic folder rescan. This
lab uses the Jenkins **git** plugin's multibranch source (branch discovery) with the same one-minute
periodic rescan (an SCM poll, no inbound webhook). The branch source is the **application** repo, so
a branch the attacker pushes there triggers the build — exactly as upstream. This drops a
Jenkins↔Gitea plugin version dependency for a version-robust git poll. (Same deviation as the White
Rabbit lab in this family.)

### 2. The Jenkinsfile still comes from the separate repo — and the checkout is explicit

The property that makes this *indirect* PPE — the `Jenkinsfile` living in a repository the attacker
cannot modify — is preserved exactly: the multibranch job uses the **Remote Jenkinsfile Provider**
(`remote-file`) to fetch the `Jenkinsfile` from `Wonderland/mad-hatter-pipeline`, never from the
application branch. Because the pipeline definition is then loaded from the pipeline repo, this lab's
`Jenkinsfile` sets `skipDefaultCheckout(true)` and **explicitly** clones the application repo at the
branch under test before running `make`, rather than relying on the implicit workspace checkout. The
player's experience is unchanged (poison the Makefile, push, read the console); the pipeline's
behaviour is deterministic regardless of plugin-version differences in implicit-checkout semantics.

### 3. The exfiltration encoding (a transform, to defeat masking)

Upstream's solution prints `echo "${FLAG}" | base64`, relying on base64 slipping past credential
masking. On the modern Jenkins this lab ships, the `credentials-binding` plugin masks a bound
secret's raw value **and its plain base64**, so that exact trick no longer works. The lab keeps the
vulnerability identical and only updates the encoding the attacker uses to one the masker does not
precompute — reversing before base64 (`echo "$FLAG" | rev | base64`). This is arguably a truer
lesson for current CI: masking is a best-effort guardrail, not a control, and a chosen transform
defeats it. (Same note as the White Rabbit lab.)
