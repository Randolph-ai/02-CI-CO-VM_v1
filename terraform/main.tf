# ============================================================
# PROXMOX VIRTUAL ENVIRONMENT - VM KONFIGURATION
# ============================================================
# AUTOR:       Randolph Bluming
# Erstellt am:     2026-06-27
# Letzte Änderung: 2026-06-29
# FUNKTION:    Erstellt EINE VM auf Proxmox
# BESCHREIBUNG: Web-Server (Nginx) mit statischer IP 10.0.30.101
# ============================================================

# ============================================================
# PROXMOX VM KONFIGURATION - WEB-SERVER
# ============================================================
# VERSION:      2.0.0  (Update: 2026-06-29)
# ÄNDERUNGEN:
#   - IP und Gateway als Variablen (kein Hardcode mehr)
#   - timeout_clone hinzugefügt (verhindert Timeout bei 40GB)
# ============================================================

resource "proxmox_virtual_environment_vm" "web_server" {

  # Grundeinstellungen
  name        = "web-server-prod"
  description = "Web-Server (Nginx) - Managed by Terraform"
  tags        = ["web", "prod"]
  node_name   = var.target_node
  vm_id       = var.web_server_vm_id

  
  # QEMU Guest Agent (Pflicht für IP-Output!)
  agent {
    enabled = true
  }

  timeout_clone = 600  # 10 Minuten - bei 40GB Template wichtig!

  # Template klonen (von Packer erstellt)
  clone {
    vm_id         = var.template_vm_id
  }
  

  # CPU
  cpu {
    cores = var.web_server_cores
    type  = "host"
  }

  # RAM
  memory {
    dedicated = var.web_server_memory
  }

  # Netzwerk
  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan_id
  }

  # Festplatte (MUSS mit Packer übereinstimmen: 40GB)
  disk {
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.web_server_disk_size
  }

  # Cloud-Init (konfiguriert VM beim ersten Start)
  initialization {
    ip_config {
      ipv4 {
        address = var.web_server_ip      # ← jetzt Variable!
        gateway = var.network_gateway    # ← jetzt Variable!
      }
    }
    user_account {
      username = "randolph"
      keys     = [file(var.ssh_public_key)]
    }
  }
}