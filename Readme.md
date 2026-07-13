

               InfraStructure Design 
               
<img width="1408" height="768" alt="image" src="https://github.com/user-attachments/assets/5fd7b343-75c7-4fb4-ac59-1fc69afbffaf" />

🔒 Key Security Controls Built-InZero Public IPs: No application server or database instance is assigned a public IP (p. 3).Least Privilege Security Groups: Ingress rules point directly to specific security groups rather than open CIDR blocks (p. 9).Credential-Free EC2: Instances utilize AWS Systems Manager (SSM) Instance Profiles instead of hardcoded IAM access keys on disk (p. 10).HIPAA Compliance Hardening: Automated CIS-style OS patching, disabled root SSH logins, and full audit logging via auditd (p. 15).



📂 Repository Structuretexttf-ansible-lab/
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


🛠️ PrerequisitesEnsure your deployment workstation has the following tools installed and configured (p. 4):AWS CLI v2 configured with necessary provisioning permissions (p. 4).Terraform v1.7+ (p. 4)Ansible v2.15+ (p. 4)Python packages: boto3 and botocore (required for AWS dynamic inventory) (p. 4).🚀 Deployment Steps1. Bootstrap the Remote State BackendTerraform state must be stored securely with locking to prevent team state corruption (p. 5). Execute these commands once to prepare your backend infrastructure (p. 5)

# Create the S3 bucket
aws s3api create-bucket --bucket adi-lab-tfstate-2026 --region us-east-1

# Enable bucket versioning
aws s3api put-bucket-versioning --bucket adi-lab-tfstate-2026 --versioning-configuration Status=Enabled

# Create the DynamoDB locking table
aws dynamodb create-table \
  --table-name terraform-lock-table \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

2. Configure Local VariablesOpen terraform/security-groups.tf and replace <YOUR_PUBLIC_IP> with your workstation's public IP address to lock down SSH access (p. 8).Store your desired database password securely in AWS Secrets Manager so it remains uncommitted in version control (p. 13):bashexport TF_VAR_db_password=$(aws secretsmanager get-secret-value \
  --secret-id lab/db-password --query SecretString --output text)

3. Initialize and Apply InfrastructureRun the following to provision the full platform. A null_resource handler is embedded to automatically trigger the Ansible execution loop exactly 60 seconds after your cluster registers (p. 17):bashcd terraform
terraform init
terraform apply -auto-approve

🔍 ValidationOnce execution completes successfully, evaluate your public load balancer endpoint to confirm both routing and security filters are functional (p. 17):bash# Check the platform load balancer health check endpoint
curl http://$(terraform output -raw alb_dns_name)/health
# Expected Output: OK

# Access the running platform homepage
curl http://$(terraform output -raw alb_dns_name)/


🔧 Troubleshooting Common HurdlesAnsible UNREACHABLE / SSH Timeout: If the Bastion Host was recreated, your proxy configurations may be holding a stale IP address (p. 18). Run terraform output bastion_public_ip to verify, then update ansible/ansible.cfg (p. 18).ALB Health Checks Failing: If instances continuously cycle out of service, the Nginx application deployment role likely failed before registration occurred (p. 18). Inspect logs via AWS Systems Manager Session Manager (pp. 10, 18).Dynamic Inventory Finds 0 Hosts: Verify your local AWS environment identity possesses the ec2:DescribeInstances permission (p. 18). The dynamic inventory engine depends on this to query active tags (pp. 12, 14, 18).🧹 CleanupAvoid ongoing cloud billing charges by tearing down infrastructure resources immediately after testing (p. 19). Always review a destruction plan first when managing assets in shared organizational accounts (p. 19).bashcd terraform
terraform destroy -auto-approve

# Optionally remove the state bootstrap resources
aws dynamodb delete-table --table-name terraform-lock-table
aws s3 rb s3://adi-lab-tfstate-2026 --force

