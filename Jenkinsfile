pipeline {
  agent { label 'terra' }

  environment {
    // Jenkins SSH credential ID (SSH Username with private key) to reach the remote VM
    SSH_CRED_ID   = 'terraid'

    // Remote host details
    TF_HOST       = '13.233.197.159'
    TF_USER       = 'ubuntu'

    // GitHub credentials (Username + Password/Token)
    GITHUB_CRED_ID = 'gitid'   // <-- Jenkins credential with your GitHub PAT

    // Repo + directory on the remote VM
    REPO_URL      = 'https://github.com/Balaji-crm/devtest1.git'
    REPO_DIR      = '/home/ubuntu/terra'

    // Optional: Jenkins string credential IDs for AWS (if you use them)
    AWS_KEY_ID_CRED   = 'aws-access-key-id'
    AWS_SECRET_CRED   = 'aws-secret-access-key'
  }

  options { timestamps() }

  stages {

    stage('Validate connectivity') {
      steps {
        echo "Testing SSH connectivity to ${TF_USER}@${TF_HOST}"
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh 'ssh-add -l || true'
          sh "ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} 'echo CONNECTED: \$(whoami)@\$(hostname)'"
        }
      }
    }

    stage('Update Terraform repo on remote') {
      steps {
        // Use GitHub token from Jenkins credentials
        withCredentials([usernamePassword(credentialsId: env.GITHUB_CRED_ID,
                                          usernameVariable: 'GUSER',
                                          passwordVariable: 'GTOKEN')]) {
          sshagent (credentials: [env.SSH_CRED_ID]) {
            sh """
              ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << EOF
                set -e

                REPO_DIR="${REPO_DIR}"
                REPO_URL="https://\$GUSER:\$GTOKEN@github.com/Balaji-crm/devtest1.git"

                echo "Using repo URL with token (masked in Jenkins logs)"

                mkdir -p "\${REPO_DIR}"
                cd "\${REPO_DIR}"

                if [ -d .git ]; then
                  echo "Repo exists — fetching latest from origin/main"
                  git fetch --all
                  git reset --hard origin/main || git reset --hard origin/HEAD
                else
                  echo "Cloning repo into \${REPO_DIR}"
                  rm -rf ./*
                  git clone "\${REPO_URL}" .
                fi

                git checkout -f main || true
                git pull --ff-only || true

                echo "Current HEAD:"
                git rev-parse HEAD
EOF
            """
          }
        }
      }
    }

    stage('Terraform Init & Plan on remote') {
      steps {
        script {
          if (AWS_KEY_ID_CRED?.trim() && AWS_SECRET_CRED?.trim()) {
            withCredentials([
              string(credentialsId: AWS_KEY_ID_CRED,   variable: 'J_AWS_ACCESS_KEY_ID'),
              string(credentialsId: AWS_SECRET_CRED,   variable: 'J_AWS_SECRET_ACCESS_KEY')
            ]) {
              sshagent (credentials: [env.SSH_CRED_ID]) {
                sh """
                  ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << EOF
                    set -e
                    cd "${REPO_DIR}"

                    # Export AWS creds for this shell
                    export AWS_ACCESS_KEY_ID="${J_AWS_ACCESS_KEY_ID}"
                    export AWS_SECRET_ACCESS_KEY="${J_AWS_SECRET_ACCESS_KEY}"

                    terraform init -input=false
                    terraform validate
                    terraform plan -input=false -out=tfplan
                    terraform show -no-color tfplan > plan.txt

                    echo "PLAN-SAVED:${REPO_DIR}/plan.txt"
EOF
                """
              }
            }
          } else {
            // No AWS creds from Jenkins; rely on remote environment/role
            sshagent (credentials: [env.SSH_CRED_ID]) {
              sh """
                ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << 'EOF'
                  set -e
                  cd "${REPO_DIR}"

                  terraform init -input=false
                  terraform validate
                  terraform plan -input=false -out=tfplan
                  terraform show -no-color tfplan > plan.txt

                  echo "PLAN-SAVED:${REPO_DIR}/plan.txt"
EOF
              """
            }
          }
        }

        // Retrieve plan.txt from remote and archive it in Jenkins
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh "scp -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST}:${REPO_DIR}/plan.txt . || true"
          archiveArtifacts artifacts: 'plan.txt', fingerprint: true
        }
      }
    }

    stage('Manual Approval to Apply') {
      steps {
        input message: "Approve terraform apply on remote host ${TF_HOST}?"
      }
    }

    stage('Terraform Apply on remote') {
      steps {
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh """
            ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} << 'EOF'
              set -e
              cd "${REPO_DIR}"
              terraform apply -input=false tfplan
EOF
          """
        }
      }
    }
  }

  post {
    success {
      echo "Terraform run completed successfully."
    }
    failure {
      echo "Terraform run failed — check console logs and remote machine state."
    }
  }
}
