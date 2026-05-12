
variable "aws_region" {
  default = "ap-southeast-1"
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "db_username" {}
variable "db_password" {
  sensitive = true
}

variable "task_definition_arn" {}
variable "waf_acl_arn" {}
