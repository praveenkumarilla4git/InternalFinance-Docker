output "server_ip" {
  value = aws_instance.finance_server.public_ip
}