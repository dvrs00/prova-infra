#!/bin/bash

set -e

DB_HOST="${db_ip_injecao}"
DOCKER_IMAGE="${docker_image_name}"
DB_NAME="${db_name_env}"
DB_USER="${db_user_env}"
DB_PASS="${db_pass_env}"

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log "--- INICIANDO SETUP: APP + GRAFANA + SSL ---"

log "Passo 1/6: Configurando SWAP (1GB)..."
sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
log "SWAP configurado com sucesso."


log "Passo 2/6: Instalando dependências e Docker..."
sudo apt-get update
sudo apt-get install -y openssl
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu
log "Docker instalado."

log "Passo 3/6: Criando estrutura de diretórios em /opt/prova-app..."
sudo mkdir -p /opt/prova-app/nginx/certs
sudo mkdir -p /opt/prova-app/grafana_data
sudo chmod 777 /opt/prova-app/grafana_data
sudo chown -R ubuntu:ubuntu /opt/prova-app
cd /opt/prova-app

log "Passo 4/6: Gerando Certificado SSL Auto-Assinado..."
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/nginx-selfsigned.key \
  -out nginx/certs/nginx-selfsigned.crt \
  -subj "/C=BR/ST=SP/L=Cloud/O=Prova/OU=IT/CN=localhost"
log "Certificado gerado em nginx/certs/."

log "Passo 5/6: Escrevendo configurações do Nginx..."
cat <<EOF > nginx/default.conf
server {
    listen 80;
    server_name _;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name _;

    ssl_certificate /etc/nginx/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/nginx/certs/nginx-selfsigned.key;

    location / {
        proxy_pass http://app:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
EOF

log "Passo 6/6: Criando docker-compose.yml e subindo containers..."
cat <<EOF > docker-compose.yml
services:
  app:
    image: $DOCKER_IMAGE
    restart: always
    environment:
      - DB_HOST=$DB_HOST
      - DB_NAME=$DB_NAME
      - DB_USER=$DB_USER
      - DB_PASS=$DB_PASS
    networks:
      - internal-net

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
      - ./nginx/certs:/etc/nginx/certs
    depends_on:
      - app
    networks:
      - internal-net

  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - ./grafana_data:/var/lib/grafana
    networks:
      - internal-net

networks:
  internal-net:
EOF

log "Executando docker compose pull..."
sudo docker compose pull

log "Executando docker compose up..."
sudo docker compose up -d

log "--- SETUP DO APP FINALIZADO COM SUCESSO! ---"