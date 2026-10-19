# mad-hatter-pipeline

The CI pipeline for `Wonderland/mad-hatter`, kept in its own repository and separate from the
application code.

Keeping the `Jenkinsfile` here — not in the application repo — means application developers cannot
change the pipeline. The pipeline checks out the application at the branch under test and runs its
`make` build with Wonderland's release token available to the build.

This repository is change-controlled: `main` is protected and pull requests require review. Only
the CI service account and the platform team have access.
