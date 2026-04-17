# ECS Auto-Scaling Application with Monitoring

A production-ready Node.js application deployed on AWS ECS Fargate with auto-scaling policies, comprehensive monitoring using Prometheus and Grafana, and automated service discovery.

## 📋 Project Structure

```
.
├── index.js                              # Express.js main application
├── package.json                          # Node.js dependencies
├── Dockerfile                            # Multi-stage Docker build (Alpine)
├── customers.json                        # Sample data for API
│
├── infra/                                # Infrastructure as Code (Terraform)
│   ├── main.tf                          # Terraform backend & provider config
│   ├── ecs.tf                           # ECS cluster, task, and service definitions
│   ├── autoscaling.tf                   # Auto-scaling policies for ECS
│   ├── networking.tf                    # VPC, subnets, and security groups
│   ├── alb.tf                           # Application Load Balancer configuration
│   ├── iam.tf                           # IAM roles and policies
│   ├── logs.tf                          # CloudWatch log groups
│   ├── security.tf                      # Security group rules
│   ├── outputs.tf                       # Terraform outputs
│   ├── terraform.tfstate                # State file (S3 backend)
│   └── terraform.tfstate.backup         # State backup
│
├── monitoring/
│   └── monitoring.sh                    # EC2 setup script for Prometheus & Grafana
│
├── ecs-service-discovery-script.py     # Python service discovery for dynamic targets
│
├── grafana_dashboard.json               # Grafana dashboard definition
│
└── screenshots/                         # Documentation screenshots
```

## 🚀 Key Features

### Application
- **Framework**: Express.js (Node.js 18-Alpine)
- **API Endpoints**:
  - `GET /health` - Health check endpoint
  - `GET /api/customers` - Customers API with filtering and pagination
  - `GET /metrics` - Prometheus metrics endpoint (prom-client)
- **Pagination Support**: Search by first_name, last_name, city with page/limit parameters
- **Prometheus Integration**: Built-in metrics collection with `prom-client`

### Deployment
- **Container Registry**: Docker Hub (anim45/practiseecs:latest)
- **Orchestration**: AWS ECS Fargate
- **Compute**: 256 CPU units, 512 MB memory per task
- **Networking**: Tasks deployed in private subnets for security
- **Load Balancing**: Application Load Balancer (ALB) for traffic distribution
- **Logging**: CloudWatch Logs integration (`/ecs/my-node-app`)

### Auto-Scaling
- **Scaling Policy**: Target Tracking (CPU-based)
- **Metric**: ECS Service Average CPU Utilization
- **Target**: 70% CPU threshold
- **Replicas**: Min 2, Max 5, Desired 2
- **Cool-down**: 60 seconds (scale-in and scale-out)

### Monitoring & Observability
- **Prometheus**: Metrics collection and storage
  - Scrape interval: 15 seconds
  - Node Exporter for system metrics
  - ECS file-based service discovery
- **Grafana**: Visualization and dashboards
- **Service Discovery**: Python script automatically discovers ECS tasks and updates Prometheus targets

### CI/CD
- **Pipeline**: GitHub Actions
- **Authentication**: GitHub OIDC (OpenID Connect) to AWS
- **Image Registry**: Docker Hub push on workflow completion

---

## 🛠️ Infrastructure Details

### Terraform Configuration
The infrastructure is managed using Terraform with the following key resources:

| File | Purpose |
|------|---------|
| `main.tf` | S3 backend configuration for state management with encryption |
| `ecs.tf` | ECS cluster, task definitions, and service configuration |
| `autoscaling.tf` | CPU-based auto-scaling policies (min: 2, max: 5) |
| `networking.tf` | VPC, public/private subnets, NAT gateway |
| `alb.tf` | Application Load Balancer and target groups |
| `iam.tf` | IAM roles for ECS task execution and GitHub OIDC |
| `logs.tf` | CloudWatch log groups for centralized logging |
| `security.tf` | Security group rules and network ACLs |

**State Management**: S3 backend with encryption and state locking

---

## 📊 Monitoring Setup

