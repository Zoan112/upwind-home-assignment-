# Configure the AWS Provider
provider "aws" {
  region = var.aws-region
}

# Variables
variable "aws-region" {
  description = "AWS region"
  type        = string
}

variable "upwind_client_id" {
  description = "Upwind client ID"
  type        = string
  #sensitive   = true  # Mark as sensitive to protect in logs
}

variable "upwind_client_secret" {
  description = "Upwind client secret"
  type        = string
  #sensitive   = true  # Mark as sensitive to protect in logs
}

variable "user_name" {
  description = "Upwind user"
  type        = string
}

variable "instance-name" {
  description = "Instance name"
  type        = string
}

variable "aws-ssh-key-name" {
  description = "AWS SSH key name"
  type        = string
}



# Create a security group to allow SSH access
resource "aws_security_group" "allow_ssh" {
  name_prefix = "allow_ssh_"  # Using name_prefix for better uniqueness
  description = "Allow SSH inbound traffic"

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
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
    Name = "allow_ssh"
    Purpose = "SSH access"
  }
}

# Create IAM role for SSM
resource "aws_iam_role" "ssm_role" {
  name = "ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach the SSM policy to the role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Create instance profile
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "ssm-profile"
  role = aws_iam_role.ssm_role.name
}

# Create an EC2 instance
resource "aws_instance" "upwind-instance" {
  ami                    = "ami-0acefc55c3a331fa8"  # Ubuntu AMI
  instance_type          = "t4g.large"
  iam_instance_profile   = aws_iam_instance_profile.ssm_profile.name
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  key_name              = var.aws-ssh-key-name
  root_block_device {
    volume_size = 20 # Specify the size in GB
    volume_type = "gp3" # General-purpose SSD
  }

user_data = base64encode(<<-EOF
              #!/bin/bash
              
              # Set environment variables
              export UPWIND_AGENT_CLOUD_PROVIDER="BYOC"
              export UPWIND_AGENT_CLOUD_ACCOUNT_ID="byoc-${var.user_name}"
              export UPWIND_AGENT_ZONE="byoc-london"
              
              # Install Upwind agent
              curl -fSsl https://get.upwind.io/agent.sh | bash -s -- \
                upwind_client_id="${var.upwind_client_id}" \
                upwind_client_secret="${var.upwind_client_secret}"
              EOF
  )


  tags = {
    Name        = var.instance-name
    Managed_by  = "terraform"
    Purpose     = "upwind-agent"
  }

}

# Outputs
output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.upwind-instance.public_ip
}

output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.upwind-instance.id
}

output "instance_state" {
  description = "Current state of the EC2 instance"
  value       = aws_instance.upwind-instance.instance_state
}