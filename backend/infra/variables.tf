variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
  default     = "910965283858"
}

variable "ecr_image_uri" {
  description = "Docker image stored in AWS ECR"
  type        = string
  default     = "910965283858.dkr.ecr.ap-south-1.amazonaws.com/cloud-deploy-app:v1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "Your public IP address with /32 for SSH access"
  type        = string
  default     = "45.118.105.167/32"
}