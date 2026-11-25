# Latest Amazon Linux 2023 AMI, resolved from AWS's public SSM parameter
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# Learner Lab's pre-made instance profile wrapping LabRole
data "aws_iam_instance_profile" "lab" {
  name = "LabInstanceProfile"
}

resource "aws_security_group" "jenkins" {
  name        = "shopops-jenkins-sg"
  description = "Jenkins: SSH and UI from my IP only"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["105.110.248.16/32"]
  }

  ingress {
    description = "Jenkins UI from my IP"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["105.110.248.16/32"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "shopops-jenkins-sg" }
}

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ssm_parameter.al2023.value
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.jenkins.id]
  key_name               = "shopops-jenkins"
  iam_instance_profile   = data.aws_iam_instance_profile.lab.name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    dnf update -y
    dnf install -y docker java-21-amazon-corretto-headless git
    systemctl enable --now docker
    usermod -aG docker ec2-user

    # Jenkins (requires Java 21 or 25)
    wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
    rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    dnf install -y jenkins
    alternatives --set java /usr/lib/jvm/java-21-amazon-corretto.x86_64/bin/java
    usermod -aG docker jenkins
    systemctl enable --now jenkins

    # kubectl (matches EKS 1.35)
    curl -sLo /usr/local/bin/kubectl "https://dl.k8s.io/release/v1.35.0/bin/linux/amd64/kubectl"
    chmod +x /usr/local/bin/kubectl

    # Trivy
    curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin
  EOF

  tags = { Name = "shopops-jenkins" }
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

output "jenkins_ssh" {
  value = "ssh -i shopops-jenkins.pem ec2-user@${aws_instance.jenkins.public_ip}"
}