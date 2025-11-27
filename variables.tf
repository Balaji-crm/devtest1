
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
}

variable "azs" {
  description = "Availability zones to use (length must match subnet lists)"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "name_prefix" {
  description = "Name prefix for resources"
  type        = string
  default     = "terra"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH from (use your IP/CIDR)"
  type        = string
  default     = "0.0.0.0/0"
}
