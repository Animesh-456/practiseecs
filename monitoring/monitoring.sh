#!/bin/bash

set -e

# ─────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

PROMETHEUS_VERSION="3.10.0"
NODE_EXPORTER_VERSION="1.10.2"

# ─────────────────────────────────────────────
# 1. CLEANUP OLD INSTALLS
# ─────────────────────────────────────────────
log "Cleaning old Prometheus & Node Exporter (if any)..."

sudo systemctl stop prometheus 2>/dev/null || true
sudo systemctl stop node_exporter 2>/dev/null || true

sudo rm -f /etc/systemd/system/prometheus.service
sudo rm -f /etc/systemd/system/node_exporter.service

sudo rm -rf /etc/prometheus
sudo rm -rf /data

sudo rm -f /usr/local/bin/prometheus
sudo rm -f /usr/local/bin/promtool
sudo rm -f /usr/local/bin/node_exporter

sudo systemctl daemon-reload

# ─────────────────────────────────────────────
# 2. SYSTEM UPDATE
# ─────────────────────────────────────────────
log "Updating system..."
sudo apt update -y
sudo apt install -y wget curl tar libatomic1 gnupg apt-transport-https

# ─────────────────────────────────────────────
# 3. INSTALL PROMETHEUS
# ─────────────────────────────────────────────
log "Installing Prometheus..."

sudo useradd --system --no-create-home --shell /bin/false prometheus 2>/dev/null || true

cd /tmp
rm -rf prometheus*

wget -q https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

tar -xf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64

# Directories
sudo mkdir -p /etc/prometheus
sudo mkdir -p /data

# Binaries
sudo mv prometheus promtool /usr/local/bin/

# FIX 1: Correct YAML indentation for ec2_sd_configs and relabel_configs
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "ec2-instances"
    ec2_sd_configs:
      - region: ap-south-1
        port: 9100
    relabel_configs:
      - source_labels: [__meta_ec2_tag_Name]
        target_label: instance
EOF

# Permissions
sudo chown -R prometheus:prometheus /etc/prometheus
sudo chown -R prometheus:prometheus /data

sudo tee /etc/systemd/system/prometheus.service > /dev/null <<'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
User=prometheus
Group=prometheus
Type=simple
Restart=always
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/data \
  --web.listen-address=0.0.0.0:9090

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable prometheus
sudo systemctl start prometheus

sleep 3

if sudo systemctl is-active --quiet prometheus; then
  log "Prometheus is running"
else
  echo -e "${RED}Prometheus failed. Logs:${NC}"
  journalctl -u prometheus -n 20 --no-pager
  exit 1
fi


# ─────────────────────────────────────────────
# 5. INSTALL GRAFANA
# ─────────────────────────────────────────────
log "Installing Grafana..."

sudo mkdir -p /etc/apt/keyrings
wget -qO /tmp/grafana.asc https://apt.grafana.com/gpg-full.key
sudo mv /tmp/grafana.asc /etc/apt/keyrings/grafana.asc

echo "deb [signed-by=/etc/apt/keyrings/grafana.asc] https://apt.grafana.com stable main" \
  | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null

sudo apt update -y
sudo apt install -y grafana

sudo systemctl enable grafana-server
sudo systemctl start grafana-server

log "Grafana running on port 3000"


# ─────────────────────────────────────────────
# DONE
# ─────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}   CLEAN SETUP COMPLETE${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Prometheus → http://<your-ec2-ip>:9090"
echo "Grafana    → http://<your-ec2-ip>:3000"