data "aws_ami" "example" {
  most_recent      = true
  owners           = ["591542846629"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-2.0.20230705-x86_64-ebs"]
  }
  
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]

}
}

# data "aws_iam_role" "example" {
#   name = "ecsInstanceRole"
# }
