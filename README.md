# 🚀 n8n Deployment Guide: GCP + DuckDNS + HTTPS

This guide provides a streamlined process for deploying n8n on Google Compute Engine using Terraform, with a permanent free domain and automatic SSL (HTTPS) for full compatibility with Telegram, Stripe, and other secure webhooks.

---

## 📋 Prerequisites
- A **Google Cloud Platform** project with billing enabled.
- A free **DuckDNS** account.

---

## Phase 1: Claim Your Permanent URL
Before touching the code, you must claim your free "name" on the internet.

1. Go to [DuckDNS.org](https://www.duckdns.org) and sign in.
2. Under **subdomains**, type a unique name (e.g., `jsmith-n8n`) and click **add domain**.
3. **Copy your Token and Subdomain name.** You will need these for Phase 3.

---

## Phase 2: Launch the Infrastructure
We will use **Google Cloud Shell** to provision the server using Terraform.

1. Open **Google Cloud Shell**.
2. Run these commands to build the server:
   ```bash
   # 1. Enable the Compute Engine API
   gcloud services enable compute.googleapis.com

   # 2. Clone the deployment repository
   git clone https://github.com/zalzah00/gce-n8n.git
   cd gce-n8n

   # 3. Initialize and apply Terraform
   terraform init
   terraform apply -var="project_id=$(gcloud config get-value project)" -auto-approve
   ```
3. Once complete, log into your new server via SSH:
   ```bash
   gcloud compute ssh n8n-server --zone=us-central1-a
   ```
   *(If prompted, press **Y** and hit **Enter** twice to skip the passphrase).*

---

## Phase 3: The "One-Touch" Student Setup
Once you are **inside** the server terminal (prompt says `ubuntu@n8n-server`), copy the block below into a notepad, **edit the first two lines**, then paste it into the terminal.

```bash
# --- ⚠️ EDIT THE TWO LINES BELOW ⚠️ ---
DOMAIN="your-subdomain-here"
TOKEN="your-token-here"
# --------------------------------------

# 1. Clean up any existing attempts
sudo docker stop n8n caddy || true
sudo docker rm n8n caddy || true
sudo docker network rm n8n-bridge || true

# 2. Create the private bridge network
sudo docker network create n8n-bridge

# 3. Force initial DuckDNS Sync
IP=$(curl -s http://checkip.amazonaws.com)
curl -s "https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=$IP"

# 4. Setup the HTTPS config (Caddyfile)
cat <<EOF > Caddyfile
$DOMAIN.duckdns.org {
    reverse_proxy n8n:5678
}
EOF

# 5. Launch n8n (The Automation Engine)
sudo docker run -d --name n8n --restart always \
  --network n8n-bridge \
  -v /home/ubuntu/n8n-data:/home/node/.n8n \
  -e WEBHOOK_URL="https://$DOMAIN.duckdns.org/" \
  n8nio/n8n

# 6. Launch the HTTPS Provider (Caddy)
sudo docker run -d --name caddy --restart always \
  -p 80:80 -p 443:443 \
  --network n8n-bridge \
  -v $(pwd)/Caddyfile:/etc/caddy/Caddyfile \
  -v caddy_data:/data \
  caddy

# 7. Enable Auto-Sync (Updates IP every 5 mins automatically)
(crontab -l 2>/dev/null; echo "*/5 * * * * curl -s 'https://www.duckdns.org/update?domains=$DOMAIN&token=$TOKEN&ip=' >/dev/null 2>&1") | crontab -

echo "--------------------------------------------------------"
echo "✅ SETUP COMPLETE!"
echo "Wait 2 minutes for the SSL certificate to generate."
echo "Your n8n link: https://$DOMAIN.duckdns.org"
echo "--------------------------------------------------------"
```

---

## 💡 Important Tips for Success

### 1. The "2-Minute" Rule & Progress Check
After running the script, your server needs about 120 seconds to "handshake" with the certificate authority. 

**How to check if it's ready:**
Run this command in your terminal:
```bash
sudo docker logs -f caddy
```
Watch for a line that says: **`"msg":"certificate obtained successfully"`**. Once you see that, your site is live! (Press `Ctrl+C` to exit the logs).

### 2. Telegram Compatibility
Because this setup uses `https`, Telegram and other services will work perfectly. Always ensure your bot settings use the `https://` version of your URL.

### 3. Saving Your $5 Budget
To save credits, **STOP** your instance in the Google Cloud Console when not in use. 
- **To Resume:** Start the instance in the console, SSH back in, and **re-run Phase 3**. Your workflows will be exactly where you left them!

### 4. Port Check
Ensure your `main.tf` has ports **80** and **443** open in the firewall section. Without these, the HTTPS setup will fail.
```hcl
  allow {
    protocol = "tcp"
    ports    = ["5678", "80", "443"]
  }
```
