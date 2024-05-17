# VPC creation 
resource "aws_vpc" "web_main" {
  cidr_block = "10.0.0.0/16"
  

  tags = {
    Name = "web-mainvpc"
    # Add other tags as needed
  }
}

resource "aws_subnet" "public_subnets" {
 count      = length(var.public_subnet_cidrs)
 vpc_id     = aws_vpc.web_main.id
 cidr_block = element(var.public_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 map_public_ip_on_launch = true
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.web_main.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 availability_zone = element(var.azs, count.index)
 map_public_ip_on_launch = true
 tags = {
   Name = "Private Subnet ${count.index + 1}"
 }
}


#Internet gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.web_main.id

  tags = {
    Name = "igwmain"
  }
}

# Second Route table (Public)
resource "aws_route_table" "second_rt" {
  vpc_id = aws_vpc.web_main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  
  tags = {
    Name = "Second Route Table"
  }
}

#route table association
resource "aws_route_table_association" "public_subnet_asso" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public_subnets[count.index].id
  route_table_id = aws_route_table.second_rt.id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "NAT Gateway EIP"
  }
}

#Nat Gateway
resource "aws_nat_gateway" "web_nat" {
   allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_subnets[0].id

  tags = {
    Name = "gw NAT"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw]
}

#Routetable

# Creating a Route Table for the Nat Gateway!
resource "aws_route_table" "web_nat_rt" {
  depends_on = [
    aws_nat_gateway.web_nat
  ]

  vpc_id = aws_vpc.web_main.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.web_nat.id
  }

  tags = {
    Name = "Route Table for NAT Gateway"
  }

}

#Routetable association Nat gateway
resource "aws_route_table_association" "private_subnet_asso" {
  count = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.web_nat_rt.id
}


resource "aws_launch_template" "web_server_template" {
  name_prefix             = "webServer"
  image_id                = "ami-07caf09b362be10b8" // Replace with your desired AMI
  instance_type           = "t2.micro"
  key_name                = "web-server" // Specify your key pair name here
  vpc_security_group_ids  = [aws_security_group.web_server_sg.id]

  user_data = filebase64("apache-install.sh")

tags = {
    Name = "webser_instance"

    
  }

}

#ASG
resource "aws_autoscaling_group" "autoscale" {
  name                  = "test-autoscaling-group"
  desired_capacity      = 2
  max_size              = 5
  min_size              = 2
  health_check_type     = "EC2"
  vpc_zone_identifier   = [
    aws_subnet.public_subnets[0].id,
    aws_subnet.public_subnets[1].id
  ]

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  launch_template {
    id      = aws_launch_template.web_server_template.id
    version = "$Latest"  # Assuming you're using the latest version
  }
}


resource "aws_security_group" "web_server_sg" {
  name        = "web-server-sg"
  description = "Security group for web server"

  vpc_id      = aws_vpc.web_main.id 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "test" {
  name               = "test-lb-tf"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_server_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

    tags = {
    Name = "webServer-alb"
  }
}




 resource "aws_lb_listener" "my_alb_listener" {
 load_balancer_arn = aws_lb.test.arn
 port              = "80"
 protocol          = "HTTP"

 default_action {
   type             = "forward"
   target_group_arn = aws_lb_target_group.web_tg.arn
 }
}

resource "aws_lb_target_group" "web_tg" { // Target Group A
 name     = "target-group"
 port     = 80
 protocol = "HTTP"
 vpc_id   = aws_vpc.web_main.id
}

