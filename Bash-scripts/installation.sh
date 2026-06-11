#!/bin/bash
set -e

NODE_EXPORTER_VERSION="1.11.1"

sudo apt update
sudo apt upgrade -y

sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo ufw allow ssh
sudo systemctl start ssh

sudo ufw allow 9100/tcp #node_exporter
sudo ufw allow 9191/tcp #fail2ban
sudo ufw enable

#rsyslog
sudo apt install rsyslog -y
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
sudo apt install fail2ban geoip-bin -y

sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
ignoreip =
[sshd]
enabled = true
maxretry = 6
findtime = 1h
bantime = 8h
ignoreip = 
EOF

sudo systemctl enable fail2ban
sudo systemctl restart fail2ban

#docker
sudo apt install docker.io docker-compose -y
sudo systemctl enable --now docker
sudo mkdir -p /opt/monitoring-agent/promtail
cd /opt/monitoring-agent

sudo tee docker-compose.yml > /dev/null <<EOF
services:
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

sudo docker-compose up -d






