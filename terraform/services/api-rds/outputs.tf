output "name" {
  value     = aws_db_instance.api.id
  sensitive = true
}

output "address" {
  value     = aws_db_instance.api.address
  sensitive = true
}

output "id" {
  value     = aws_db_instance.api.id
  sensitive = true
}
