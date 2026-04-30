output "public_ip" {
  value = module.core_cluster.public_ip
}

output "domain_url" {
  value = module.core_cluster.domain_url
}

output "ssh_command" {
  value = module.core_cluster.ssh_command
}
