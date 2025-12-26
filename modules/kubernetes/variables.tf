# Kubernetes module variables

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

# AWS Auth ConfigMap variables
variable "node_role_arn" {
  description = "IAM role ARN for EKS nodes (required for nodes to join cluster)"
  type        = string
}

variable "cluster_admin_roles" {
  description = "List of IAM roles to grant cluster admin access"
  type = list(object({
    arn      = string
    username = string
  }))
  default = []
}

variable "cluster_admin_users" {
  description = "List of IAM users to grant cluster admin access"
  type = list(object({
    arn      = string
    username = string
  }))
  default = []
}
