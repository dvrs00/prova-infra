output "app_public_ip" {
  description = "IP Publico da Aplicacao (Elastic IP)"
  value       = aws_eip_association.eip_assoc.public_ip
}

output "app_ssh_command" {
  description = "Comando pronto para acesso SSH"
  value       = "ssh -i ~/.ssh/ec2-bootstrap.pem ubuntu@${aws_eip_association.eip_assoc.public_ip}"
}

output "db_endpoint" {
  description = "Endpoint privado do Banco de Dados"
  value       = aws_instance.db.private_ip
}