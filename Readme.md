

                  InfraStructure Design 
               
<img width="1408" height="768" alt="image" src="https://github.com/user-attachments/assets/5fd7b343-75c7-4fb4-ac59-1fc69afbffaf" />
# 🏥 Secure 3-Tier Healthcare Web Application Platform

An enterprise-grade, highly available infrastructure environment built on AWS using **Terraform** for resource provisioning and **Ansible** for automated compliance configurations. The architecture is engineered to satisfy strict security benchmarks by ensuring total data isolation, restricted admin access, and comprehensive audit controls.

---

## 🗺️ Infrastructure Design

<img width="1408" height="768" alt="AWS Infrastructure Architecture Diagram" src="https://github.com" />

### 🔒 Key Security Controls Built-In
* **Zero Public IPs**: No application server or database instance is assigned a public IP to eliminate direct external scanning.
* **Least Privilege Security Groups**: Ingress rules point directly to specific security groups rather than open CIDR blocks.
* **Credential-Free EC2**: Instances utilize AWS Systems Manager (SSM) Instance Profiles instead of hardcoded IAM access keys on disk.
* **HIPAA Compliance Hardening**: Automated CIS-style OS patching, disabled root SSH logins, and full audit logging via `auditd`.

---

## 📂 Repository Structure

```text
tf-ansible-lab/
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
```

---

## 🛠️ System Configuration Breakdown

### 🔷 Core Network Layer
* **Resource File:** `terraform/vpc.tf`
* **Infrastructure Components:** Provisions the isolated Virtual Private Cloud (`VPC`), Internet Gateway, NAT Gateway routing systems, and explicit path configurations.
* **Subnet Partitioning:** Decouples infrastructure into strict **Public**, **Private Application**, and **Isolated Private Database** segments spanning across dual Availability Zones for native high availability.

### 🔷 Global Parameters & State Management
* **Resource Files:** `terraform/variables.tf` & `terraform/backend.tf`
* **State Locking:** Locks concurrent team deployments securely using a dedicated AWS DynamoDB matrix.
* **Encrypted Storage:** Persists architectural runtime state records within a version-controlled Amazon S3 cloud instance.

### 🔷 Firewall Security Perimeters
* **Resource File:** `terraform/security-groups.tf`
* **Administrative Access:** Restricts administrative incoming `SSH` endpoints exclusively to a single, verified workstation IP address through a hardened Bastion host.
* **Tier-to-Tier Isolation:** Enforces strict internal boundaries: the Application Load Balancer routes traffic *only* to the app cluster, and database nodes *only* accept traffic originating from the application tier.

### 🔷 Identity & Access Governance
* **Resource File:** `terraform/iam.tf`
* **Credential-Free Compute:** Replaces structural hardcoded AWS access keys with dynamic, short-lived token engine profiles attached directly to compute processes.
* **Policy Attachment:** Bundles secure standard compliance management connectivity permissions (`AmazonSSMManagedInstanceCore`) down to operational hosts automatically.

### 🔷 Administrative Gateway Node
* **Resource File:** `terraform/bastion.tf`
* **Operational Role:** Serves as the strictly protected entry point for all remote engineer configurations.
* **Base Image Configuration:** Automatically resolves and bootstraps the environment utilizing the latest stable, patched distributions of Amazon Linux 2023.

### 🔷 Application Distribution & Traffic Balancing
* **Resource File:** `terraform/alb.tf`
* **Ingress Routing:** Standardizes incoming HTTP traffic across multiple Availability Zones.
* **Resiliency Monitors:** Implements automated health checking to intercept, flag, and remove malfunctioning processing units out of rotation.

### 🔷 Elastic Compute Cluster
* **Resource File:** `terraform/asg-app.tf`
* **Dynamic Scaling:** Standardizes standard active operating bounds with integrated automated target policies.
* **Automation Hooks:** Embedded configuration management handlers trigger system compliance playbooks exactly 60 seconds post-boot initialization.

