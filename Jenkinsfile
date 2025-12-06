pipeline {
    agent {
        node {
            label 'terra'
            customWorkspace '/var/jenkins/workspaces/test'
        }
    }
}


  environment {
    // Jenkins SSH credential ID (SSH Username with private key) - must match exactly the Jenkins credential ID
    SSH_CRED_ID = 'terraid'

    // Remote host details - set to the correct host/IP
    TF_HOST = '13.233.197.159'   // <- confirm this: .142 vs .143
    TF_USER = 'ubuntu'          // remote user
    REPO_URL = 'https://github.com/Balaji-crm/devtest1.git'
    REPO_DIR = '/home/ubuntu/terra'
    // Optional: Jenkins string credential IDs for AWS (if you use them)
    AWS_KEY_ID_CRED = 'aws-access-key-id'
    AWS_SECRET_CRED = 'aws-secret-access-key'
  }

  options { timestamps() }

  stages {
    stage('Validate connectivity') {
      steps {
        echo "Testing SSH connectivity to ${TF_USER}@${TF_HOST}"
        sshagent (credentials: [env.SSH_CRED_ID]) {
          // Show loaded identities for debugging
          sh 'ssh-add -l || true'

          // Run a connectivity check on the remote host
          sh "ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} 'echo CONNECTED: \$(whoami)@\$(hostname)'"
        }
      }
    }

    stage('Update Terraform repo on remote') {
      steps {
        sshagent (credentials: [env.SSH_CRED_ID]) {
          // Use a GString (""" ... """) so Groovy variables expand before sending to the shell.
          sh """
            ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'REMOTE_EOF'
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
              # Ensure correct branch
              git checkout -f main || true
              git pull || true
REMOTE_EOF
          """
        }
      }
    }

    stage('Terraform Init & Plan on remote') {
      steps {
        // If AWS creds present in Jenkins, make them available for the remote commands.
        script {
          if (AWS_KEY_ID_CRED?.trim() && AWS_SECRET_CRED?.trim()) {
            withCredentials([string(credentialsId: AWS_KEY_ID_CRED, variable: 'J_AWS_ACCESS_KEY_ID'),
                             string(credentialsId: AWS_SECRET_CRED, variable: 'J_AWS_SECRET_ACCESS_KEY')]) {
              sshagent (credentials: [env.SSH_CRED_ID]) {
                // Variables J_AWS_* will be expanded into the SSH command and exported on remote
                sh """
                  ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'REMOTE_EOF'
                    set -e
                    cd ${REPO_DIR}
                    # Export AWS creds for this shell (they were interpolated into the command)
                    export AWS_ACCESS_KEY_ID="${J_AWS_ACCESS_KEY_ID}"
                    export AWS_SECRET_ACCESS_KEY="${J_AWS_SECRET_ACCESS_KEY}"
                    terraform init -input=false
                    terraform validate
                    terraform plan -input=false -out=tfplan
                    terraform show -no-color tfplan > plan.txt
                    echo "PLAN-SAVED:${REPO_DIR}/plan.txt"
REMOTE_EOF
                """
              }
            }
          } else {
            // No AWS creds from Jenkins; rely on remote environment/role
            sshagent (credentials: [env.SSH_CRED_ID]) {
              sh """
                ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'REMOTE_EOF'
                  set -e
                  cd ${REPO_DIR}
                  terraform init -input=false
                  terraform validate
                  terraform plan -input=false -out=tfplan
                  terraform show -no-color tfplan > plan.txt
                  echo "PLAN-SAVED:${REPO_DIR}/plan.txt"
REMOTE_EOF
              """
            }
          }
        }

        // Retrieve plan.txt from remote and archive it
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh "scp -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST}:${REPO_DIR}/plan.txt . || true"
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
        sshagent (credentials: [env.SSH_CRED_ID]) {
          sh """
            ssh -o StrictHostKeyChecking=no ${TF_USER}@${TF_HOST} <<'REMOTE_EOF'
              set -e
              cd ${REPO_DIR}
              terraform apply -input=false tfplan
REMOTE_EOF
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
