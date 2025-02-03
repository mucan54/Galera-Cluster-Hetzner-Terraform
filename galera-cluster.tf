terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.44.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
}

variable "ssh_key_path" {
  description = "Path to the SSH public key"
  type        = string
}

variable "server_count" {
  description = "Number of database nodes"
  type        = number
  default     = 3
}

variable "server_type" {
  description = "Type of Hetzner Cloud server"
  type        = string
  default     = "cx22"
}

variable "server_image" {
  description = "Image to use for the servers"
  type        = string
  default     = "debian-11"
}

variable "volume_size" {
  description = "Size of each volume in GB"
  type        = number
  default     = 50
}

variable "private_network_name" {
  description = "Name of the private network"
  type        = string
  default     = "galera-private-network"
}

variable "load_balancer_name" {
  description = "Name of the load balancer"
  type        = string
  default     = "galera-load-balancer"
}

variable "location" {
  description = "Hetzner Cloud location"
  type        = string
  default     = "fsn1"
}

resource "hcloud_ssh_key" "default" {
  name       = "default-ssh-key"
  public_key = file(var.ssh_key_path)
}

resource "hcloud_network" "private_network" {
  name     = var.private_network_name
  ip_range = "10.1.0.0/24"
}

resource "hcloud_network_subnet" "private_subnet" {
  network_id   = hcloud_network.private_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.1.0.0/24"
}

resource "hcloud_volume" "db_volumes" {
  count      = var.server_count
  name       = "db-node-${count.index + 1}-volume"
  size       = var.volume_size
  location   = var.location
  format     = "ext4"
  automount  = false
}

resource "hcloud_server" "db_nodes" {
  count       = var.server_count
  name        = "db-node-${count.index + 1}"
  server_type = var.server_type
  image       = var.server_image
  location    = var.location
  ssh_keys    = [hcloud_ssh_key.default.id]

  network {
    network_id = hcloud_network.private_network.id
    ip         = "10.1.0.${10 + count.index}"
  }

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    node_name       = "db-node-${count.index + 1}"
    node_ip         = "10.1.0.${10 + count.index}"
    cluster_ips     = join(",", [for i in range(var.server_count) : "10.1.0.${10 + i}"])
    mariadb_root_pw = "SecureRootPassword"
    volume_id       = hcloud_volume.db_volumes[count.index].id
    bootstrap       = count.index == 0 ? "true" : "false"
  })

  labels = {
    role = "db"
  }
}

resource "hcloud_volume_attachment" "db_volume_attachments" {
  count      = var.server_count
  server_id  = hcloud_server.db_nodes[count.index].id
  volume_id  = hcloud_volume.db_volumes[count.index].id
}

resource "hcloud_load_balancer" "galera_lb" {
  name               = var.load_balancer_name
  load_balancer_type = "lb11"
  location           = var.location
}

resource "hcloud_load_balancer_network" "lb_network" {
  load_balancer_id = hcloud_load_balancer.galera_lb.id
  network_id       = hcloud_network.private_network.id
}

resource "hcloud_load_balancer_service" "mysql_service" {
  load_balancer_id = hcloud_load_balancer.galera_lb.id
  protocol         = "tcp"
  listen_port      = 3306
  destination_port = 3306

  health_check {
    protocol = "tcp"
    port     = 3306
    interval = 15
    timeout  = 10
    retries  = 3
  }
}

resource "hcloud_load_balancer_target" "lb_targets" {
  count             = var.server_count
  load_balancer_id  = hcloud_load_balancer.galera_lb.id
  type              = "server"
  server_id         = hcloud_server.db_nodes[count.index].id
}