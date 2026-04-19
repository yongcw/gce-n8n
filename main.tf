provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  type = string
}

resource "google_compute_firewall" "n8n_firewall" {
  name    = "allow-n8n-web-ui"
  network = "default"
  allow {
    protocol = "tcp"
    ports    = ["5678", "80", "443"]
  }
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["n8n-server"]
}

resource "google_compute_instance" "n8n_vm" {
  name         = "n8n-server"
  machine_type = "e2-small"
  zone         = "us-central1-a"
  tags         = ["n8n-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      network_tier = "STANDARD" # Cheaper than Premium
    }
  }

  scheduling {
    preemptible        = true
    provisioning_model = "SPOT"
    automatic_restart  = false
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Create Swap to prevent crashes
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Install Docker
    apt-get update && apt-get install -y docker.io
    systemctl enable --now docker

    # Setup Permissions
    mkdir -p /home/ubuntu/n8n-data
    chown -R 1000:1000 /home/ubuntu/n8n-data
  EOT
}
