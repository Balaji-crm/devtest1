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
    }

    post {
        success { echo "Step 1 completed successfully." }
        failure { echo "Step 1 failed — check logs." }
    }
}
