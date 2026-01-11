resource "aws_iam_user" "validator" {
  name = "acesso-wlui"
}

resource "aws_iam_user_login_profile" "validator" {
  user    = aws_iam_user.validator.name
  password_reset_required = true
}

resource "aws_iam_policy_attachment" "readonly_attach" {
  name       = "readonly-attach"
  users      = [aws_iam_user.validator.name]
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

output "validator_password" {
  value = aws_iam_user_login_profile.validator.password
  sensitive = true 
}