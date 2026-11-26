// Jenkinsfile — Automated pipeline Build -> Trivy Scan -> Push ECR -> Deploy EKS
pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT = sh(
            script: "aws sts get-caller-identity --query Account --output text",
            returnStdout: true
        ).trim()
        ECR_REPO = "${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/retail-ui"
        CLUSTER = 'eks-shopops'
    }

    stages {
        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${ECR_REPO}:${BUILD_NUMBER} src/ui"
            }
        }

        stage('Trivy Security Scan') {
            steps {
                sh "TMPDIR=/var/lib/jenkins/trivy-tmp trivy image --cache-dir /var/lib/jenkins/trivy-cache --severity HIGH,CRITICAL --exit-code 0 ${ECR_REPO}:${BUILD_NUMBER}"
            }
        }

        stage('Push to Amazon ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REPO}
                    docker push ${ECR_REPO}:${BUILD_NUMBER}
                """
            }
        }

        stage('Deploy to Amazon EKS') {
            steps {
                sh """
                    aws eks update-kubeconfig --name ${CLUSTER} --region ${AWS_REGION}
                    kubectl set image deployment/ui ui=${ECR_REPO}:${BUILD_NUMBER} -n retail
                    kubectl rollout status deployment/ui -n retail --timeout=180s
                """
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}