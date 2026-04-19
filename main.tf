provider "google" {
  project = var.project_id
  region  = "us-central1"
}

variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

# 1. Firewall Rule to allow n8n traffic (Port 5678)
resource "google_compute_firewall" "n8n_firewall" {
  name    = "allow-n8n-web-ui"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["5678"]
  }

  # Allows access from any computer on the internet
  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["n8n-server"]
}

# 2. The Compute Instance
resource "google_compute_instance" "n8n_vm" {
  name         = "n8n-server"
  machine_type = "e2-small"      # 2GB RAM (Stable for n8n)
  zone         = "us-central1-a"
  tags         = ["n8n-server"]  # Connects VM to the firewall rule above

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Leaving this empty assigns an Ephemeral Public IP (Required for DuckDNS)
      network_tier = "STANDARD" 
    }
  }

  scheduling {
    preemptible        = true    # Keeps costs low (~$0.19/day)
    provisioning_model = "SPOT"
    automatic_restart  = false
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    # 1. Create 2GB Swap File (Prevents crashes on smaller machines)
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab

    # 2. Update and install Docker
    apt-get update && apt-get install -y docker.io
    systemctl enable --now docker

    # 3. Setup folder and PERMISSIONS
    mkdir -p /home/ubuntu/n8n-data
    chown -R 1000:1000 /home/ubuntu/n8n-data
  EOT
}

output "instance_ip" {
  value = google_compute_instance.n8n_vm.network_interface.0.access_config.0.nat_ip
}
