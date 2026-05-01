variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "domain_name" {
  description = "Domain name for the website (e.g. yuchia.dev), also used as the S3 bucket name"
  type        = string
  default     = "yuchia.dev"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for managing DNS records"
  type        = string
}

variable "cloudflare_api_token" {
  type      = string
  sensitive = true
}
