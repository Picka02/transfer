#!/bin/bash

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Vérification de Docker
if ! command -v docker &> /dev/null; then
    echo "Docker non détecté, installation en cours..."
    apt update && apt install -y docker.io docker-compose
else
    echo "Docker est déjà installé."
fi

# Création des dossiers de configuration
mkdir -p CTF/{easy,medium,hard,pwn}
cd CTF

# Génération du fichier docker-compose.yml
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  ctf_easy:
    build: ./easy
    container_name: ctf_easy
    ports:
      - "8081:80"
    restart: always

  ctf_medium:
    build: ./medium
    container_name: ctf_medium
    ports:
      - "8082:80"
      - "2222:22"
    restart: always

  ctf_hard:
    build: ./hard
    container_name: ctf_hard
    ports:
      - "8083:80"
      - "2223:22"
    restart: always

  ctf_pwn:
    build: ./pwn
    container_name: ctf_pwn
    ports:
      - "8084:80"
    restart: always
    volumes:
      - ./PWN:/app
    command: ["/bin/bash", "-c", "cd /app && ./my_executable.exe"]
EOF

# Configuration de la machine facile (LFI + Interface Web améliorée)
mkdir -p easy
cat <<EOF > easy/Dockerfile
FROM ubuntu:20.04
RUN apt update && apt install -y apache2 php libapache2-mod-php && \
    mkdir /var/www/html/vuln && \
    echo '<?php include($_GET["file"]); ?>' > /var/www/html/vuln/index.php && \
    echo 'FLAG{LFI_Challenge_001}' > /var/www/html/flag.txt && \
    echo '<html><head><link rel="stylesheet" href="style.css"></head><body><h1>Bienvenue sur "File Explorer"</h1><p>Un fichier peut en cacher un autre...</p></body></html>' > /var/www/html/index.html && \
    echo 'body { background-color: #222; color: #fff; text-align: center; font-family: Arial; margin-top: 50px; }' > /var/www/html/style.css && \
    systemctl enable apache2
CMD ["apachectl", "-D", "FOREGROUND"]
EOF

# Configuration de la machine moyenne (SQLi + SSH avec Protection WAF basique)
mkdir -p medium
cat <<EOF > medium/Dockerfile
FROM debian:11
RUN apt update && apt install -y apache2 php libapache2-mod-php mariadb-server sudo openssh-server && \
    echo '<?php if(preg_match("/union|select|drop|insert/i", \$_GET["id"])) die("Tentative détectée !"); $conn = new mysqli("localhost", "ctfuser", "C0mP!eXp@55w0rD", "ctf"); if ($conn->connect_error) die("Erreur"); ?>' > /var/www/html/sqli.php && \
    echo 'FLAG{SQLi_Challenge_002}' > /home/pentester/flag.txt && chmod 600 /home/pentester/flag.txt && \
    echo '<html><head><link rel="stylesheet" href="style.css"></head><body><h1>Bienvenue sur "Injection Lab"</h1><p>Une base de données peut parfois révéler des secrets...</p></body></html>' > /var/www/html/index.html && \
    echo 'body { background-color: #1e1e1e; color: #fff; text-align: center; font-family: Arial; margin-top: 50px; }' > /var/www/html/style.css && \
    systemctl enable apache2 ssh
CMD ["bash", "-c", "service apache2 start && service ssh start && tail -f /dev/null"]
EOF

# Configuration de la machine difficile (RCE + Port Knocking + SUID + Reverse Shell en attente)
mkdir -p hard
cat <<EOF > hard/Dockerfile
FROM kalilinux/kali-rolling
RUN apt update && apt install -y apache2 php libapache2-mod-php openssh-server knockd gcc netcat && \
    echo '<?php if(preg_match("/rm|shutdown|reboot/i", \$_GET["cmd"])) die("Commande interdite"); echo shell_exec(\$_GET["cmd"]); ?>' > /var/www/html/rce.php && \
    echo 'hacker:H@ckMe1fYouC@n' | chpasswd && \
    echo 'hacker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers && \
    echo 'FLAG{RCE_Challenge_003}' > /root/flag.txt && chmod 600 /root/flag.txt && \
    echo 'while true; do nc -lvnp 4444 -e /bin/bash; done &' >> /root/.bashrc && \
    echo '<html><head><link rel="stylesheet" href="style.css"></head><body><h1>Bienvenue sur "Code Execution Arena"</h1><p>Un code mal protégé peut ouvrir des portes insoupçonnées...</p></body></html>' > /var/www/html/index.html && \
    echo 'body { background-color: #111; color: #ff4444; text-align: center; font-family: Arial; margin-top: 50px; }' > /var/www/html/style.css && \
    systemctl enable apache2 ssh knockd
CMD ["bash", "-c", "service apache2 start && service ssh start && knockd -d && tail -f /dev/null"]
EOF

# Configuration de la machine PWN (Interagir avec un exécutable)
mkdir -p pwn
cat <<EOF > pwn/Dockerfile
FROM ubuntu:20.04

# Install Wine to run Windows executables
RUN dpkg --add-architecture i386 && \
    apt update && \
    apt install -y wine32

# Copy the executable to the container
COPY ./PWN /app

# Set the working directory
WORKDIR /app

# Run the executable
CMD ["wine", "my_executable.exe"]
EOF

# Construction des images Docker
docker-compose build

# Démarrage des conteneurs Docker
docker-compose up -d

echo "CTF prêt !"
echo "Facile : http://localhost:8081 (LFI: flag dans /var/www/html/flag.txt)"
echo "Moyen : http://localhost:8082 (SQLi protégé) & SSH: pentester@localhost:2222 (flag dans /home/pentester/flag.txt)"
echo "Difficile : http://localhost:8083 (RCE avancé) & SSH avec Port Knocking (flag dans /root/flag.txt)"
echo "PWN : http://localhost:8084 (Interagir avec l'exécutable)"