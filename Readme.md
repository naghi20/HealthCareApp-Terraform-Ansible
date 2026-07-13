

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

🏥 Secure 3-Tier Healthcare Web Application PlatformAn enterprise-grade, highly available infrastructure environment built on AWS using Terraform for resource provisioning and Ansible for automated compliance configurations.🛠️ System Configuration Breakdown🔷 Core Network LayerResource File: terraform/vpc.tfInfrastructure Components: Provisiones the isolated Virtual Private Cloud (VPC), Internet Gateway, NAT Gateway routing systems, and explicit path configurations.Subnet Partitioning: Decouples infrastructure into strict Public, Private Application, and Isolated Private Database segments spanning across dual Availability Zones for native high availability.🔷 Global Parameters & State ManagementResource Files: terraform/variables.tf & terraform/backend.tfState Locking: Locks concurrent team deployments securely using a dedicated AWS DynamoDB matrix.Encrypted Storage: Persists architectural runtime state records within a version-controlled Amazon S3 cloud instance.🔷 Firewall Security PerimetersResource File: terraform/security-groups.tfAdministrative Access: Restricts administrative incoming SSH endpoints exclusively to a single, verified workstation IP address through a hardened Bastion host.Tier-to-Tier Isolation: Enforces strict internal boundaries: the Application Load Balancer routes traffic only to the app cluster, and database nodes only accept traffic originating from the application tier.🔷 Identity & Access GovernanceResource File: terraform/iam.tfCredential-Free Compute: Replaces structural hardcoded AWS access keys with dynamic, short-lived token engine profiles attached directly to compute processes.Policy Attachment: Bundles secure standard compliance management connectivity permissions (AmazonSSMManagedInstanceCore) down to operational hosts automatically.🔷 Administrative Gateway NodeResource File: terraform/bastion.tfOperational Role: Serves as the strictly protected entry point for all remote engineer configurations.Base Image Configuration: Automatically resolves and bootstraps the environment utilizing the latest stable, patched distributions of Amazon Linux 2023.🔷 Application Distribution & Traffic BalancingResource File: terraform/alb.tfIngress Routing: Standardizes incoming HTTP traffic across multiple Availability Zones.Resiliency Monitors: Implements automated health checking to intercept, flag, and remove malfunctioning processing units out of rotation.🔷 Elastic Compute ClusterResource File: terraform/asg-app.tfDynamic Scaling: Standardizes standard active operating bounds with integrated automated target policies.Automation Hooks: Embedded configuration management handlers trigger system compliance playbooks exactly 60 seconds post-boot initialization.🔷 High-Availability Database EngineResource File: terraform/rds.tfData Tier Processing: Provisions a fully managed MySQL instance tucked safely away inside the isolated storage subnet blocks.Disaster Recovery: Enforces at-rest disk encryption alongside real-time Multi-AZ database mirroring for continuous protection.🔷 Deployment Diagnostics & Pipeline OutputsResource File: terraform/outputs.tfPipeline Interoperability: Generates clean terminal configuration flags including target load balancer URLs and Bastion endpoints upon successful execution loops.⚙️ Automated Configuration Management🔶 Orchestration SettingsResource File: ansible/ansible.cfgTunneling Mechanics: Routes all administrative tasks securely by proxying connections through the Bastion gateway to hit internal target private addresses.🔶 Dynamic Resource DiscoveryResource File: ansible/inventory/aws_ec2.ymlTarget Selection: Dynamically queries operational AWS APIs to identify, group, and inventory hosts using structural resource tags (Role: webapp).🔶 Structural Execution EntrypointResource File: ansible/site.ymlPlaybook Execution Matrix: Sequences configuration phases down to matched resource groups, pulling variables directly from shared environmental modules (ansible/group_vars/all.yml).🔶 System Hardening RoleResource File: ansible/roles/hardening/tasks/main.ymlSecurity Control Matrix:Updates system baseline packages to enforce active patch management protocols.Explicitly deauthorizes administrative root SSH console connection capability.Installs and configures system auditing systems (auditd) to comply with strict medical regulatory framework logging.🔶 Proxy Services RoleResource File: ansible/roles/webserver/tasks/main.ymlReverse Proxy Layer: Deploys and configures a reverse-proxy routing profile (nginx.conf.j2) to direct ingress load balancing requests over internal loops cleanly.🔶 Application Pipeline DeploymentResource File: ansible/roles/app_deploy/tasks/main.ymlArtifact Injection: Instantiates standard isolated runtime accounts, secures environment target variable objects (app.env.j2), and safely pulls validated build artifacts out of cloud object storage.
