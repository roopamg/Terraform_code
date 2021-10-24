provider "aws" {
    region = "us-east-2"
}

# resource "aws_instance" "web" {
#   ami           = "ami-00399ec92321828f5"
#   instance_type = "t2.micro"

#   tags = {
#     Name = "test_ec2"
#   }
# }

# Create VPC
resource "aws_vpc" "test_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "test_vpc"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "test_igw" {
  vpc_id = aws_vpc.test_vpc.id
  tags = {
    Name = "test_igw"
  }
}

# Create custom route table
resource "aws_route_table" "test_route_table" {
  vpc_id = aws_vpc.test_vpc.id

  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.test_igw.id
    }

  route {
      ipv6_cidr_block = "::/0"
      gateway_id = aws_internet_gateway.test_igw.id
  }

  tags = {
    Name = "test_route_table"
  }
}

# Create Subnet
resource "aws_subnet" "test_subnet" {
  vpc_id     =  aws_vpc.test_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-2a"
  tags = {
    Name = "test_subnet"
  }
}

# Associate subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.test_subnet.id
  route_table_id = aws_route_table.test_route_table.id
}

# Create security group to allow port 22,80,443
resource "aws_security_group" "test_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.test_vpc.id

  ingress = [
    {
      description      = "HTTP"
      from_port        = 80
      to_port          = 80
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]  
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    },
  {
      description      = "HTTPS"
      from_port        = 443
      to_port          = 443
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]  
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false      
  },

    {
      description      = "SSH"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]  
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false      
    }
  ]


  egress = [
    {
      description      = "for all outgoing traffics"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
      prefix_list_ids = []
      security_groups = []
      self = false
    }
  ]


  tags = {
    Name = "test_sg"
  }
}

# Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "test_ni" {
  subnet_id       = aws_subnet.test_subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.test_sg.id]

  tags = {
      Name = "test_ni"
  }
}

# Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "test_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.test_ni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.test_igw]

  tags = {
      Name = "test_eip"
  }
}

output "server_public_ip" {
  value = aws_eip.test_eip.public_ip
}

# Create Ubuntu server and install/enable apache2 
resource "aws_instance" "test_instance" {
  ami                    = "ami-00399ec92321828f5"
  instance_type          = "t2.micro"
  availability_zone      = "us-east-2a"  
  key_name               = "ubuntu"
  
  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.test_ni.id
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c 'echo your very first web server > /var/www/html/index.html'
                EOF
  tags = {
    Name = "web-server"
  }
}



output "server_private_ip" {
  value = aws_instance.test_instance.private_ip

}

output "server_id" {
  value = aws_instance.test_instance.id
}

