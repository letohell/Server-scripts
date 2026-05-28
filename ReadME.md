This file contains instractions for connecting prometheus, grafana, f2b, loki and promtail to your server.

I'm using windows 11 as localhost and ubuntu 24.04 as server.
_____________________________
Windows
_____________________________

1. Putty
To connect via SSH first of all you need generate pair of keys: public and private (private key should be kept on your localhost).

Using Putty gen generate pair of keys and add pub key to the ubuntu machine (I use vds from ihor-hosting and can add pub key on their site)
1. Prometheus:

-Download https://github.com/prometheus/prometheus/releases/download/v3.12.0-rc.0/prometheus-3.12.0-rc.0.windows-amd64.zip

-For setting prometheus as a service on windows I used nssm (Non-Sucking Service Manager). https://www.nssm.cc/download

-In opened window set path to your prometheus.exe file and set an argument: --config.file=C:\Prometheus\prometheus.yml (or wherever your file is).
-Push "Install service" and then start service from services.msc.

-to check targets you can use  http://localhost:9090/targets (if you didn't change prometheus port)

2. Grafana
Download https://grafana.com/grafana/download

In C:\Program Files\GrafanaLabs\grafana\conf folder open file defaults.ini and in any text editor change field "enabled" in block [smtp] on true and save changes.

Then start Grafana service in services.msc (or restart).

Grafana interface will be available on http://localhost:3000

Login/psswd by default is admin/admin (after loggin you will be able to change password).

3. Loki
Using admin PowerShell add new Firewall rule:

New-NetFirewallRule `
  -DisplayName "Loki 3100 Tailscale" `
  -Direction Inbound `
  -Protocol TCP `
  -LocalPort 3100 `
  -Action Allow

Download Doker desktop:

-Create docker-compose.yml
-in PowerShell: docker compose up -d

// docker ps, docker compose down

*tailscale and promtail are needed

to check: curl http://localhost:3100/ready
4. Tailscale:

Download https://pkgs.tailscale.com/stable/tailscale-setup-1.98.2.exe

-Create an account or log in.
-Connect Tailscale to host machine.
_____________________________
Ubuntu
_____________________________
Before all needed modifications update and upgrade system:
-sudo apt update
-sudo apt upgrade

1. Open ssh

Download: sudo apt install openssh-server
-sudo systemctl enable ssh


2. UFW

sudo ufw allow ssh
copy ssh config file: sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.initial

sudo nano /etc/ssh/sshd_config

-sudo daemon-reload
-sudo systemctl restart ssh

3. Node exporter

download: 
-wget https://github.com/prometheus/node_exporter/releases/download/v1.9.1/node_exporter-1.9.1.linux-amd64.tar.gz
-tar xvf node_exporter-1.9.1.linux-amd64.tar.gz
-cd node_exporter-1.9.1.linux-amd64
-sudo cp node_exporter /usr/local/bin/

-Add user for node_exporter: sudo useradd --no-create-home --shell /bin/false <имя_пользователя>  
-sudo chown <имя_пользователя>:<группа> /usr/local/bin/node_exporter 

-sudo nano /etc/systemd/system/node_exporter.service
-sudo mkdir -p /var/lib/node_exporter/textfile_collector

to check metrics: curl http://localhost:9100/metrics  

to add ufw rules: sudo ufw allow proto tcp from IP to any port 9100  

4. rsyslog

Download: sudo apt install rsyslog

-sudo systemctl enable rsyslog

5. Fail2ban

Download: wget https://github.com/fail2ban/fail2ban/archive/refs/tags/1.1.0.tar.gz

-tar -xvf 1.1.0.tar.gz
-cd fail2ban-1.1.0

-sudo mkdir -p /etc/fail2ban
-sudo mkdir -p /var/log/fail2ban

-sudo nano /etc/fail2ban/jail.local

To set as a serice: sudo nano /etc/systemd/system/fail2ban.service

-sudo systemctl daemon-reload
-sudo systemctl enable fail2ban
-sudo systemctl start fail2ban

To check jail status: sudo fail2ban-client status

6. Fail2ban exporter

Download: wget https://github.com/prometheus-community/fail2ban_exporter/releases/latest/download/fail2ban_exporter-linux-amd64.tar.gz

-tar -xvf fail2ban_exporter-linux-amd64.tar.gz
-cd fail2ban_exporter-linux-amd64

-sudo cp fail2ban_exporter /usr/local/bin/
-sudo useradd --no-create-home --shell /bin/false fail2ban_exporter

To set as a service: sudo nano /etc/systemd/system/fail2ban_exporter.service

-sudo systemctl daemon-reload
-sudo systemctl enable fail2ban_exporter
-sudo systemctl start fail2ban_exporter

To check metrics: curl localhost:9191/metrics

7. Promtail

Download: wget https://github.com/grafana/loki/releases/latest/download/promtail-linux-amd64.zip

-unzip promtail-linux-amd64.zip
-chmod +x promtail-linux-amd64
-sudo mv promtail-linux-amd64 /usr/local/bin/promtail

To install as a service: sudo nano /etc/systemd/system/promtail.service

-sudo mkdir -p /var/lib/promtail
-sudo systemctl enable promtail
-sudo systemctl daemon-reload
-sudo systemctl start promtail

7. Tailscale

Download: curl -fsSL https://tailscale.com/install.sh | sh

-sudo tailscale up

Login in account and connect server machine/ 
Now yout localhost and server are in one network.