resource "aws_launch_template" "app" {
  name_prefix            = "lab-app-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile {
    name = aws_iam_instance_profile.app_profile.name
  }
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "lab-app-server"
      Role = "webapp"
      Env  = "lab"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "lab-app-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 4
  vpc_zone_identifier = aws_subnet.app[*].id
  target_group_arns   = [aws_lb_target_group.app.arn]
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "lab-app-server"
    propagate_at_launch = true
  }
  tag {
    key                 = "Role"
    value               = "webapp"
    propagate_at_launch = true
  }
}

resource "null_resource" "run_ansible" {
  depends_on = [aws_autoscaling_group.app]
  provisioner "local-exec" {
    command = <<-EOT
      sleep 60
      cd ../ansible && ansible-playbook site.yml
    EOT
  }
  triggers = {
    asg_id = aws_autoscaling_group.app.id
  }
}
