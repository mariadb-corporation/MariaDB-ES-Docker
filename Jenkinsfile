
pipeline {
  agent { label 'master' }
  parameters {
    choice choices: ['10.2', '10.3', '10.4', '10.5'], description: 'Version to build', name: 'ES_VERSION'
  }

  options {
    buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '20')
  }
  environment {
    REGISTRY = "local/es-docker"
//    registryCredential = 'dockerhub'
  }
  stages {
    stage ('Build image') {
      steps {
        script {
          currentBuild.displayName = "#${BUILD_NUMBER}: Image: MariaDB-ES ${params.ES_VERSION}"
        }
        withCredentials([string(credentialsId: 'es-token', variable: 'TOKEN')]) {
          ansiColor('xterm') {
            sh """docker build --no-cache -t ${env.REGISTRY}:${params.ES_VERSION} \
              --build-arg ES_TOKEN=${TOKEN} --build-arg ES_VERSION=${params.ES_VERSION} -f Dockerfile ."""
          }
        }
      }
    }
    stage('Push image'){
      steps {
        echo "Pushing image: ${env.REGISTRY}:${params.ES_VERSION}..."
      }
    }
  }
  post {
    always {
      echo "Cleaning up old docker images..."
    }
  }
}
