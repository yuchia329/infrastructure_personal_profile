variable "domain_name" {
  description = "Domain name for the website (e.g. yuchia.dev), also used as the S3 bucket name"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for managing DNS records"
  type        = string
}
