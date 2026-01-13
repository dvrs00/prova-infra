resource "aws_iam_user" "validator" {
  name = "acesso-wlui"
}

resource "aws_iam_user_login_profile" "validator" {
  user                    = aws_iam_user.validator.name
  password_reset_required = true
}

resource "aws_iam_policy_attachment" "readonly_attach" {
  name       = "readonly-attach"
  users      = [aws_iam_user.validator.name]
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "validator_password" {
  value     = aws_iam_user_login_profile.validator.password
  sensitive = true
}

resource "aws_iam_role" "ec2_grafana_role" {
  name = "grafana_cloudwatch_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_read" {
  role       = aws_iam_role.ec2_grafana_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_grafana_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_instance_profile" "grafana_profile" {
  name = "grafana_instance_profile"
  role = aws_iam_role.ec2_grafana_role.name
}