### Prometheus Configuration
- **Job 1**: Prometheus self-monitoring (localhost:9090)
- **Job 2**: EC2 instances (auto-discovered)
- **Job 3**: ECS tasks (file-based service discovery via Python script)

### Service Discovery Script
The `ecs-service-discovery-script.py` automates target discovery:

```python
# How it works:
1. Queries ECS for all clusters and tasks
2. Retrieves network interface details for each task
3. Extracts private IP addresses from ENI
4. Generates ecs_file_sd.yml with discovered targets
5. Prometheus reads YAML and adds targets dynamically
```

**Execution**: Runs every minute via cron job
```bash
* * * * * /usr/bin/python3 /path/to/ecs-service-discovery-script.py
```

### Grafana Dashboards
- Import via `grafana_dashboard.json`
- Visualizations for:
  - CPU and Memory utilization
  - Request rates and latencies
  - Error rates and health status
  - Task scaling events

---

## 📝 Prometheus YAML Configuration

### Complete prometheus.yml Setup

The Prometheus configuration file (`/etc/prometheus/prometheus.yml`) needs to include three main scrape configurations:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Job 1: Prometheus Self-Monitoring
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  # Job 2: EC2 Instances (Node Exporter)
  - job_name: "ec2-instances"
    ec2_sd_configs:
      - region: ap-south-1
        port: 9100
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance

  # Job 3: ECS Tasks (File-Based Service Discovery)
  - job_name: "ecs-tasks"
    scrape_interval: 15s
    file_sd_configs:
      - files:
          - /etc/prometheus/ecs_file_sd.yml
        refresh_interval: 30s
    relabel_configs:
      - source_labels: [__address__]
        target_label: __param_target
      - source_labels: [__param_target]
        target_label: instance
      - target_label: __address__
        replacement: localhost:9090
```

### How File-Based Service Discovery Works

#### 1. **Service Discovery Script Output** (`ecs_file_sd.yml`)
The Python script `ecs-service-discovery-script.py` generates a YAML file:

```yaml
- targets:
  - 10.0.1.45:4000
  - 10.0.2.78:4000
  - 10.0.1.92:4000
  - 10.0.2.34:4000
```

#### 2. **Flow Diagram**
```
┌─────────────────────────────────────────────────────────────────┐
│  ECS Cluster (AWS)                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │  Task 1      │  │  Task 2      │  │  Task 3      │          │
│  │ 10.0.1.45:   │  │ 10.0.2.78:   │  │ 10.0.1.92:   │          │
│  │    4000      │  │    4000      │  │    4000      │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
           ↑              ↑              ↑
           │              │              │
           └──────────────┼──────────────┘
                          │
          ┌───────────────▼────────────────┐
          │ ecs-service-discovery-script.py│
          │ (Runs every 1 minute via cron) │
          │                                 │
          │ 1. Query ECS API                │
          │ 2. Get ENI IP addresses         │
          │ 3. Write to YAML file           │
          └───────────────┬────────────────┘
                          │
          ┌───────────────▼────────────────┐
          │  /etc/prometheus/              │
          │    ecs_file_sd.yml             │
          └───────────────┬────────────────┘
                          │
          ┌───────────────▼────────────────┐
          │ Prometheus                      │
          │ (reads YAML every 30s)         │
          │ Updates targets & scrapes      │
          │ Stores metrics in time-series  │
          └────────────────────────────────┘
```

#### 3. **Configuration Details**

| Parameter | Value | Purpose |
|-----------|-------|---------|
| `file_sd_configs` | `/etc/prometheus/ecs_file_sd.yml` | Path where Python script writes targets |
| `refresh_interval` | 30s | How often Prometheus re-reads the YAML file |
| `scrape_interval` | 15s | How often Prometheus scrapes each target |

#### 4. **Python Script Execution**

**Cron Job Setup:**
```bash
# SSH into EC2 instance and add to crontab:
crontab -e

# Add this line (runs every minute):
* * * * * /usr/bin/python3 /path/to/ecs-service-discovery-script.py

