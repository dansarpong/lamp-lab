output "web-link" {
  value = "http://${aws_lb.lab-alb.dns_name}"
}
