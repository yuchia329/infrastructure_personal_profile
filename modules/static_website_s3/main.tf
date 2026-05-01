# ==============================================================================
# S3 Static Website Module with Cloudflare
# ==============================================================================

# ------------------------------------------------------------------------------
# Cloudflare Zone Settings
# ------------------------------------------------------------------------------

# Set SSL/TLS mode to Full for the zone (EC2 subdomains use self-signed certs).
# yuchia.dev itself overrides to Flexible via the ruleset below because S3
# static website hosting does not support HTTPS on the origin.
resource "cloudflare_zone_settings_override" "domain_settings" {
  zone_id = var.cloudflare_zone_id

  settings {
    ssl                      = "full"
    always_use_https         = "on"
    automatic_https_rewrites = "on"
  }
}

# ------------------------------------------------------------------------------
# Cloudflare Ruleset – SSL Override for yuchia.dev root
# ------------------------------------------------------------------------------

# Override SSL to Flexible only for the bare domain (S3 cannot serve HTTPS).
# Priority 1 ensures this fires before any other HTTP request origin rules.
resource "cloudflare_ruleset" "ssl_override" {
  zone_id     = var.cloudflare_zone_id
  name        = "Personal Web Override SSL"
  description = "Override SSL to Flexible for the yuchia.dev static S3 website"
  kind        = "zone"
  phase       = "http_config_settings"

  rules {
    action = "set_config"
    action_parameters {
      ssl = "flexible"
    }
    expression  = "(http.host eq \"yuchia.dev\")"
    description = "Personal Web Override SSL"
    enabled     = true
  }
}

resource "aws_s3_bucket" "website" {
  bucket = var.domain_name
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document {
    suffix = "index.html"
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.website.arn}/*"
      }
    ]
  })
}

locals {
  s3_origin_id   = "myS3Origin"
  website_domain = aws_s3_bucket_website_configuration.website.website_endpoint
}

resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = var.domain_name
  content = aws_s3_bucket_website_configuration.website.website_endpoint
  type    = "CNAME"
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  content = var.domain_name
  # content = "${var.domain_name}.s3-website-us-east-1.amazonaws.com"
  type    = "CNAME"
  proxied = true
}
