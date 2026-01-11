#!/bin/bash

DB_HOST="${db_ip_injecao}"
DOCKER_IMAGE="${docker_image_name}" 

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "--- [APP] Setup com SSL Auto-Assinado ---"

# instala docker e openssl
sudo apt-get update
sudo apt-get install -y openssl
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# cria pastas
sudo mkdir -p /opt/prova-app/nginx/certs
sudo chown -R ubuntu:ubuntu /opt/prova-app
cd /opt/prova-app

# gera o certificado auto-assinado e configura o Nginx como proxy reverso com HTTPS
echo "--- Gerando Certificado Local ---"
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout nginx/certs/nginx-selfsigned.key \
  -out nginx/certs/nginx-selfsigned.crt \
  -subj "/C=BR/ST=SP/L=Cloud/O=Prova/OU=IT/CN=localhost"

# configuração do Nginx
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

# cria o docker-compose
cat <<EOF > docker-compose.yml
services:
  app:
    image: $DOCKER_IMAGE
    restart: always
    environment:
      - DB_HOST=$DB_HOST
      - DB_USER=admin
      - DB_PASS=admin
      - DB_NAME=db_prova
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

networks:
  internal-net:
EOF

echo "--- Subindo Containers ---"
sudo docker compose pull
sudo docker compose up -d
echo "--- Fim do Setup ---"