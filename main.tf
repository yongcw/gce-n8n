provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  type = string
}

# 1. THE GATE (Firewall)
resource "google_compute_firewall" "n8n_firewall" {
  name    = "allow-n8n-web-ui"
  network = "default"

  allow {
    protocol = "tcp"
    # Unified list: 80/443 for HTTPS, 5678 for n8n dashboard
    ports    = ["80", "443", "5678"]
  }

  source_ranges = ["0.0.0.0/0"]
  # This MUST match the tag on the VM below
  target_tags   = ["n8n-node"] 
}

# 2. THE SERVER (VM)
resource "google_compute_instance" "n8n_vm" {
  name         = "n8n-server"
  machine_type = "e2-small"
  zone         = "us-central1-a"
  
  # This TAG is what opens the ports. 
  # If this is missing or misspelled, HTTPS will fail.
  tags         = ["n8n-node"] 

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      network_tier = "STANDARD" 
    }
  }

  scheduling {
    preemptible        = true
    provisioning_model = "SPOT"
    automatic_restart  = false
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # Create Swap (Emergency RAM)
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # Install Docker
    apt-get update && apt-get install -y docker.io
    systemctl enable --now docker

    # Prepare data folder
    mkdir -p /home/ubuntu/n8n-data
    chown -R 1000:1000 /home/ubuntu/n8n-data
  EOT
}
