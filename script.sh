#!/bin/bash

# Vérification des privilèges root
if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

echo "[*] Vérification de Docker..."

# Vérifie si Docker est installé
if ! command -v docker &> /dev/null; then
    echo "[!] Docker non détecté, installation en cours..."
    apt update && apt install -y docker.io docker-compose
else
    echo "[✓] Docker est déjà installé."
fi

echo "[*] Création du répertoire CTF..."
mkdir -p CTF/{easy,medium,hard}
cd CTF

echo "[*] Génération du fichier docker-compose.yml..."
cat <<EOF > docker-compose.yml
version: "3.8"

services:
  ctf_easy:
    image: ubuntu:20.04
    container_name: ctf_easy
    ports:
      - "8081:80"
    restart: always
    volumes:
      - ./easy:/var/www/html
    command: ["/bin/bash", "-c", "apt update && apt install -y apache2 php libapache2-mod-php && systemctl start apache2 && tail -f /dev/null"]

  ctf_medium:
    image: debian:11
    container_name: ctf_medium
    ports:
      - "8082:80"
      - "2222:22"
    restart: always
    volumes:
      - ./medium:/var/www/html
    command: ["/bin/bash", "-c", "apt update && apt install -y apache2 php libapache2-mod-php mariadb-server sudo openssh-server && systemctl start apache2 && systemctl start ssh && tail -f /dev/null"]

  ctf_hard:
    image: kalilinux/kali-rolling
    container_name: ctf_hard
    ports:
      - "8083:80"
      - "2223:22"
    restart: always
    volumes:
      - ./hard:/var/www/html
    command: ["/bin/bash", "-c", "apt update && apt install -y apache2 php libapache2-mod-php openssh-server && systemctl start apache2 && systemctl start ssh && tail -f /dev/null"]
EOF

echo "[*] Création des défis..."

# Facile (LFI)
echo '<?php include($_GET["file"]); ?>' > easy/index.php

# Moyen (SQLi)
cat <<EOF > medium/sqli.php
<?php
\$conn = new mysqli('localhost', 'ctfuser', 'C0mP!eXp@55w0rD', 'ctf');
if (\$conn->connect_error) die('Erreur de connexion');
\$sql = "SELECT * FROM users WHERE username = '" . \$_GET['user'] . "'";
\$result = \$conn->query(\$sql);
?>
EOF

# Difficile (RCE)
echo '<?php echo shell_exec($_GET["cmd"]); ?>' > hard/rce.php

# Ajout d'un utilisateur backdoor dans la machine difficile
cat <<EOF > hard/ssh-backdoor.sh
#!/bin/bash
useradd -m -s /bin/bash hacker
echo "hacker:H@ckMe1fYouC@n" | chpasswd
echo "hacker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
service ssh restart
EOF

# Ajout du Dockerfile pour le défi difficile
cat <<EOF > hard/Dockerfile
FROM kalilinux/kali-rolling
COPY ssh-backdoor.sh /root/
RUN chmod +x /root/ssh-backdoor.sh && /root/ssh-backdoor.sh
EOF

echo "[*] Démarrage des conteneurs..."
docker-compose up -d

echo "[+] CTF prêt !"
echo "🔹 Facile : http://localhost:8081"
echo "🔸 Moyen : http://localhost:8082 (SSH: pentester@localhost:2222)"
echo "🔴 Difficile : http://localhost:8083 (SSH: hacker@localhost:2223)"