#!/bin/bash

set -e

DB_NAME="${db_name_env}"
DB_USER="${db_user_env}"
DB_PASS="${db_pass_env}"
BUCKET_NAME="${bucket_name_env}"

exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log "--- INICIANDO SETUP: DATABASE + BACKUP AUTOMÁTICO S3 ---"
log "Config: DB_NAME=$DB_NAME, BUCKET=$BUCKET_NAME" 
log "Passo 1/6: Instalando Docker e AWS CLI..."

sudo apt get update
sudo apt get install -y awscli 
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker ubuntu

log "Docker e AWS CLI instalados."
log "Passo 2/6: Configurando diretório /opt/prova-db..."

sudo mkdir -p /opt/prova-db
sudo chown -R ubuntu:ubuntu /opt/prova-db
cd /opt/prova-db

log "Passo 3/6: Criando script SQL de inicialização..."

cat <<EOF > init.sql
CREATE TABLE usuarios (id SERIAL PRIMARY KEY, nome VARCHAR(50), cargo VARCHAR(50), situacao VARCHAR(50));
INSERT INTO usuarios (nome, cargo,situacao) VALUES ('Douglas', 'DevOps/NOC1','Aprovado');
EOF

log "Passo 4/6: Criando docker-compose.yml..."
cat <<EOF > docker-compose.yml
services:
  db:
    image: postgres:15-alpine
    restart: always
    environment:
      POSTGRES_DB: $DB_NAME
      POSTGRES_USER: $DB_USER
      POSTGRES_PASSWORD: $DB_PASS
    ports:
      - "5432:5432"
    volumes:
      - pg_data:/var/lib/postgresql/data
      - ./init.sql:/docker-entrypoint-initdb.d/init.sql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $DB_USER -d $DB_NAME"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pg_data:
EOF

log "Subindo container do Banco de Dados..."

sudo docker compose up -d

log "Passo 5/6: Criando script de Backup para S3..."

sudo -u ubuntu mkdir -p /home/ubuntu/backups
sudo -u ubuntu mkdir -p /home/ubuntu/logs

cat <<EOF > /home/ubuntu/backup_to_s3.sh
#!/bin/bash
BUCKET_NAME="$BUCKET_NAME"
CONTAINER_NAME=\$(sudo docker ps --format "{{.Names}}" | grep db)
if [ -z "\$CONTAINER_NAME" ]; then CONTAINER_NAME="prova-db-db-1"; fi
DB_USER="$DB_USER"
DB_NAME="$DB_NAME"
BACKUP_DIR="/home/ubuntu/backups"
DATE=\$(date +%Y-%m-%d_%H-%M-%S)
FILE_NAME="db_backup_\$DATE.sql"
S3_PATH="s3://\$BUCKET_NAME/\$FILE_NAME"

mkdir -p \$BACKUP_DIR

echo "[INFO] Gerando Dump de \$DB_NAME..."
if sudo docker exec -t \$CONTAINER_NAME pg_dump -U \$DB_USER \$DB_NAME > "\$BACKUP_DIR/\$FILE_NAME"; then
    echo "Dump gerado com sucesso."
else
    echo "ERRO CRÍTICO ao gerar dump." && exit 1
fi

echo "[INFO] Enviando para S3..."

if aws s3 cp "\$BACKUP_DIR/\$FILE_NAME" "\$S3_PATH" --quiet; then
    echo "SUCESSO: Enviado para \$S3_PATH"
else
    echo "ERRO CRÍTICO no upload S3." && exit 1
fi

# Limpeza
rm "\$BACKUP_DIR/\$FILE_NAME"
echo "Backup finalizado."
EOF

chmod +x /home/ubuntu/backup_to_s3.sh
chown ubuntu:ubuntu /home/ubuntu/backup_to_s3.sh

log "Passo 6/6: Agendando backup no Crontab (A cada 12h)..."

(crontab -u ubuntu -l 2>/dev/null; echo "0 */12 * * * /home/ubuntu/backup_to_s3.sh >> /home/ubuntu/logs/backup.log 2>&1") | crontab -u ubuntu -

log "--- SETUP DO BANCO E BACKUP FINALIZADO COM SUCESSO! ---"