# ECS Cluster
resource "aws_ecs_cluster" "lamp-cluster" {
  name = "lamp-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "lamp-task" {
  family                   = "lamp-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs-task-execution-role.arn
  task_role_arn            = aws_iam_role.ecs-task-role.arn

  container_definitions = jsonencode([
    {
      name      = "php-app",
      image     = var.image
      essential = true,
      portMappings = [
        {
          containerPort = 80,
          hostPort      = 80,
          protocol      = "tcp"
        }
      ],
      environment = [
        { name = "DATABASE_USER", value = aws_db_instance.lab-mysql.username },
        { name = "DATABASE_HOST", value = aws_db_instance.lab-mysql.endpoint },
        { name = "DATABASE_PORT", value = tostring(aws_db_instance.lab-mysql.port) },
        { name = "DATABASE_NAME", value = "todo" }
      ],
      secrets = [
        { name = "DATABASE_PASSWORD", valueFrom = "${data.aws_secretsmanager_secret_version.db_creds.arn}:password::" }
      ],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = "ecs_logs"
          "awslogs-region"        = var.region,
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "lamp-service" {
  name            = "lamp-service"
  cluster         = aws_ecs_cluster.lamp-cluster.id
  task_definition = aws_ecs_task_definition.lamp-task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [aws_subnet.lab-public-a.id, aws_subnet.lab-public-b.id]
    security_groups  = [aws_security_group.ecs-sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.lab-alb-tg.arn
    container_name   = "php-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.lab-alb-listener]
}


# Application Load Balancer
resource "aws_lb" "lab-alb" {
  name               = "lab-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lab-alb-sg.id]
  subnets            = [aws_subnet.lab-public-a.id, aws_subnet.lab-public-b.id]
}

resource "aws_lb_listener" "lab-alb-listener" {
  load_balancer_arn = aws_lb.lab-alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lab-alb-tg.arn
  }
}

resource "aws_lb_target_group" "lab-alb-tg" {
  name        = "lab-alb-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.lab-vpc.id
  target_type = "ip"

  health_check {
    port     = 80
    protocol = "HTTP"
    timeout  = 5
    interval = 100
  }
}


# ECS Auto Scaling
resource "aws_appautoscaling_target" "ecs-target" {
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.lamp-cluster.name}/${aws_ecs_service.lamp-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs-scale-up" {
  name               = "ecs-scale-up"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs-target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs-target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs-target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = 1
      metric_interval_lower_bound = 0
    }
  }
}

resource "aws_appautoscaling_policy" "ecs-scale-down" {
  name               = "ecs-scale-down"
  policy_type        = "StepScaling"
  resource_id        = aws_appautoscaling_target.ecs-target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs-target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs-target.service_namespace

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 300
    metric_aggregation_type = "Average"

    step_adjustment {
      scaling_adjustment          = -1
      metric_interval_upper_bound = 0
    }
  }
}
