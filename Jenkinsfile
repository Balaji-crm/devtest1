pipeline {
    agent { label 'terra' }

    environment {
        SSH_CRED_ID = 'terraid'       // Jenkins SSH credential ID
        TF_HOST     = '13.233.197.159'
        TF_USER     = 'ubuntu'
    }

    options { timestamps() }

    stages {

        stage('Step 1: Remote Git Sanity Check') {
            steps {
                echo "Connecting to ${TF_USER}@${TF_HOST}..."

                sshagent (credentials: [env.SSH_CRED_ID]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << 'EOF'
                            set -e
                            echo "== Remote Host Info =="
                            echo USER: \$(whoami)
                            echo HOST: \$(hostname)
                            echo PWD:  \$(pwd)

                            echo "== Git Version =="
                            git --version || echo "git NOT found"

                            echo "== Network Check =="
                            ping -c 2 github.com || echo "Ping failed"

                            echo "STEP 1 COMPLETED"
EOF
                    """
                }
            }
        }

        stage('Step 2: Test GitHub SSH Access') {
            steps {
                echo "Testing GitHub SSH access from remote server..."

                sshagent (credentials: [env.SSH_CRED_ID]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << 'EOF'
                            set -e

                            echo "== Testing GitHub SSH authentication =="
                            ssh -T git@github.com || true

                            echo "If you see:"
                            echo "  'Hi username! You’ve successfully authenticated'"
                            echo "then SSH auth is working."

                            echo "If you see:"
                            echo "  'Permission denied (publickey)'"
                            echo "then the deploy key is NOT installed on GitHub."

                            echo "STEP 2 COMPLETED"
EOF
                    """
                }
            }
        }
    }

    post {
        success { echo "Step 1 + Step 2 completed successfully." }
        failure { echo "Step 2 failed — check logs." }
    }
}
