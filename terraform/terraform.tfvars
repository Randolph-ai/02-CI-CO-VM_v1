# ============================================================
# TERRAFORM VARIABLEN WERTE - PRODUCTION ENVIRONMENT
# ============================================================
# DATUM:           2026-06-26
# Letzte Änderung: 2026-08-14
# ENTWICKLER:      Infrastructure Team
# FUNKTION:        Konkrete Werte für Terraform Variablen
# ANWENDUNG:       Proxmox VM-Provisionierung - Production
# VERSION:         1.1.0
# BESCHREIBUNG:    Zentrale Konfigurationsdatei für alle
#                  umgebungsabhängigen Parameter.
# ============================================================

# ============================================================
# 1. PROXMOX VERBINDUNG
# ============================================================
# Die Verbindungsparameter wurden in secrets.auto.tfvars ausgelagert!
# Siehe: secrets.auto.tfvars für:
# - pm_api_url
# - pm_api_token_secret
# - pm_api_token_id

# ============================================================
# 2. ALLGEMEINE VM EINSTELLUNGEN
# ============================================================

target_node    = "proxmox"
template_vm_id = 2000
ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILrGnYLOLcYQTJkT8+US+HMbhCDMBEdJ3nGPnCGbemmt terraform-produktiv-zugang"

# ============================================================
# 3. NETZWERK & STORAGE
# ============================================================

network_bridge  = "vmbr0"
network_vlan_id = 30
network_gateway = "10.0.30.1"
disk_datastore  = "local-lvm"

# ============================================================
# 4. WEB-SERVER VM
# ============================================================

web_server_vm_id     = 1001
web_server_cores     = 2
web_server_memory    = 2048
web_server_disk_size = 40 # MUSS mit Packer disk_size übereinstimmen!
web_server_ip        = "10.0.30.101/24"
web_server_on_boot   = false
web_server_started   = true

# ============================================================
# 5. DB-SERVER VM
# ============================================================

db_server_vm_id     = 1010
db_server_cores     = 2
db_server_memory    = 2048
db_server_disk_size = 40 # MUSS mit Packer disk_size übereinstimmen!
db_server_ip        = "10.0.30.102/24"
db_server_on_boot   = false
db_server_started   = true
