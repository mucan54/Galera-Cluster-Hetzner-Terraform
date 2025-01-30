# Galera Cluster Deployment with Terraform on Hetzner Cloud

## Overview
This repository provides an **automated solution** for deploying a **MariaDB Galera Cluster** on **Hetzner Cloud** using **Terraform** and **cloud-init**. It includes:

✅ **Terraform scripts** to provision:
   - Hetzner Cloud servers
   - Attached storage volumes for MySQL data
   - Private networking
   - Load balancer for high availability

✅ **Cloud-init scripts** for:
   - Automatic **MariaDB and Galera Cluster installation**
   - Configuration of **Galera multi-node replication**
   - Attaching and mounting dedicated **storage volumes** for `/var/lib/mysql`
   - Scheduled **cleanup tasks for logs, temp files, and database optimization**

## Infrastructure Diagram
```
               +----------------------------+
               |       Load Balancer        |
               |       (Port: 3306)         |
               +----------------------------+
                        |       |       |
      --------------------------------------------------
      |                  |                  |          
+----------------+  +----------------+  +----------------+
|  db-node-1    |  |  db-node-2    |  |  db-node-3    |
|  10.1.0.10    |  |  10.1.0.11    |  |  10.1.0.12    |
|  Galera Node  |  |  Galera Node  |  |  Galera Node  |
|  Volume: 50GB |  |  Volume: 50GB |  |  Volume: 50GB |
+----------------+  +----------------+  +----------------+
```

## Prerequisites
1. **Terraform** installed ([Install Terraform](https://developer.hashicorp.com/terraform/downloads))
2. **Hetzner Cloud API Token** ([Generate Token](https://console.hetzner.cloud/))
3. **SSH Key** added to Hetzner Cloud

## Setup Guide

### 1️⃣ Clone Repository
```sh
 git clone https://github.com/your-username/galera-cluster-terraform.git
 cd galera-cluster-terraform
```

### 2️⃣ Set Up Your Hetzner API Token
Create a `.tfvars` file and add your Hetzner Cloud token:
```sh
nano terraform.tfvars
```
```hcl
hcloud_token = "your_hetzner_api_token"
ssh_key_path = "~/.ssh/id_rsa.pub"
```

### 3️⃣ Initialize Terraform
```sh
terraform init
```

### 4️⃣ Plan the Deployment
```sh
terraform plan
```

### 5️⃣ Deploy the Infrastructure
```sh
terraform apply -auto-approve
```

### 6️⃣ Verify Galera Cluster
SSH into any node and check cluster status:
```sh
mysql -u root -p -e "SHOW STATUS LIKE 'wsrep_cluster_size';"
```

## Features
### 🚀 Automated MariaDB + Galera Cluster Setup
- Installs **MariaDB** & **Galera** on each node automatically
- Configures **Galera Cluster** for multi-node replication

### 🗄️ Dedicated Storage Volumes for MySQL
- Each node gets **a separate volume** (e.g., 50GB SSD)
- Volumes are **mounted at `/var/lib/mysql`**

### 🔄 Automatic System Maintenance (Cron Jobs)
- **Daily log cleanup** (`/var/log`) - removes files older than 7 days
- **Temp directory cleanup** (`/tmp`) - removes files older than 1 day
- **Weekly MySQL optimization** (`OPTIMIZE TABLE`)

## Cleanup & Destroy Infrastructure
To remove all created resources:
```sh
terraform destroy -auto-approve
```

## Troubleshooting
### ❌ Issue: Cluster Nodes Not Joining
- Verify nodes can reach each other:
  ```sh
  ping 10.1.0.11
  ```
- Check MariaDB service:
  ```sh
  systemctl status mariadb
  ```

### ❌ Issue: Storage Volume Not Mounted
- Check if the volume is attached:
  ```sh
  lsblk
  ```
- Manually mount:
  ```sh
  mount /dev/disk/by-id/scsi-0HC_Volume_db-node-1-volume /var/lib/mysql
  ```

## License
This project is licensed under the MIT License.

## Author
Developed by [Can Özdemir](https://github.com/mucan54). Contributions are welcome! 🚀

