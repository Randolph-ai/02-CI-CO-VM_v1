# ============================================================
# TERRAFORM VARIABLEN WERTE - PRODUCTION ENVIRONMENT
# ============================================================
# DATUM:         2026-06-26
# ENTWICKLER:    Infrastructure Team
# FUNKTION:      Konkrete Werte für Terraform Variablen
# ANWENDUNG:     Proxmox VM-Provisionierung - Production
# VERSION:       1.1.0
# BESCHREIBUNG:  Zentrale Konfigurationsdatei für alle
#                umgebungsabhängigen Parameter.
#                ACHTUNG: Enthält sensible Daten!
# ============================================================
#
# ============================================================
# TERRAFORM VARIABLEN WERTE
# ============================================================
# ⚠️  NICHT IN GIT COMMITTEN!
# ⚠️  Enthält sensible Daten (API-Token)
# ============================================================

# ============================================================
# 1. PROXMOX VERBINDUNG
# ============================================================

pm_api_url          = "https://10.0.30.22:8006/api2/json"
pm_api_token_id     = "root@pam!terraform-automation"
pm_api_token_secret = "f4c2783b-6c36-48fa-ad69-d0fefa098130"

# ============================================================
# 2. ALLGEMEINE VM EINSTELLUNGEN
# ============================================================

target_node    = "proxmox"
template_vm_id = 2000        # Packer-Template (nach Packer-Build)
ssh_public_key = "~/.ssh/id_rsa.pub"

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
web_server_disk_size = 40          # MUSS = Packer disk_size!
web_server_ip        = "10.0.30.101/24"