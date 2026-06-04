#!/bin/bash
set -e

NODE_EXPORTER_VERSION="1.11.1"

sudo apt update
sudo apt upgrade

sudo ufw enable

sudo apt install openssh-server
sudo systemctl enable ssh
sudo ufw allow ssh
sudo systemctl start ssh

sudo ufw allow 9100/tcp #node_exporter
sudo ufw allow 9191/tcp #fail2ban
sudo ufw allow 3100/tcp #promtail

#rsyslog
sudo apt install rsyslog
sudo systemctl enable rsyslog
sudo systemctl start rsyslog

#node_exporter
cd /tmp
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
sudo cp node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter /usr/local/bin/

sudo mkdir -p /var/lib/node_exporter/textfile_collector

sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
ExecStart=/usr/local/bin/node_exporter \
  --collector.textfile.directory=/var/lib/node_exporter/textfile_collector
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable node_exporter
sudo systemctl restart node_exporter

#fail2ban
sudo apt install fail2ban geoip-bin

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
maxretry = 6
findtime = 1h
bantime = 8h
ignoreip = 
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

#tailscale
curl -fsSL https://tailscale.com/install.sh | sh  
#sudo tailscale up

#docker
sudo apt install docker.io docker-compose
sudo systemctl enable --now docker
sudo mkdir -p /opt/monitoring-agent/promtail
cd /opt/monitoring-agent

sudo tee docker-compose.yml > /dev/null <<EOF
services:
  promtail:
    image: grafana/promtail:3.6.11
    container_name: promtail
    volumes:
      - ./promtail/promtail-config.yaml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - /var/lib/promtail:/var/lib/promtail
    command: -config.file=/etc/promtail/config.yml
    restart: unless-stopped

  fail2ban_exporter:
    image: blackflysolutions/fail2ban-prometheus-exporter:latest
    container_name: fail2ban_exporter
    ports:
      - "9191:9191"
    volumes:
      - /var/run/fail2ban:/var/run/fail2ban:ro
    command:
      - "--collector.f2b.socket=/var/run/fail2ban/fail2ban.sock"
      - "--web.listen-address=:9191"
    restart: unless-stopped
EOF

sudo tee promtail/promtail-config.yaml > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: http://TAILSCALE_IP_WINDOWS:3100/loki/api/v1/push

scrape_configs:
  - job_name: authlog
    static_configs:
      - targets:
          - localhost
        labels:
          job: ssh
          host: ubuntu-server
          __path__: /var/log/auth.log

  - job_name: syslog
    static_configs:
      - targets:
          - localhost
        labels:
          job: syslog
          host: ubuntu-server
          __path__: /var/log/syslog
EOF

sudo mkdir -p /var/lib/promtail
sudo docker-compose up -d






