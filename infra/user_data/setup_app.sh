#!/bin/bash
 
DB_HOST="${db_ip_injecao}"
DOCKER_IMAGE="${docker_image_name}" 

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "--- [APP] Iniciando setup ---"

# instala o docker
sudo apt-get update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# setup das pastas
sudo mkdir -p /opt/prova-app/nginx
sudo chown -R ubuntu:ubuntu /opt/prova-app
cd /opt/prova-app

# cria a config do nginx 
cat <<EOF > nginx/default.conf
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://app:3000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# cria o docker-compose.yml
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
    volumes:
      - ./nginx/default.conf:/etc/nginx/conf.d/default.conf
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

echo "--- [App] Setup finalizado ---"