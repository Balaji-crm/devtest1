pipeline {
  agent any

  environment {
    // Jenkins SSH credential ID (SSH Username with private key)
    SSH_CRED_ID = 'terraform-ssh-creds'

    // Remote host details - replace with actual host/IP or set as Job/Global variables
    TF_HOST = '192.168.1.143'
    TF_USER = 'ubuntu'     // or ec2-user (depends on AMI)
    REPO_URL = 'https://github.com/Balaji-crm/devtest1.git'
    REPO_DIR = '/home/ubuntu/day1'   // choose a folder
    // Optional: If you store AWS creds in Jenkins, set those credential IDs here:
    AWS_KEY_ID_CRED = 'aws-access-key-id'             // optional secret-text ID
    AWS_SECRET_CRED = 'aws-secret-access-key'         // optional secret-text ID
  }

  options { timestamps() }

  stages {
    stage('Validate connectivity') {
      steps {
        echo "Testing SSH connectivity to ${env.TF_USER}@${env.TF_HOST}"
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh "ssh -o StrictHostKeyChecking=no ${env.TF_USER}@${env.TF_HOST} 'echo connected: \$(whoami)@\$(hostname)'"
        }
      }
    }

    stage('Update Terraform repo on remote') {
      steps {
        sshagent (credentials: [env.SSH_CRED_ID]) {
          // clone if missing, else pull
          sh """
            ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'SSH_EOF'
              set -e
              mkdir -p ${REPO_DIR}
              cd ${REPO_DIR}
              if [ -d .git ]; then
                echo "Repo exists — fetching latest"
                git fetch --all
                git reset --hard origin/HEAD
              else
                echo "Cloning repo"
                git clone ${REPO_URL} .
              fi
              # Ensure correct branch if you want specific branch (e.g., main)
              git checkout -f main || true
              git pull || true
SSH_EOF
          """
        }
      }
    }

    stage('Terraform Init & Plan on remote') {
      steps {
        // Inject AWS env vars if you stored them in Jenkins credentials (optional)
        script {
          def awsKey = ''
          def awsSecret = ''
          if (credentialsExists(AWS_KEY_ID_CRED) && credentialsExists(AWS_SECRET_CRED)) {
            // Use withCredentials to bind secrets as env vars
            withCredentials([string(credentialsId: AWS_KEY_ID_CRED, variable: 'AWS_ACCESS_KEY_ID'),
                             string(credentialsId: AWS_SECRET_CRED, variable: 'AWS_SECRET_ACCESS_KEY')]) {
              sshagent (credentials: [env.SSH_CRED_ID]) {
                sh """
                  ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'SSH_EOF'
                    set -e
                    cd ${REPO_DIR}
                    # export creds for this shell (only for this run)
                    export AWS_ACCESS_KEY_ID='${env.AWS_ACCESS_KEY_ID}'
                    export AWS_SECRET_ACCESS_KEY='${env.AWS_SECRET_ACCESS_KEY}'
                    terraform init -input=false
                    terraform validate
                    terraform plan -input=false -out=tfplan
                    terraform show -no-color tfplan > plan.txt
                    echo "PLAN-SAVED:/${REPO_DIR}/plan.txt"
SSH_EOF
                """
              }
            }
          } else {
            // No AWS creds passed from Jenkins; rely on remote's IAM role or local creds on the remote server
            sshagent (credentials: [env.SSH_CRED_ID]) {
              sh """
                ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'SSH_EOF'
                  set -e
                  cd ${REPO_DIR}
                  terraform init -input=false
                  terraform validate
                  terraform plan -input=false -out=tfplan
                  terraform show -no-color tfplan > plan.txt
                  echo "PLAN-SAVED:${REPO_DIR}/plan.txt"
SSH_EOF
              """
            }
          }
        }
        // Optionally retrieve and archive the plan.txt from remote for inspection
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh """
            scp -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST}:${REPO_DIR}/plan.txt .
          """
          archiveArtifacts artifacts: 'plan.txt', fingerprint: true
        }
      }
    }

    stage('Manual Approval to Apply') {
      steps {
        input message: "Approve apply on remote Terraform host ${TF_HOST}?"
      }
    }

    stage('Terraform Apply on remote') {
      steps {
        // Run apply on remote using the plan created earlier
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh """
            ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'SSH_EOF'
              set -e
              cd ${REPO_DIR}
              terraform apply -input=false tfplan
SSH_EOF
          """
        }
      }
    }
  }

  post {
    success { echo "Terraform run completed successfully." }
    failure { echo "Terraform run failed — check console logs and remote machine state." }
  }
}

// helper to check credential presence (groovy)
def credentialsExists(id) {
  try {
    return id != null && id != ''
  } catch (e) {
    return false
  }
}
