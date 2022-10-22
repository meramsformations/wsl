#!/bin/bash

KUBE_VERSION="v1.23.2"


#On commence par vérifier que nous sommes sur une distribution ubuntu
sudo lsb_release -a 2>/dev/null | grep -i ubuntu > /dev/null
if [ $? -ne 0 ]
then
  echo "Une distribution Ubuntu est nécessaire. Merci d'exécuter ce script sur Ubuntu"
  exit 1
fi


#Mise à jour du fichier /etc/sudoers afin de ne pas avoir à saisir le mot de passe pour les commandes sudo 
sudo sed -i "s/ALL=(ALL:ALL) ALL/ALL=(ALL:ALL) NOPASSWD:ALL/g" /etc/sudoers


#Téléchargement et installation des packages 
sudo apt-get update
sudo apt-get -yq install ca-certificates curl gnupg lsb-release git conntrack maven default-jdk net-tools


#Check si git, maven et Java sont bien présents
git version >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Git n'a pas pu être installé."
  exit 1
fi
mvn --version >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Maven n'a pas pu être installé."
  exit 1
fi
java --version >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Java n'a pas pu être installé."
  exit 1
fi


#Préparation au téléchargement de Docker
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null


#Installation de Docker
sudo apt-get update
sudo apt-get -yq install docker-ce docker-ce-cli containerd.io docker-compose-plugin  


#Check si Docker est installé
docker -v >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Docker n'a pas pu être installé."
  exit 1
fi

#Démarrage de Docker
sudo service docker start
#Attente avant de vérifier si Docker est bien running
sleep 3
sudo service docker status | grep -i "Docker is running" > /dev/null
if [ $? -ne 0 ]
then
  echo "Docker n'arrive pas à démarrer"
  exit 1
fi

#Téléchargement des packages minikube et kubectl
rm -f /tmp/minikube /tmp/kubectl
curl -sLo /tmp/minikube https://storage.googleapis.com/minikube/releases/${KUBE_VERSION}/minikube-linux-amd64
curl -sLo /tmp/kubectl  https://dl.k8s.io/release/${KUBE_VERSION}/bin/linux/amd64/kubectl

#Vérification du bon téléchargement des packages
if [ ! -f /tmp/minikube -o ! -f /tmp/kubectl ]
then
 echo "Echec du téléchargement des packages minikube et/ou kubectl"
 exit 1
fi

#Vérification de la taille des fichiers téléchargés
SIZE_MINIKUBE=$(du /tmp/minikube -b | cut -f1)
SIZE_KUBECTL=$(du /tmp/kubectl -b | cut -f1)

if [ $SIZE_MINIKUBE -lt 1048576 ]
then
 echo "Le package minikube téléchargé semble invalide."
 exit 1
fi
if [ $SIZE_KUBECTL -lt 1048576 ]
then
 echo "Le package kubectl téléchargé semble invalide."
 exit 1
fi 

chmod +x /tmp/minikube
sudo mkdir -p /usr/local/bin/
sudo install /tmp/minikube /usr/local/bin/
sudo cp /tmp/kubectl /usr/local/bin/kubectl
sudo chmod a+x /usr/local/bin/kubectl
rm -f /tmp/minikube /tmp/kubectl

#Check si les binaires minikube et kuebctl fonctionnent bien
minikube version 2>/dev/null | grep -i $KUBE_VERSION >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
 echo "Minikube n'a pas été installé correctement."
 exit 1
fi
kubectl version 2>/dev/null | grep -i $KUBE_VERSION >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
 echo "Minikube n'a pas été installé correctement."
 exit 1
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


mkdir ~/jenkins 2>/dev/null
chmod a+rwx ~/jenkins
VOLUME_DIR=$HOME/jenkins

#Avant de démarrer le conteneur Jenkins on vérifie ue le port 8080 est libre
sudo lsof -nP -iTCP -sTCP:LISTEN | grep 8080 >/dev/null 2>/dev/null
if [ $? -eq 0 ]
then
  echo "Le port 8080 est déjà en écoute. Merci de le libérer"
  exit 1
fi

sudo docker run -d -p 8080:8080 -v ${VOLUME_DIR}:/var/jenkins_home jenkins/jenkins:lts-jdk8
sleep 5

#On vérifie que le conteneur Jenkins est bien démarré
sudo lsof -nP -iTCP -sTCP:LISTEN | grep 8080 >/dev/null 2>/dev/null
if [ $? -ne 0 ]
then
  echo "Jenkins ne semble pas être démarré."
  exit 1
fi

echo "Installation OK"
