$ErrorActionPreference = "Stop"

$BaseDir = "C:\monitoring"
$PromDir = "$BaseDir\prometheus"
$LokiDir = "$BaseDir\loki"
$NssmDir = "$BaseDir\nssm"
$DownloadDir = "$BaseDir\downloads"

New-Item -ItemType Directory -Force -Path $BaseDir, $PromDir, $LokiDir, $NssmDir, $DownloadDir | Out-Null

function Download-GitHubAsset {
    param (
        [string]$Repo,
        [string]$Pattern,
        [string]$OutFile
    )

    $release = Invoke-RestMethod "https://api.github.com/repos/$Repo/releases/latest"
    $asset = $release.assets | Where-Object { $_.name -match $Pattern } | Select-Object -First 1

    if (-not $asset) {
        throw "Asset not found: $Repo / $Pattern"
    }

    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $OutFile
}

Write-Host "Installing Tailscale..."
winget install --id Tailscale.Tailscale -e --accept-package-agreements --accept-source-agreements

Write-Host "Installing Grafana..."
winget install --id GrafanaLabs.GrafanaOSS -e --accept-package-agreements --accept-source-agreements

Write-Host "Downloading NSSM..."
$nssmZip = "$DownloadDir\nssm.zip"
Invoke-WebRequest "https://nssm.cc/release/nssm-2.24.zip" -OutFile $nssmZip
Expand-Archive $nssmZip -DestinationPath $DownloadDir -Force
Copy-Item "$DownloadDir\nssm-2.24\win64\nssm.exe" "$NssmDir\nssm.exe" -Force

Write-Host "Downloading Prometheus..."
$promZip = "$DownloadDir\prometheus.zip"
Download-GitHubAsset "prometheus/prometheus" "windows-amd64\.zip$" $promZip
Expand-Archive $promZip -DestinationPath $DownloadDir -Force
$promExtracted = Get-ChildItem $DownloadDir -Directory | Where-Object { $_.Name -like "prometheus-*.windows-amd64" } | Select-Object -First 1
Copy-Item "$($promExtracted.FullName)\*" $PromDir -Recurse -Force

@"
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
"@ | Set-Content "$PromDir\prometheus.yml" -Encoding UTF8

Write-Host "Installing Prometheus service..."
& "$NssmDir\nssm.exe" install Prometheus "$PromDir\prometheus.exe"
& "$NssmDir\nssm.exe" set Prometheus AppParameters "--config.file=$PromDir\prometheus.yml --storage.tsdb.path=$PromDir\data --storage.tsdb.retention.time=30d"
& "$NssmDir\nssm.exe" set Prometheus AppDirectory $PromDir
& "$NssmDir\nssm.exe" set Prometheus Start SERVICE_AUTO_START

Write-Host "Downloading Loki..."
$lokiZip = "$DownloadDir\loki.zip"
Download-GitHubAsset "grafana/loki" "^loki-windows-amd64\.exe\.zip$" $lokiZip
Expand-Archive $lokiZip -DestinationPath $LokiDir -Force

@"
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: C:\monitoring\loki\data
  storage:
    filesystem:
      chunks_directory: C:\monitoring\loki\data\chunks
      rules_directory: C:\monitoring\loki\data\rules
  replication_factor: 1

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

storage_config:
  filesystem:
    directory: C:\monitoring\loki\data\chunks

limits_config:
  retention_period: 720h

compactor:
  working_directory: C:\monitoring\loki\data\compactor
  retention_enabled: true
  delete_request_store: filesystem
"@ | Set-Content "$LokiDir\loki-config.yaml" -Encoding UTF8

Write-Host "Installing Loki service..."
$lokiExe = Get-ChildItem $LokiDir -Filter "loki-windows-amd64.exe" | Select-Object -First 1
& "$NssmDir\nssm.exe" install Loki $lokiExe.FullName
& "$NssmDir\nssm.exe" set Loki AppParameters "--config.file=$LokiDir\loki-config.yaml"
& "$NssmDir\nssm.exe" set Loki AppDirectory $LokiDir
& "$NssmDir\nssm.exe" set Loki Start SERVICE_AUTO_START

Write-Host "Opening firewall ports..."
New-NetFirewallRule -DisplayName "Prometheus 9090" -Direction Inbound -Protocol TCP -LocalPort 9090 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Loki 3100" -Direction Inbound -Protocol TCP -LocalPort 3100 -Action Allow -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "Grafana 3000" -Direction Inbound -Protocol TCP -LocalPort 3000 -Action Allow -ErrorAction SilentlyContinue

Write-Host "Starting services..."
Start-Service Prometheus
Start-Service Loki
Start-Service grafana

Write-Host "Done."
Write-Host "Prometheus: http://localhost:9090"
Write-Host "Loki:       http://localhost:3100/ready"
Write-Host "Grafana:    http://localhost:3000"
Write-Host "Next: run tailscale up from the Tailscale app."