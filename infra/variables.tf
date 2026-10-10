variable "project" {
  type        = string
  description = "Short lowercase name used in resource names"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "region" {
  type    = string
  default = "ap-south-1"
}

variable "root_domain" {
  type        = string
  description = "Existing Route 53 hosted zone, e.g. yourdomain.com"
}

variable "app_subdomain" {
  type    = string
  default = "app"
}

variable "api_subdomain" {
  type    = string
  default = "api"
}

variable "certbot_email" {
  type        = string
  description = "Email for Let's Encrypt expiry notices"
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}

variable "db_instance_class" {
  type    = string
  default = "db.t4g.micro"
}

variable "db_name" {
  type    = string
  default = "appdb"
}

variable "db_allocated_storage" {
  type    = number
  default = 20
}

variable "db_deletion_protection" {
  type    = bool
  default = true
}

variable "db_skip_final_snapshot" {
  type    = bool
  default = false
}
