data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  key_name               = "ec2-bootstrap"
  vpc_security_group_ids = [aws_security_group.sg_private.id]
  iam_instance_profile   = aws_iam_instance_profile.grafana_profile.name

  user_data = templatefile("${path.module}/user_data/setup_db.sh", {
    db_name_env     = var.db_name
    db_user_env     = var.db_user
    db_pass_env     = var.db_password
    bucket_name_env = var.bucket_name
  })

  user_data_replace_on_change = true

  tags = { Name = "prova-db-private" }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  key_name               = "ec2-bootstrap"
  vpc_security_group_ids = [aws_security_group.sg_public.id]

  iam_instance_profile = aws_iam_instance_profile.grafana_profile.name

  user_data_replace_on_change = true

  user_data = templatefile("${path.module}/user_data/setup_app.sh", {
    db_ip_injecao     = aws_instance.db.private_ip
    docker_image_name = "dvrsdev/douglasprovacloud:latest"
    db_name_env       = var.db_name
    db_user_env       = var.db_user
    db_pass_env       = var.db_password
  })

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  tags       = { Name = "prova-app-public" }
  depends_on = [aws_instance.db]
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.app.id
  allocation_id = "eipalloc-000eaeb5222b8a841"
}