#!/bin/bash

KUBE_VERSION="v1.23.2"


#On vérifie si SSH est en cours d'exécution. Sinon, on le démarre
sudo service ssh status | grep -i "sshd is running" > /dev/null
if [ $? -ne 0 ]
then
   #Démarrage du serveur ssh
   sudo service ssh start
   #Attente avant de vérifier si Docker est bien running
   sleep 3
   
   #On contrôle que ssh est bien démarré
   sudo service ssh status | grep -i "sshd is running" > /dev/null
   if [ $? -ne 0 ]
   then
      echo "Le serveur SSH n'arrive pas à démarrer"
      exit 1
   fi
fi



#On vérifie si Docker est en cours d'exécution. Sinon, on le démarre
sudo service docker status | grep -i "Docker is running" > /dev/null
if [ $? -ne 0 ]
then
   #Redémarrage de Docker
   sudo service docker start
   #Attente avant de vérifier si Docker est bien running
   sleep 3
   
   #On contrôle que Docker est bien démarré
   sudo service docker status | grep -i "Docker is running" > /dev/null
   if [ $? -ne 0 ]
   then
      echo "Docker n'arrive pas à démarrer"
      exit 1
   fi
fi



#On vérifie si Jenkins est en cours d'exécution. Sinon, on le démarre
sudo docker ps | grep jenkins/jenkins:lts-jdk8 >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
    VOLUME_DIR=$HOME/jenkins
    sudo docker run -d -p 8080:8080 -v ${VOLUME_DIR}:/var/jenkins_home jenkins/jenkins:lts-jdk8
    sleep 5
	#On vérifie que le conteneur Jenkins est bien démarré
    sudo lsof -nP -iTCP -sTCP:LISTEN | grep 8080 >/dev/null 2>/dev/null
    if [ $? -ne 0 ]
    then
      echo "Jenkins ne semble pas être démarré."
      exit 1
    fi
fi



#On vérifie si Minikube est en cours d'exécution. Sinon, on le démarre
sudo minikube status | grep -i "host.*:.*Running" >/dev/null 2>/dev/null
RET_HOST=$?
sudo minikube status | grep -i "kubelet.*:.*Running" >/dev/null 2>/dev/null
RET_KUBELET=$?
sudo minikube status | grep -i "apiserver.*:.*Running" >/dev/null 2>/dev/null
RET_APISERVER=$?
sudo minikube status | grep -i "kubeconfig.*:.*Configured" >/dev/null 2>/dev/null
RET_KUBECONFIG=$?
if [ $RET_HOST -ne 0 -o $RET_KUBELET -ne 0 -o $RET_APISERVER -ne 0 -o $RET_KUBECONFIG -ne 0 ]
then
    sudo sysctl fs.protected_regular=0
    sudo rm -f /tmp/juju-*
    #sudo service docker start
    sudo minikube start --driver=docker --kubernetes-version=${KUBE_VERSION} --force
	
	#Vérifictaion du bon démarrage de minikube
    sudo minikube status | grep -i "host.*:.*Running" >/dev/null 2>/dev/null
    RET_HOST=$?
    sudo minikube status | grep -i "kubelet.*:.*Running" >/dev/null 2>/dev/null
    RET_KUBELET=$?
    sudo minikube status | grep -i "apiserver.*:.*Running" >/dev/null 2>/dev/null
    RET_APISERVER=$?
    sudo minikube status | grep -i "kubeconfig.*:.*Configured" >/dev/null 2>/dev/null
    RET_KUBECONFIG=$?
    if [ $RET_HOST -ne 0 -o $RET_KUBELET -ne 0 -o $RET_APISERVER -ne 0 -o $RET_KUBECONFIG -ne 0 ]
    then
      echo "Minikube n'a pas réussi à démarrer correctement"
      exit 1
    fi
fi

echo "Installation OK"
