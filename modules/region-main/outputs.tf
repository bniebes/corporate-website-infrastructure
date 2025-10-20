output "hosted_zone_id" {
  description = "Route 53 Hosted Zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers for the hosted zone - update these at your domain registrar"
  value       = aws_route53_zone.main.name_servers
}

output "user_name" {
  value       = aws_iam_user.cicd_user.name
  description = "IAM username for CI/CD"
}

output "access_key_id" {
  value       = aws_iam_access_key.cicd_user_key.id
  description = "Access key ID for CI/CD user"
  sensitive   = true
}

output "secret_access_key" {
  value       = aws_iam_access_key.cicd_user_key.secret
  description = "Secret access key for CI/CD user"
  sensitive   = true
}
  
