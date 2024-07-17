resource "aws_vpc" "dock-web" {
  cidr_block = "11.0.0.0/16"
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.dock-web.id
  cidr_block = "11.0.1.0/24"
  availability_zone = "eu-west-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "public-2" {
  vpc_id     = aws_vpc.dock-web.id
  cidr_block = "11.0.3.0/24"
  availability_zone = "eu-west-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet_2"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.dock-web.id
  cidr_block = "11.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "private_subnet"
  }
}

resource "aws_security_group" "vpc_sg" {
  name        = "vpc_sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.dock-web.id

  ingress{
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

  egress{
  from_port = 80
  to_port = 80
  protocol = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}
}

resource "aws_internet_gateway" "int_gw" {
  vpc_id = aws_vpc.dock-web.id

  tags = {
    Name = "gateway-for-public-subnets"
  }
}

resource "aws_instance" "ec2_ins" {
  ami           = data.aws_ami.example.id
  instance_type = "t3.micro"
  vpc_security_group_ids = [aws_security_group.vpc_sg.id]
  subnet_id = aws_subnet.public.id
  user_data = filebase64("${path.module}/ecs.sh")
  iam_instance_profile = aws_iam_instance_profile.test_profile.name
  key_name = aws_key_pair.ecs-key-pair.key_name

  tags = {
    Name = "test-docker-app"
  }
}

resource "aws_key_pair" "ecs-key-pair" {
key_name = "ecs-key-pair"
public_key = tls_private_key.ecs-pri.public_key_openssh
}

resource "tls_private_key" "ecs-pri" {
algorithm = "RSA"
rsa_bits  = 4096
}


resource "local_file" "ecs-key" {
content  = tls_private_key.ecs-pri.private_key_pem
filename = "ecs-key-pair"
}

resource "aws_iam_instance_profile" "test_profile" {
  name = "test_profile"
  role = aws_iam_role.test_role.name
}

resource "aws_eip" "eip" {
  instance = aws_instance.ec2_ins.id
  domain   = "vpc"
}

# resource "aws_nat_gateway" "nat_gw" {
#   allocation_id = aws_eip.eip.id
#   subnet_id     = aws_subnet.private.id

#   tags = {
#     Name = "gw NAT"
#   }

#   # To ensure proper ordering, it is recommended to add an explicit dependency
#   # on the Internet Gateway for the VPC.
#   depends_on = [aws_internet_gateway.int_gw]
# }

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.dock-web.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.int_gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.route.id
}

# resource "aws_launch_template" "ecs_ec2" {
#   name_prefix            = "demo-ecs-ec2"
#   image_id               = data.aws_ami.example.id
#   instance_type          = "t2.micro"
#   vpc_security_group_ids = [aws_security_group.vpc_sg.id]
#   user_data = filebase64("${path.module}/ecs.sh")



#   iam_instance_profile { arn = aws_iam_instance_profile.test_profile.arn }
#   monitoring { enabled = true }

