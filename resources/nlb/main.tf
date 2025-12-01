resource "aws_lb" "this" {
  name               = "${var.project_name}-speech-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = var.subnet_ids

  enable_cross_zone_load_balancing = true

  tags = var.tags
}

resource "aws_lb_target_group" "this" {
  name        = "${var.project_name}-speech-tg"
  port        = var.port
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Required for Fargate

  health_check {
    protocol = "TCP"
  }

  tags = var.tags
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}
