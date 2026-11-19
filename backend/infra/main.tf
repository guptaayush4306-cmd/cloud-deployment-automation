# 1. Get available availability zones

data "aws_availability_zones" "available" {
  state = "available"
}

# 2. Get the latest Ubuntu 24.04 AMI

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# 3. Create VPC

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "clouddeploy-vpc"
  }
}

# 4. Create public subnet

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "clouddeploy-public-subnet"
  }
}

# 5. Create Internet Gateway

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "clouddeploy-igw"
  }
}

# 6. Create route table

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "clouddeploy-public-rt"
  }
}

# 7. Associate route table with subnet

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 8. Create security group

resource "aws_security_group" "app_sg" {
  name        = "clouddeploy-sg"
  description = "Allow SSH and application traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH access from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "FastAPI application"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "clouddeploy-sg"
  }
}

# 9. Create IAM role for EC2

resource "aws_iam_role" "ec2_role" {
  name = "clouddeploy-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "ec2.amazonaws.com"
      }

      Action = "sts:AssumeRole"
    }]
  })
}

# 10. Allow EC2 to pull images from ECR

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 11. Allow EC2 Systems Manager access

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role = aws_iam_role.ec2_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# 12. Create IAM instance profile

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "clouddeploy-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# 13. Create EC2 instance

resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true

  user_data = <<-EOF
    #!/bin/bash
    set -eux

    apt-get update -y
    apt-get install -y docker.io awscli

    systemctl enable docker
    systemctl start docker

    aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin \
      ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    docker pull ${var.ecr_image_uri}

    docker run -d \
      --name cloud-app \
      --restart unless-stopped \
      -p 8000:8000 \
      ${var.ecr_image_uri}
  EOF

  tags = {
    Name = "clouddeploy-ec2"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecr_access
  ]
}
