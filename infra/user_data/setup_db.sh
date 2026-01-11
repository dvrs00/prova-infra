#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "--- [DB] Iniciando setup ---"

# instala docker
sudo apt-get update
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

# 2. setup das pastas
sudo mkdir -p /opt/prova-db
sudo chown -R ubuntu:ubuntu /opt/prova-db
cd /opt/prova-db

# 3. sql para criar tabela e inserir dados
cat <<EOF > init.sql
CREATE TABLE usuarios (id SERIAL PRIMARY KEY, nome VARCHAR(50), cargo VARCHAR(50), situacao VARCHAR(50));
INSERT INTO usuarios (nome, cargo,situacao) VALUES ('Douglas', 'DevOps/NOC1','Aprovado');
EOF

# cria o docker-compose 
cat <<EOF > docker-compose.yml
services:
  db:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin
      POSTGRES_DB: db_prova
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U admin -d db_prova"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pg_data:
EOF
echo '--- [DB] Subindo Container ---'

sudo docker compose up -d

echo "--- [DB] Setup finalizado ---"