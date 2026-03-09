pipeline {
  agent any

  stages {
    stage('Backend') {
      steps {
        dir('backend') {
          sh 'python -m pip install -r requirements.txt'
          sh 'python -m compileall app'
        }
      }
    }
    stage('Mobile') {
      steps {
        dir('mobile') {
          sh 'flutter pub get'
          sh 'flutter analyze'
          sh 'flutter test'
        }
      }
    }
    stage('Admin') {
      steps {
        dir('admin') {
          sh 'npm ci'
          sh 'npm run lint'
          sh 'npm run build'
        }
      }
    }
  }
}
