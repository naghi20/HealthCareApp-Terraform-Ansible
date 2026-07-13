output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "db_endpoint" {
  value     = aws_db_instance.app_db.endpoint
  sensitive = true
}
