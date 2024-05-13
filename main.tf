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