# Verify cron job:
crontab -l
```

**Script Logic:**
```python
1. Connect to ECS API (ap-south-1 region)
2. Get all clusters
3. For each cluster, list all tasks
4. For each task:
   - Get network interface ID (ENI)
   - Query EC2 API for private IP address
   - Append to targets list
5. Write targets to /etc/prometheus/ecs_file_sd.yml in YAML format
6. Prometheus detects the file change and reloads targets
```

#### 5. **Important Notes**

- **Target Format**: `IP_ADDRESS:PORT` (e.g., `10.0.1.45:4000`)
- **Port**: Must match your application port in ECS (port 4000 in our case)
- **Region**: Update region in both Python script and Prometheus config if different
- **Permissions**: Ensure Prometheus user has read permissions on `ecs_file_sd.yml`
- **Dynamic Scaling**: When new tasks spin up due to auto-scaling, the script discovers them within 1 minute
- **Task Termination**: When tasks scale down, they're removed from the YAML on the next cron run

#### 6. **Testing the Configuration**

```bash
# Check if prometheus is reading targets:
curl http://localhost:9090/api/v1/targets

# Check targets for ecs-tasks job:
curl http://localhost:9090/api/v1/targets?job=ecs-tasks

# View YAML file contents:
cat /etc/prometheus/ecs_file_sd.yml

# Check Prometheus logs:
journalctl -u prometheus -f
```

---

## 🔧 Technologies Used

### Application & Containerization
- Node.js 18 (Alpine Linux)
- Express.js - Web framework
- prom-client - Prometheus metrics
- Docker - Containerization

### Cloud & Infrastructure
- AWS ECS Fargate - Container orchestration
- AWS ALB - Load balancing
- AWS CloudWatch - Logging and monitoring
- AWS IAM - Identity and access management
- Terraform - Infrastructure as Code
- S3 - State management

### Monitoring & Observability
- Prometheus - Metrics collection
- Grafana - Visualization
- Node Exporter - System metrics

### CI/CD
- GitHub Actions - CI/CD pipeline
- GitHub OIDC - Secure AWS authentication
- Docker Hub - Image registry

---

## 📈 Performance & Scalability

- **Task Scaling**: Automatically scales from 2 to 5 replicas based on CPU utilization
- **Health Checks**: ALB performs regular health checks on `/health` endpoint
- **Metrics Scraping**: Prometheus scrapes every 15 seconds with 1-minute cron-based discovery
- **Log Retention**: CloudWatch logs for audit and debugging
- **Multi-AZ Deployment**: Tasks spread across private subnets in different AZs

---

## 🔐 Security Features

- **Private Subnets**: Application tasks run in isolated private subnets
- **Encrypted State**: Terraform state stored in S3 with encryption
- **IAM Roles**: Least privilege principle for ECS task execution
- **Network Isolation**: Security groups restrict inbound/outbound traffic
- **OIDC Integration**: GitHub OIDC for federated authentication (no long-lived credentials)

---

## 📸 Screenshots & Visual Documentation

### 1. Grafana dashboard
![Architecture Screenshot 1](./screenshots/Screenshot%202026-04-13%20201954.png)

### 2. Prometheus Dashboard
![ECS Setup](./screenshots/Screenshot%202026-04-13%20202047.png)

### 3. ECS Cluster
![Task Definition](./screenshots/Screenshot%202026-04-13%20202141.png)

### 4. ECS Service
![Scaling Metrics](./screenshots/Screenshot%202026-04-13%20202154.png)

### 5. Tasks
![Service Discovery](./screenshots/Screenshot%202026-04-13%20202211.png)

### 6. ALB endpoint 
![Prometheus Targets](./screenshots/Screenshot%202026-04-13%20202242.png)

### 7. Github Actions Pipeline - Overview
![Grafana Overview](./screenshots/Screenshot%202026-04-13%20202329.png)

### 8. Github actions workflows - Overview
![Monitoring Config](./screenshots/Screenshot%202026-04-13%20202429.png)

---

## 🚀 Deployment Steps

### 1. Prerequisites
- AWS account with ap-south-1 region
- Terraform installed
- Python 3 with boto3

### 2. Infrastructure Deployment
```bash
cd infra/
terraform init
terraform plan
terraform apply
```

### 3. Monitoring Setup (EC2 Instance)
```bash
# SSH into EC2 instance
ssh -i your-key.pem ec2-user@your-ec2-instance

