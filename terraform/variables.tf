variable "app_name" {
  type = string
}

variable "aws_region" {
  type    = string
  default = "eu-west-2"
}

variable "account_id" {
  type = string
}

variable "cluster_version" {
  type    = string
  default = "1.32"
}
