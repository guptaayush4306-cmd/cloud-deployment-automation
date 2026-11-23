output "ec2_public_ip" {
  description = "Public IP of CloudDeploy EC2"
  value       = aws_instance.app.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of EC2"
  value       = aws_instance.app.public_dns
}

output "application_url" {
  description = "CloudDeploy application URL"
  value       = "http://${aws_instance.app.public_ip}:8000"
}

output "ecr_image" {
  value = var.ecr_image_uri
}
