
variable "aws_region" {
  description = "AWS region to deploy resources into"
  type        = string
  default     = "ap-south-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the custom VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_2_cidr" {
  description = "CIDR block for the second public subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the public subnet and EC2 instance"
  type        = string
  default     = "ap-south-1a"
}

variable "availability_zone_2" {
  description = "Availability zone for the second public subnet"
  type        = string
  default     = "ap-south-1b"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.large"
}

variable "key_name" {
  description = "Optional EC2 key pair name for SSH access"
  type        = string
  default     = "bms"
}


resource "aws_vpc" "bookmyshow_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "bookmyshow-vpc"
  }
}

resource "aws_internet_gateway" "bookmyshow_igw" {
  vpc_id = aws_vpc.bookmyshow_vpc.id

  tags = {
    Name = "bookmyshow-igw"
  }
}

resource "aws_subnet" "bms-public_subnet" {
  vpc_id                  = aws_vpc.bookmyshow_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "bookmyshow-public-subnet"
  }
}

resource "aws_subnet" "bms-public_subnet_2" {
  vpc_id                  = aws_vpc.bookmyshow_vpc.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = var.availability_zone_2
  map_public_ip_on_launch = true

  tags = {
    Name = "bookmyshow-public-subnet-2"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.bookmyshow_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bookmyshow_igw.id
  }

  tags = {
    Name = "bookmyshow-public-rt"
  }
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.bms-public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route_table_association" "public_subnet_2_association" {
  subnet_id      = aws_subnet.bms-public_subnet_2.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_security_group" "bms-sg" {
  name        = "bookmyshow-ec2-sg"
  description = "Basic security group for EC2"
  vpc_id      = aws_vpc.bookmyshow_vpc.id

  dynamic "ingress" {
  for_each = [22, 25, 80, 443, 465, 6443]

  content {
    description = "Port ${ingress.value}"
    from_port   = ingress.value
    to_port     = ingress.value
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
  
dynamic "ingress" {
  for_each = [
    { from = 3000,  to = 10000 },
    { from = 30000, to = 32767 }
  ]

  content {
    description = "Port Range"
    from_port   = ingress.value.from
    to_port     = ingress.value.to
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
dynamic "ingress" {
  for_each = [
    { from = 3000,  to = 10000 },
    { from = 30000, to = 32767 }
  ]

  content {
    description = "Port Range"
    from_port   = ingress.value.from
    to_port     = ingress.value.to
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "bookmyshow-ec2-sg"
  }


}

resource "aws_instance" "bookmyshow_ec2" {
  ami                         = "ami-01a00762f46d584a1"
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.bms-public_subnet.id
  vpc_security_group_ids      = [aws_security_group.bms-sg.id]
  associate_public_ip_address = true
  key_name                    = var.key_name != "" ? var.key_name : null
  user_data                   = templatefile("./resource.sh", {})

  root_block_device {
    volume_size = 28
    volume_type = "gp3"
  }
    

  tags = {
    Name = "bookmyshow-ec2"
  }
}

output "vpc_id" {
  value = aws_vpc.bookmyshow_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.bms-public_subnet.id
}

output "public_subnet_2_id" {
  value = aws_subnet.bms-public_subnet_2.id
}

output "ec2_public_ip" {
  value = aws_instance.bookmyshow_ec2.public_ip
}

