variable "region" {
  default = "ap-northeast-2"
}

variable "instance_id" {
  type = string
}

variable "hosted_zone_id" {
  type = string
}

variable "record_name" {
  type = string
}

variable "webhook_url" {
  type = string
}