# Run monitoring setup script
bash monitoring.sh

# Install and schedule service discovery script
python3 ecs-service-discovery-script.py

# Add to crontab (runs every minute)
(crontab -l 2>/dev/null; echo "* * * * * /usr/bin/python3 /path/to/ecs-service-discovery-script.py") | crontab -
```

### 4. CI/CD Pipeline (GitHub Actions)
Push to repository with GitHub Actions workflow configured for:
- Building Docker image
- Pushing to Docker Hub
- Deploying to ECS via Terraform

---

## 📝 API Examples

### Health Check
```bash
curl http://alb-dns/health
# Response: {"message":"Health is running OK"}
```

### List Customers with Filters
```bash
# Search by first name
curl "http://alb-dns/api/customers?first_name=John&page=1&limit=10"

# Search by city
curl "http://alb-dns/api/customers?city=NewYork&page=1&limit=10"

# Pagination
curl "http://alb-dns/api/customers?page=2&limit=20"
```

### Prometheus Metrics
```bash
curl http://task-private-ip:4000/metrics
```

---

## 📚 Key Learnings

This project demonstrates:

✅ **Container Orchestration**: ECS Fargate for serverless container management  
✅ **Infrastructure as Code**: Terraform for reproducible AWS infrastructure  
✅ **Auto-Scaling**: Dynamic scaling based on CPU metrics  
✅ **Observability**: Prometheus + Grafana for comprehensive monitoring  
✅ **Service Discovery**: Automated dynamic target discovery for dynamic environments  
✅ **Security**: Private networking, IAM roles, and encrypted state  
✅ **CI/CD**: GitHub Actions with OIDC for secure deployments  
✅ **Best Practices**: Multi-stage Docker builds, health checks, log aggregation  

---

## Highlights

This project showcases essential cloud-native and DevOps skills:

- **AWS ECS Fargate & Orchestration**: Designed and deployed containerized Node.js application with Fargate launch type, demonstrating knowledge of serverless container management
- **Terraform IaC**: Built complete infrastructure using Terraform (networking, ECS, ALB, IAM, logging) with S3 backend state management
- **Auto-Scaling & Performance**: Implemented CPU-based auto-scaling policies (min: 2, max: 5 replicas) with 70% target threshold
- **Monitoring & Observability**: Set up complete observability stack with:
  - Prometheus for metrics collection and scraping
  - Grafana for visualization and dashboards
  - CloudWatch for centralized logging
- **Service Discovery**: Built Python script that dynamically discovers ECS tasks and updates Prometheus targets every minute via cron
- **Security**: Implemented security best practices including:
  - Tasks in private subnets with NAT gateway
  - IAM roles with least privilege
  - GitHub OIDC for federated AWS authentication (no long-lived credentials)
  - Encrypted Terraform state in S3
- **CI/CD Pipeline**: Configured GitHub Actions workflow with OIDC authentication and automated Docker Hub pushes
- **Networking**: Designed ALB for load balancing across private subnets in multiple AZs
- **API Development**: Built RESTful API with Express.js featuring:
  - Advanced filtering and pagination
  - Built-in Prometheus metrics endpoint
  - Health checks

---

## 📖 Project Documentation

- **API Testing**: Import `Application.postman_collection.json` into Postman
- **Grafana Dashboards**: Import `grafana_dashboard.json` for pre-built visualizations
- **Setup Scripts**: `monitoring.sh` automates Prometheus, Grafana, and Node Exporter installation
- **Service Discovery**: `ecs-service-discovery-script.py` enables dynamic target discovery
- **Infrastructure Code**: See `/infra` directory for all Terraform configurations

---