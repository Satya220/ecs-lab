resource "aws_launch_configuration" "foobar" {
  name          = "ecs_config"
  image_id      = data.aws_ami.example.id
  instance_type = "t3.micro"
  security_groups = [aws_security_group.asg_sg.id]
  key_name = aws_key_pair.ecs-key-pair.key_name
}

resource "aws_autoscaling_group" "bar" {
  desired_capacity   = 2
  launch_configuration = aws_launch_configuration.foobar.name
  max_size           = 2
  min_size           = 2
  vpc_zone_identifier = [aws_subnet.public.id,aws_subnet.public-2.id]

  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }
}

resource "aws_security_group" "asg_sg" {
  name        = "asg-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.dock-web.id

ingress{
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks=  [aws_vpc.dock-web.cidr_block]
    }

    egress{
        from_port = 0
        to_port = 0
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
    Name = "asg_sg"
  }
}


resource "aws_ecs_capacity_provider" "test" {
  name = "test"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.bar.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 3
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 2
    }
  }
}


resource "aws_ecs_task_definition" "service" {
  family = "service"
  # network_mode = "awsvpc"
  execution_role_arn = aws_iam_role.exec_role.arn
  # task_role_arn = "arn:aws:iam::633739933116:role/ecsInstanceRole"

  container_definitions = jsonencode([
    {
      name      = "1st"
      image     = "httpd"
      # cpu       = 10
      # memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
    ])

  volume {
    name      = "service-storage"
    host_path = "/ecs/service-storage"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [eu-west-1a, eu-west-1b]"
  }
}

resource "aws_ecs_task_set" "example" {
  service         = aws_ecs_service.web-ecs.id
  cluster         = aws_ecs_cluster.test.id
  task_definition = aws_ecs_task_definition.service.arn

  load_balancer {
    target_group_arn = aws_lb_target_group.test.arn
    container_name   = "1st"
    container_port   = 80
  }
}

resource "aws_kms_key" "example" {
  description             = "key_for_ecs"
  deletion_window_in_days = 7
}

resource "aws_cloudwatch_log_group" "example" {
  name = "tp_logs"
}

resource "aws_ecs_cluster" "test" {
  name = "web-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  configuration {
    execute_command_configuration {
      kms_key_id = aws_kms_key.example.arn
      logging    = "OVERRIDE"
      

      log_configuration {
        cloud_watch_encryption_enabled = true
        cloud_watch_log_group_name     = aws_cloudwatch_log_group.example.name
      }
    }
  }
}

resource "aws_ecs_cluster_capacity_providers" "example" {
  cluster_name = aws_ecs_cluster.test.name

  capacity_providers = [aws_ecs_capacity_provider.test.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.test.name
  }
}

resource "aws_ecs_service" "web-ecs" {
  name            = "ecs-web"
  cluster         = aws_ecs_cluster.test.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 3
  iam_role        = "arn:aws:iam::153707729340:role/aws-service-role/ecs.amazonaws.com/AWSServiceRoleForECS"
  # depends_on      = "arn:aws:iam::aws:policy/aws-service-role/AmazonECSServiceRolePolicy"
  launch_type =  "EC2"

  ordered_placement_strategy {
    type  = "binpack"
    field = "cpu"
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.test.arn
    container_name   = "1st"
    container_port   = 80
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
  }
}

##IAM ROLE
# resource "aws_iam_role" "test_role" {
#   name = "iam_role_ecs"

#   # Terraform's "jsonencode" function converts a
#   # Terraform expression result to valid JSON syntax.
#   assume_role_policy = jsonencode({
    
#     "Version": "2012-10-17",
#     "Statement": [
#         {
#             "Effect": "Allow",
#             "Action": [
#                 "ec2:DescribeTags",
#                 "ecs:CreateCluster",
#                 "ecs:DeregisterContainerInstance",
#                 "ecs:DiscoverPollEndpoint",
#                 "ecs:Poll",
#                 "ecs:RegisterContainerInstance",
#                 "ecs:StartTelemetrySession",
#                 "ecs:UpdateContainerInstancesState",
#                 "ecs:Submit*",
#                 "ecr:GetAuthorizationToken",
#                 "ecr:BatchCheckLayerAvailability",
#                 "ecr:GetDownloadUrlForLayer",
#                 "ecr:BatchGetImage",
#                 "logs:CreateLogStream",
#                 "logs:PutLogEvents"
#             ],
#             "Resource": "*"
#         },
#         {
#             "Effect": "Allow",
#             "Action": "ecs:TagResource",
#             "Resource": "*",
#             "Condition": {
#                 "StringEquals": {
#                     "ecs:CreateAction": [
#                         "CreateCluster",
#                         "RegisterContainerInstance"
#                     ]
#                 }
#             }
#         }
#     ]
#   })

#   tags = {
#     tag-key = "tag-value"
#   }
# }

# resource "aws_iam_role_policy_attachment" "example_attachment" {
#   role       = aws_iam_role.test_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
# }

resource "aws_iam_role" "test_role" {
  name = "test_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
    ]
})

  tags = {
    tag-key = "tag-value"
  }
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.test_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role" "exec_role" {
  name = "exec_role"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = jsonencode({
    
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
    ]
})

  tags = {
    tag-key = "exec-value"
  }
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

