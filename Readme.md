Repository Directory Structuretexttf-ansible-lab/
├── terraform/
│   ├── backend.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── security-groups.tf
│   ├── bastion.tf
│   ├── alb.tf
│   ├── asg-app.tf
│   ├── rds.tf
│   ├── iam.tf
│   └── outputs.tf
└── ansible/
    ├── ansible.cfg
    ├── inventory/
    │   └── aws_ec2.yml
    ├── group_vars/
    │   └── all.yml
    ├── site.yml
    └── roles/
        ├── hardening/tasks/main.yml
        ├── webserver/tasks/main.yml
        └── app_deploy/tasks/main.yml

🛠️ Terraform Configuration Files 

terraform/backend.tf
terraform {
  required_version = ">= 1.7.0"
  backend "s3" {
    bucket         = "adi-lab-tfstate-2026"
    key            = "3tier-lab/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-table"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
---------------------------------
terraform/variables.tf
variable "aws_region" { default = "us-east-1" }
variable "vpc_cidr" { default = "10.20.0.0/16" }
variable "azs" { default = ["us-east-1a", "us-east-1b"] }
variable "public_subnets" { default = ["10.20.0.0/24", "10.20.1.0/24"] }
variable "app_subnets" { default = ["10.20.10.0/24", "10.20.11.0/24"] }
variable "db_subnets" { default = ["10.20.20.0/24", "10.20.21.0/24"] }
variable "key_name" { default = "adi-lab-key" }
variable "instance_type" { default = "t3.micro" }
variable "db_username" { default = "labadmin" }
variable "db_password" { sensitive = true }
----------------------------------
terraform/vpc.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "lab-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "lab-igw" }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-public-${count.index}" }
}

resource "aws_subnet" "app" {
  count             = length(var.app_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.app_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "lab-app-${count.index}" }
}

resource "aws_subnet" "db" {
  count             = length(var.db_subnets)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.db_subnets[count.index]
  availability_zone = var.azs[count.index]
  tags              = { Name = "lab-db-${count.index}" }
}

resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "lab-nat" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "lab-public-rt" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "lab-private-rt" }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = length(aws_subnet.app)
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "db" {
  count          = length(aws_subnet.db)
  subnet_id      = aws_subnet.db[count.index].id
  route_table_id = aws_route_table.private.id
}
-----------------------------------------
terraform/security-groups.tf
resource "aws_security_group" "bastion" {
  name   = "lab-bastion-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "SSH from my IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["<YOUR_PUBLIC_IP>/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "alb" {
  name   = "lab-alb-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
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

resource "aws_security_group" "app" {
  name   = "lab-app-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description     = "HTTP from ALB only"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }
  ingress {
    description     = "SSH from bastion only"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name   = "lab-db-sg"
  vpc_id = aws_vpc.main.id
  ingress {
    description     = "MySQL from app tier only"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
---------------------------
terraform/iam.tf
resource "aws_iam_role" "app_role" {
  name = "lab-app-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "://amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.app_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "lab-app-instance-profile"
  role = aws_iam_role.app_role.name
}
----------------------
terraform/bastion.tf
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  tags                   = { Name = "lab-bastion" }
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}
------------------
terraform/alb.tf
resource "aws_lb" "app" {
  name               = "lab-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "app" {
  name     = "lab-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  health_check {
    path                = "/health"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
----------------------------
terraform/asg-app.tf
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
-------------------------
terraform/rds.tf
resource "aws_db_subnet_group" "db" {
  name       = "lab-db-subnet-group"
  subnet_ids = aws_subnet.db[*].id
}

resource "aws_db_instance" "app_db" {
  identifier             = "lab-app-db"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  db_subnet_group_name   = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.db.id]
  username               = var.db_username
  password               = var.db_password
  multi_az               = true
  skip_final_snapshot    = true
  backup_retention_period = 7
  publicly_accessible    = false
}
----------------------
terraform/outputs.tf
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "alb_dns_name" {
  value = aws_lb.app.dns_name
}

output "db_endpoint" {
  value     = aws_db_instance.app_db.endpoint
  sensitive = true
}
=========================================================================================


📜 Ansible Configuration

Files  ansible/ansible.cfgini[defaults]
inventory = ./inventory/aws_ec2.yml
host_key_checking = False
retry_files_enabled = False

[ssh_connection]
ssh_args = -o ProxyCommand="ssh -W %h:%p -q ec2-user@<BASTION_PUBLIC_IP>"
Use code with caution.ansible/inventory/aws_ec2.ymlyamlplugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Role: webapp
  instance-state-name: running
keyed_groups:
  - key: tags.Role
    prefix: role
hostnames:
  - private-ip-address
compose:
  ansible_host: private_ip_address
-------------------------

ansible/group_vars/all.yml
app_port: 80
app_user: appuser
db_host: "{{ hostvars['localhost']['db_endpoint'] | default('') }}"
Use code with caution.ansible/site.ymlyaml- name: Configure and deploy the healthcare web app platform
  hosts: role_webapp
  become: yes
  roles:
    - hardening
    - webserver
    - app_deploy
------------------------
ansible/roles/hardening/tasks/main.yml
- name: Ensure all packages are updated (patch management)
  ansible.builtin.dnf:
    name: "*"
    state: latest
  register: patch_result

- name: Disable root SSH login
  ansible.builtin.lineinfile:
    path: /etc/ssh/sshd_config
    regexp: '^PermitRootLogin'
    line: 'PermitRootLogin no'
  notify: restart sshd

- name: Enforce password-less sudo is disabled for app user
  ansible.builtin.lineinfile:
    path: /etc/sudoers.d/appuser
    create: yes
    line: "appuser ALL=(ALL) PASSWD: ALL"
    mode: '0440'

- name: Ensure firewalld is enabled and running
  ansible.builtin.systemd:
    name: firewalld
    enabled: true
    state: started

- name: Install and enable auditd for audit logging (HIPAA §164.312 audit control)
  ansible.builtin.dnf:
    name: audit
    state: present

- name: Enable auditd service
  ansible.builtin.systemd:
    name: auditd
    enabled: true
    state: started
---------------------------------
ansible/roles/webserver/tasks/main.yml

- name: Install nginx
  ansible.builtin.dnf:
    name: nginx
    state: present

- name: Deploy nginx reverse-proxy config
  ansible.builtin.template:
    src: nginx.conf.j2
    dest: /etc/nginx/conf.d/app.conf
  notify: restart nginx

- name: Deploy health check endpoint for ALB
  ansible.builtin.copy:
    content: "OK"
    dest: /usr/share/nginx/html/health
    mode: '0644'

- name: Ensure nginx is enabled and running
  ansible.builtin.systemd:
    name: nginx
    enabled: true
    state: started
-------------------
ansible/roles/webserver/templates/nginx.conf.j2  

nginxserver {
    listen 80;
    location /health {
        root /usr/share/nginx/html;
        try_files /health =200;
    }
    location / {
        proxy_pass http://127.0.0.1:{{ app_port }};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
-------------------------------
ansible/roles/app_deploy/tasks/main.yml

- name: Create application user
  ansible.builtin.user:
    name: "{{ app_user }}"
    system: yes
    shell: /sbin/nologin

- name: Pull application artifact from S3
  ansible.builtin.command: >
    aws s3 cp s3://lab-app-artifacts/app-latest.tar.gz /opt/app.tar.gz
  args:
    creates: /opt/app.tar.gz

- name: Extract application
  ansible.builtin.unarchive:
    src: /opt/app.tar.gz
    dest: /opt/app
    remote_src: yes

- name: Template application environment file
  ansible.builtin.template:
    src: app.env.j2
    dest: /opt/app/.env
    owner: "{{ app_user }}"
    mode: '0600'

- name: Start application service
  ansible.builtin.systemd:
    name: app
    enabled: true
    state: restarted
--------------------
If you need help setting up your GitHub Actions workflows to automate this deployment or want me to create the README.md file detailing the architectural steps and deployment execution commands for this repository, let me know!AI can make mistakes, so double-check responses You said: create read me file as well🏥 Secure 3-Tier Healthcare Web Application Platform (Terraform + Ansible)This repository contains the complete Infrastructure as Code (IaC) and Configuration Management to provision and configure a secure, repeatable, 3-tier web application environment on AWS (pp. 1-2). The architecture is designed to satisfy strict compliance frameworks such as HIPAA and HITRUST by ensuring data isolation, restricted admin access, and comprehensive audit controls (pp. 2, 9, 15).🏗️ Architecture OverviewThe system architecture follows a zero-direct-public-access model across two Availability Zones (pp. 2-3):Public Tier: Contains an Application Load Balancer (ALB) and a hardened Bastion Host (pp. 2-3).Private App Tier: Hosts an Auto Scaling Group (ASG) of EC2 application servers (pp. 2-3).Isolated Private DB Tier: Runs a highly available MySQL RDS instance (pp. 2-3).


          |
  [ Internet Gateway ]
          |
============================================================

|  Public Subnet AZ-a        |  Public Subnet AZ-b         |
|  - Bastion Host            |  - NAT Gateway              |
|  - ALB (Multi-AZ)          |  - ALB (Multi-AZ)           |
============================================================
          |
============================================================

|  Private App Subnet AZ-a   |  Private App Subnet AZ-b    |
|  - EC2 (Auto Scaling)      |  - EC2 (Auto Scaling)       |
============================================================
          |
============================================================

|  Private DB Subnet AZ-a    |  Private DB Subnet AZ-b     |
|  - RDS MySQL (Primary)     |  - RDS MySQL (Standby)      |
============================================================

🔒 Key Security Controls Built-InZero Public IPs: No application server or database instance is assigned a public IP (p. 3).Least Privilege Security Groups: Ingress rules point directly to specific security groups rather than open CIDR blocks (p. 9).Credential-Free EC2: Instances utilize AWS Systems Manager (SSM) Instance Profiles instead of hardcoded IAM access keys on disk (p. 10).HIPAA Compliance Hardening: Automated CIS-style OS patching, disabled root SSH logins, and full audit logging via auditd (p. 15).📂 Repository Structuretexttf-ansible-lab/
├── terraform/                  # Infrastructure provisioning
│   ├── backend.tf              # Remote state definition
│   ├── variables.tf            # Configurable network & sizing parameters
│   ├── vpc.tf                  # Subnets, NAT, and route tables
│   ├── security-groups.tf      # Tier-to-tier firewall rules
│   ├── bastion.tf              # Admin jumpbox configuration
│   ├── alb.tf                  # External load balancer rules
│   ├── asg-app.tf              # Compute cluster & automation trigger
│   ├── rds.tf                  # Database definition
│   ├── iam.tf                  # Least privilege roles
│   └── outputs.tf              # Pipeline outputs
└── ansible/                    # Configuration management
    ├── ansible.cfg             # SSH ProxyJump setup
    ├── inventory/
    │   └── aws_ec2.yml         # AWS Dynamic Inventory plugin
    ├── group_vars/
    │   └── all.yml             # Global playbook variables
    ├── site.yml                # Master orchestration playbook
    └── roles/
        ├── hardening/          # OS Security & compliance tasks
        ├── webserver/          # Nginx proxy deployment
        └── app_deploy/         # Application artifact extraction

🛠️ PrerequisitesEnsure your deployment workstation has the following tools installed and configured (p. 4):AWS CLI v2 configured with necessary provisioning permissions (p. 4).Terraform v1.7+ (p. 4)Ansible v2.15+ (p. 4)Python packages: boto3 and botocore (required for AWS dynamic inventory) (p. 4).🚀 Deployment Steps1. Bootstrap the Remote State BackendTerraform state must be stored securely with locking to prevent team state corruption (p. 5). Execute these commands once to prepare your backend infrastructure (p. 5):bash# Create the S3 bucket
aws s3api create-bucket --bucket adi-lab-tfstate-2026 --region us-east-1

# Enable bucket versioning
aws s3api put-bucket-versioning --bucket adi-lab-tfstate-2026 --versioning-configuration Status=Enabled

# Create the DynamoDB locking table
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST
Use code with caution.2. Configure Local VariablesOpen terraform/security-groups.tf and replace <YOUR_PUBLIC_IP> with your workstation's public IP address to lock down SSH access (p. 8).Store your desired database password securely in AWS Secrets Manager so it remains uncommitted in version control (p. 13):bashexport TF_VAR_db_password=$(aws secretsmanager get-secret-value \
  --secret-id lab/db-password --query SecretString --output text)
Use code with caution.3. Initialize and Apply InfrastructureRun the following to provision the full platform. A null_resource handler is embedded to automatically trigger the Ansible execution loop exactly 60 seconds after your cluster registers (p. 17):bashcd terraform
terraform init
terraform apply -auto-approve
Use code with caution.🔍 ValidationOnce execution completes successfully, evaluate your public load balancer endpoint to confirm both routing and security filters are functional (p. 17):bash# Check the platform load balancer health check endpoint
curl http://$(terraform output -raw alb_dns_name)/health
# Expected Output: OK

# Access the running platform homepage
curl http://$(terraform output -raw alb_dns_name)/
Use code with caution.🔧 Troubleshooting Common HurdlesAnsible UNREACHABLE / SSH Timeout: If the Bastion Host was recreated, your proxy configurations may be holding a stale IP address (p. 18). Run terraform output bastion_public_ip to verify, then update ansible/ansible.cfg (p. 18).ALB Health Checks Failing: If instances continuously cycle out of service, the Nginx application deployment role likely failed before registration occurred (p. 18). Inspect logs via AWS Systems Manager Session Manager (pp. 10, 18).Dynamic Inventory Finds 0 Hosts: Verify your local AWS environment identity possesses the ec2:DescribeInstances permission (p. 18). The dynamic inventory engine depends on this to query active tags (pp. 12, 14, 18).🧹 CleanupAvoid ongoing cloud billing charges by tearing down infrastructure resources immediately after testing (p. 19). Always review a destruction plan first when managing assets in shared organizational accounts (p. 19).bashcd terraform
terraform destroy -auto-approve

# Optionally remove the state bootstrap resources
aws dynamodb delete-table --table-name terraform-lock-table
aws s3 rb s3://adi-lab-tfstate-2026 --force
Use code with caution.
