provider "google" {
  project = var.project_id
  region  = "us-central1"
}

resource "google_compute_instance" "n8n_vm" {
  name         = "n8n-student-instance"
  machine_type = "e2-small"
  zone         = "us-central1-a"

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

  # THIS AUTOMATES EVERYTHING: Docker + Permissions + n8n Start
  metadata_startup_script = <<-EOT
    #!/bin/bash
    # 1. Install Docker
    apt-get update && apt-get install -y docker.io
    systemctl enable --now docker

    # 2. Setup folder and PERMISSIONS
    mkdir -p /home/ubuntu/n8n-data
    chown -R 1000:1000 /home/ubuntu/n8n-data

    # 3. Launch n8n immediately
    docker run -d --name n8n --restart always \
      -p 5678:5678 \
      -v /home/ubuntu/n8n-data:/home/node/.n8n \
      -e TZ=Asia/Singapore \
      n8nio/n8n
  EOT
}

output "instance_ip" {
  value = google_compute_instance.n8n_vm.network_interface.0.access_config.0.nat_ip
}
