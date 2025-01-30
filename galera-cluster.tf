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
  default     = "cx21"
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
  }

  volumes = [hcloud_volume.db_volumes[count.index].id]

  user_data = templatefile("${path.module}/cloud-init.yaml", {
    node_name       = "db-node-${count.index + 1}"
    node_ip         = "10.1.0.${count.index + 10}"
    cluster_ips     = join(",", formatlist("10.1.0.%d", range(10, 10 + var.server_count)))
    mariadb_root_pw = "SecureRootPassword"
    volume_path     = "/dev/disk/by-id/scsi-0HC_Volume_db-node-${count.index + 1}-volume"
  })

  labels = {
    role = "db"
  }
}

resource "hcloud_load_balancer" "galera_lb" {
  name                = var.load_balancer_name
  load_balancer_type  = "lb11"
  location            = var.location
  network_id          = hcloud_network.private_network.id
  use_private_ip      = true
}

resource "hcloud_load_balancer_target" "lb_targets" {
  count             = var.server_count
  load_balancer_id  = hcloud_load_balancer.galera_lb.id
  type              = "server"
  server_id         = hcloud_server.db_nodes[count.index].id
}

resource "hcloud_load_balancer_service" "mysql_service" {
  load_balancer_id = hcloud_load_balancer.galera_lb.id
  protocol         = "tcp"
  listen_port      = 3306
  destination_port = 3306
}

resource "hcloud_load_balancer_service_health_check" "mysql_health_check" {
  load_balancer_service_id = hcloud_load_balancer_service.mysql_service.id
  protocol                 = "tcp"
  port                     = 3306
  interval                 = 15
  timeout                  = 10
  retries                  = 3
}
