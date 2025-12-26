# Kubernetes module outputs

output "user_service_account_name" {
  description = "Name of the user service account"
  value       = kubernetes_service_account.user_sa.metadata[0].name
}
