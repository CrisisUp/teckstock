variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_cidr" {
  default = "172.16.0.0/16"
}

variable "az_count" {
  default = 2
}

variable "azure_location" {
  default = "East US"
}

variable "azure_vnet_cidr" {
  default = "10.0.0.0/16"
}

variable "azure_subnet_cidr" {
  default = "10.0.0.0/24"
}