### 🔷 High-Availability Database Engine
* **Resource File:** `terraform/rds.tf`
* **Data Tier Processing:** Provisions a fully managed MySQL instance tucked safely away inside the isolated storage subnet blocks.
* **Disaster Recovery:** Enforces at-rest disk encryption alongside real-time Multi-AZ database mirroring for continuous protection.

### 🔷 Deployment Diagnostics & Pipeline Outputs
* **Resource File:** `terraform/outputs.tf`
* **Pipeline Interoperability:** Generates clean terminal configuration flags including target load balancer URLs and Bastion endpoints upon successful execution loops.

---

## ⚙️ Automated Configuration Management

### 🔶 Orchestration Settings
* **Resource File:** `ansible/ansible.cfg`
* **Tunneling Mechanics:** Routes all administrative tasks securely by proxying connections through the Bastion gateway to hit internal target private addresses.

### 🔶 Dynamic Resource Discovery
* **Resource File:** `ansible/inventory/aws_ec2.yml`
* **Target Selection:** Dynamically queries operational AWS APIs to identify, group, and inventory hosts using structural resource tags (`Role: webapp`).

### 🔶 Structural Execution Entrypoint
* **Resource File:** `ansible/site.yml`
* **Playbook Execution Matrix:** Sequences configuration phases down to matched resource groups, pulling variables directly from shared environmental modules (`ansible/group_vars/all.yml`).

### 🔶 System Hardening Role
* **Resource File:** `ansible/roles/hardening/tasks/main.yml`
* **Security Control Matrix:** 
  * Updates system baseline packages to enforce active patch management protocols.
  * Explicitly deauthorizes administrative root `SSH` console connection capability.
  * Installs and configures system auditing systems (`auditd`) to comply with strict medical regulatory framework logging.

### 🔶 Proxy Services Role
* **Resource File:** `ansible/roles/webserver/tasks/main.yml`
* **Reverse Proxy Layer:** Deploys and configures a reverse-proxy routing profile (`nginx.conf.j2`) to direct ingress load balancing requests over internal loops cleanly.

### 🔶 Application Pipeline Deployment
* **Resource File:** `ansible/roles/app_deploy/tasks/main.yml`
* **Artifact Injection:** Instantiates standard isolated runtime accounts, secures environment target variable objects (`app.env.j2`), and safely pulls validated build artifacts out of cloud object storage.

---

## 🛠️ Prerequisites

Ensure your deployment workstation has the following tools installed and configured:
* **AWS CLI v2** configured with necessary provisioning permissions.
* **Terraform v1.7+**
* **Ansible v2.15+**
* **Python packages**: `boto3` and `botocore` (required for AWS dynamic inventory parsing).

---

## 🚀 Deployment Steps

### 1. Bootstrap the Remote State Backend
Terraform state must be stored securely with locking to prevent team state corruption. Execute these commands once to prepare your backend infrastructure:

```bash
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
```

### 2. Configure Local Variables
Open `terraform/security-groups.tf` and replace `<YOUR_PUBLIC_IP>` with your workstation's public IP address to lock down SSH access.

Store your desired database password securely in AWS Secrets Manager so it remains uncommitted in version control:
```bash
export TF_VAR_db_password=$(aws secretsmanager get-secret-value \
  --secret-id lab/db-password --query SecretString --output text)
```

### 3. Initialize and Apply Infrastructure
Run the following to provision the full platform. A `null_resource` handler is embedded to automatically trigger the Ansible execution loop exactly 60 seconds after your cluster registers:

```bash
cd terraform
terraform init
terraform apply -auto-approve
```

---

## 🔍 Validation

Once execution completes successfully, evaluate your public load balancer endpoint to confirm both routing and security filters are functional:

```bash
# Check the platform load balancer health check endpoint
curl http://$(terraform output -raw alb_dns_name)/health
# Expected Output: OK

# Access the running platform homepage
curl http://$(terraform output -raw alb_dns_name)/
```
