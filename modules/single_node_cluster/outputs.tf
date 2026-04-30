output "public_ip" {
  value = aws_eip.app.public_ip
}

output "domain_url" {
  value = "https://${local.fqdn}"
}

output "fqdn" {
  value = local.fqdn
}

output "ssh_command" {
  value = "ssh -i ./${var.project_name}.pem ubuntu@${aws_eip.app.public_ip}"
}

output "cloudflare_record_id" {
  value = cloudflare_record.app.id
}
