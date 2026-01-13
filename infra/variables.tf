variable "project_name" {
  default = "prova-infra"
}

variable "db_name" {
  description = "Nome do banco de dados"
  default     = "db_prova"
}

variable "db_user" {
  description = "Usuário do banco"
  sensitive   = true
}

variable "db_password" {
  description = "Senha do banco"
  sensitive   = true
}

variable "bucket_name" {
  description = "Nome do Bucket S3 para backups"
  type        = string
}