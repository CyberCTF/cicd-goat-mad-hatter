// Seed job (run by Configuration-as-Code) that creates Wonderland's mad-hatter pipeline.
//
// This is what makes the attack INDIRECT. The multibranch pipeline's BRANCH SOURCE is the
// mad-hatter APPLICATION repository over git: branch discovery means every branch that is pushed
// gets its own pipeline, built when a periodic rescan (every minute — the SCM-poll trigger) finds
// it. An attacker with write access to the application repo can push a branch, so the attacker
// controls WHEN the pipeline runs and WHAT is in the application checkout (including the Makefile).
//
// But the Jenkinsfile is NOT read from the application repo. The Remote Jenkinsfile Provider
// (remote-file plugin) fetches it from the SEPARATE mad-hatter-pipeline repository, main branch,
// which the attacker can only read. So the pipeline definition is protected: a Direct-PPE (editing
// the Jenkinsfile) is impossible. The attacker's only lever is the build script the protected
// pipeline invokes — the application's Makefile.
multibranchPipelineJob('wonderland-mad-hatter') {
    displayName('Wonderland » mad-hatter')
    branchSources {
        branchSource {
            source {
                git {
                    id('wonderland-mad-hatter')
                    remote('http://gitea:3000/Wonderland/mad-hatter.git')
                    credentialsId('gitea-jenkins')
                    traits {
                        gitBranchDiscovery()
                    }
                }
            }
        }
    }
    factory {
        remoteJenkinsFileWorkflowBranchProjectFactory {
            localMarker('')
            matchBranches(false)
            fallbackBranch('main')
            remoteJenkinsFile('Jenkinsfile')
            remoteJenkinsFileSCM {
                gitSCM {
                    userRemoteConfigs {
                        userRemoteConfig {
                            name('origin')
                            url('http://gitea:3000/Wonderland/mad-hatter-pipeline.git')
                            refspec('')
                            credentialsId('gitea-jenkins')
                        }
                    }
                    branches {
                        branchSpec {
                            name('*/main')
                        }
                    }
                    browser {}
                    gitTool('')
                    extensions {}
                }
            }
        }
    }
    orphanedItemStrategy {
        discardOldItems {
            numToKeep(20)
        }
    }
    triggers {
        periodicFolderTrigger {
            interval('1m')
        }
    }
}
