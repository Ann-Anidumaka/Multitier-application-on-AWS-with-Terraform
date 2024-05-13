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
 
 tags = {
   Name = "Public Subnet ${count.index + 1}"
 }
}
 
resource "aws_subnet" "private_subnets" {
 count      = length(var.private_subnet_cidrs)
 vpc_id     = aws_vpc.web_main.id
 cidr_block = element(var.private_subnet_cidrs, count.index)
 
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
