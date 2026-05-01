module "portfolio" {
  source = "../../modules/static_website_s3"

  domain_name          = var.domain_name
  cloudflare_zone_id   = var.cloudflare_zone_id
  cloudflare_api_token = var.cloudflare_api_token
}
