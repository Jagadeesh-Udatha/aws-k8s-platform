output "address" {
  value = aws_db_instance.this.address
}

output "port" {
  value = aws_db_instance.this.port
}

output "jdbc_url" {
  description = "TLS is enforced by rds.force_ssl, so the driver must ask for it."
  value       = "jdbc:postgresql://${aws_db_instance.this.address}:${aws_db_instance.this.port}/${var.database}?sslmode=require"
}

output "username" {
  value = var.username
}

output "password" {
  value     = random_password.master.result
  sensitive = true
}
