variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "availability_zones" {
  description = "Availability zones for the VPC"
  type        = list(string)
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "enable_nat_gateway" {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT Gateway for all private subnets (cost savings)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "nat_traffic_alarm_threshold_gb" {
  description = "Alarm when a NAT Gateway pulls more than this many GB from the internet in one hour. Set to 0 to disable."
  type        = number
  default     = 50
}

variable "nat_traffic_alarm_actions" {
  description = "SNS topic ARNs to notify when the NAT traffic alarm fires"
  type        = list(string)
  default     = []
}
