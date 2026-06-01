sudo wget https://github.com/grafana/loki/releases/v3.6.8/download/promtail-linux-amd64.zip
unzip -o promtail-linux-amd64.zip
chmod +x promtail-linux-amd64
sudo mv promtail-linux-amd64 /usr/local/bin/promtail

sudo mkdir -p /var/lib/promtail

sudo tee /etc/promtail-config.yaml > /dev/null <<EOF
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /var/lib/promtail/positions.yaml

clients:
  - url: ${LOKI_URL}

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

sudo tee /etc/systemd/system/promtail.service > /dev/null <<EOF
[Unit]
Description=Promtail
After=network.target

[Service]
ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail-config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

wget https://github.com/hctrdev/fail2ban-prometheus-exporter/releases/download/v${FAIL2BAN_EXPORTER_VERSION}/fail2ban-prometheus-exporter_${FAIL2BAN_EXPORTER_VERSION}_linux_amd64.tar.gz || true
echo "Fail2Ban exporter release name may differ. Check: https://github.com/hctrdev/fail2ban-prometheus-exporter/releases"

sudo systemctl daemon-reload
sudo systemctl enable --now node_exporter
sudo systemctl enable --now promtail

echo "Done."
echo "Node exporter: http://localhost:9100/metrics"
echo "Promtail config: /etc/promtail-config.yaml"
echo "Run: sudo tailscale up"
echo "Use script argument for Loki URL, example:"
echo "sudo ./install-ubuntu-agent.sh http://100.x.x.x:3100/loki/api/v1/push"