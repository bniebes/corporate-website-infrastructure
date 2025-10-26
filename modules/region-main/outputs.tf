output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone - update these at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "user_name" {
  description = "IAM username for CI/CD"
  value       = aws_iam_user.cicd_user.name
}

output "access_key_id" {
  description = "Access key ID for CI/CD user"
  value       = aws_iam_access_key.cicd_user_key.id
  sensitive   = true
}

output "secret_access_key" {
  description = "Secret access key for CI/CD user"
  value       = aws_iam_access_key.cicd_user_key.secret
  sensitive   = true
}
