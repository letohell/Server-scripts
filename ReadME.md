To install on ubuntu openssh, fail2ban, geoip-bin, node_exporter and fail2ban_exporter + promtail via docker compose use: update.sh in Bash-scripts folder

on ubuntu server

chmod +x update.sh
sudo ./update.sh

to run Tailscale use: sudo tailscale up (also install it on your localhost to connect 2 machines in one network)

after installing change IPs in /etc/fail2ban/jail.local and /opt/monitoring-agent/promtail/promtail-config.yaml

