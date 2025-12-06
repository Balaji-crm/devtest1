pipeline {
    agent { label 'terra' }

    environment {
        SSH_CRED_ID  = 'terraid'                 // Jenkins SSH credential ID
        TF_HOST      = '13.233.197.159'
        TF_USER      = 'ubuntu'

        REPO_URL     = 'git@github.com:Balaji-crm/devtest1.git'
        TEST_REPO_DIR = '/home/ubuntu/terra-test'
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

                            # Add GitHub host key to known_hosts (avoids 'Host key verification failed')
                            mkdir -p ~/.ssh
                            ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true

                            # Test SSH to GitHub (may still return non-zero even when OK, so don't fail pipeline)
                            ssh -T git@github.com || true

                            echo
                            echo "If you see:"
                            echo "  'Hi <username>! You’ve successfully authenticated'"
                            echo "then SSH auth is working."
                            echo
                            echo "If you see:"
                            echo "  'Permission denied (publickey)'"
                            echo "then an SSH key is NOT registered on GitHub for this server."
                            echo
                            echo "STEP 2 COMPLETED"
EOF
                    """
                }
            }
        }

        stage('Step 3: Test clone into temp directory') {
            steps {
                echo "Testing git clone into ${env.TEST_REPO_DIR}..."

                sshagent (credentials: [env.SSH_CRED_ID]) {
                    sh """
                        ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << 'EOF'
                            set -e

                            REPO_URL="${REPO_URL}"
                            TEST_DIR="${TEST_REPO_DIR}"

                            echo "== Preparing test directory =="
                            rm -rf "\${TEST_DIR}"
                            mkdir -p "\${TEST_DIR}"
                            cd "\${TEST_DIR}"

                            echo "== Ensuring GitHub host key exists =="
                            mkdir -p ~/.ssh
                            ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null || true

                            echo "== Cloning repo =="
                            git clone "\${REPO_URL}" .

                            echo "== Clone result =="
                            pwd
                            ls -la
                            echo "HEAD commit:"
                            git rev-parse HEAD

                            echo "STEP 3 COMPLETED"
EOF
                    """
                }
            }
        }
    }

    post {
        success { echo "Steps 1–3 completed successfully." }
        failure { echo "One of the steps failed — check logs (likely Step 3 / GitHub auth)." }
    }
}
