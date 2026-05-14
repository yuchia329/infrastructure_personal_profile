module "core_cluster" {
  source = "../../modules/single_node_cluster"

  aws_region           = var.aws_region
  project_name         = var.project_name
  environment          = var.environment
  instance_type        = var.instance_type
  allowed_ssh_cidr     = var.allowed_ssh_cidr
  cloudflare_api_token = var.cloudflare_api_token
  cloudflare_zone_id   = var.cloudflare_zone_id
  domain_name          = var.domain_name
  subdomain            = var.subdomain
  github_repos         = var.github_repos
  grafana_admin_password = var.grafana_admin_password
}

resource "cloudflare_record" "grafana" {
  zone_id = var.cloudflare_zone_id
  name    = "grafana"
  content = module.core_cluster.public_ip
  type    = "A"
  proxied = true
}

resource "cloudflare_record" "prometheus" {
  zone_id = var.cloudflare_zone_id
  name    = "prometheus"
  content = module.core_cluster.public_ip
  type    = "A"
  proxied = true
}
