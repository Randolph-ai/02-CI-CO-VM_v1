# ============================================================
# PROXMOX VIRTUAL ENVIRONMENT - VM KONFIGURATION
# ============================================================
# ZWECK:   Erstellt EINE VM auf Proxmox für den Web-Server
#
# AUTOR:       Randolph Bluming
# Erstellt am:     2026-06-27
# Letzte Änderung: 2026-07-02
# ============================================================

# ============================================================
# PROXMOX VM RESSOURCE - WEB-SERVER
# ============================================================
# ZWECK:   Definiert die komplette VM-Konfiguration
#
# WICHTIG: Die VM wird aus einem Packer-Template geklont
#          Das Template muss VOR dem Terraform-Run existieren!
#          (siehe Packer-Build → template-vm)
#
# VERSION: 2.0.0 (Update: 2026-06-29)
# ÄNDERUNGEN:
#   - IP und Gateway als Variablen (kein Hardcode mehr)
#   - timeout_clone hinzugefügt (verhindert Timeout bei 40GB)
# ============================================================

resource "proxmox_virtual_environment_vm" "web_server" {
  # ---- GRUNDEINSTELLUNGEN ----
  # Name, Beschreibung und Tags für die VM
  #    │
  #    └── "web-server-prod" = Hostname der VM
  #        Tags helfen bei der Organisation in Proxmox

  name        = "web-server-prod"
  description = "Web-Server (Nginx) - Managed by Terraform"
  tags        = ["web", "prod"]
  
  # ---- PROXMOX NODE ----
  # Auf welchem Proxmox-Host wird die VM erstellt?
  node_name   = var.target_node
  #    │
  #    └── Wert aus terraform.tfvars
  #        z.B. target_node = "proxmox-host-01"

  # ---- VM-ID ----
  # Eindeutige ID in Proxmox (muss im Cluster einzigartig sein)
  vm_id       = var.web_server_vm_id
  #    │
  #    └── Wert aus terraform.tfvars
  #        z.B. web_server_vm_id = 101

  # ---- QEMU GUEST AGENT ----
  # Ermöglicht Kommunikation zwischen Host und Gast
  #    │
  #    └── PFICHT für IP-Output!
  #        Ohne Agent kann Terraform die IP nicht auslesen

  agent {
    enabled = true
  }

  # ---- TIMEOUT CLONE ----
  # Zeitlimit für das Klonen des Templates
  #    │
  #    └── 600 Sekunden = 10 Minuten
  #        Bei 40GB Template kann das Klonen länger dauern
  #        Verhindert Timeout-Fehler in der Pipeline

  timeout_clone = 600

  # ---- TEMPLATE KLONEN ----
  # Welches Template wird als Basis verwendet?
  #    │
  #    └── Das Packer-Template wird hier referenziert
  #        VM-ID aus terraform.tfvars (z.B. 9000)

  clone {
    vm_id = var.template_vm_id
  }

  # ---- CPU ----
  # Prozessor-Konfiguration für die VM
  #    │
  #    └── "host" = CPU-Typ des Hosts wird durchgereicht
  #        Beste Performance, aber weniger Migration möglich

  cpu {
    cores = var.web_server_cores
    type  = "host"
  }

  # ---- RAM ----
  # Arbeitsspeicher-Konfiguration
  #    │
  #    └── dedicated = exklusiv reservierter RAM
  #        Kein Ballooning (Shared Memory)

  memory {
    dedicated = var.web_server_memory
  }

  # ---- NETZWERK ----
  # Netzwerk-Interface der VM
  #    │
  #    └── bridge = virtueller Switch in Proxmox
  #        vlan_id = VLAN für Netzwerktrennung

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan_id
  }

  # ---- FESTPLATTE ----
  # Speicher-Konfiguration
  #    │
  #    └── MUSS mit Packer übereinstimmen: 40GB
  #        interface "scsi0" = SCSI-Controller
  #        datastore = Speicherort auf Proxmox

  disk {
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.web_server_disk_size
  }

  # ---- CLOUD-INIT ----
  # Automatische Konfiguration beim ersten Start
  #    │
  #    └── Wird NUR beim ersten Boot ausgeführt
  #        Danach ist die VM fertig konfiguriert
  #        Änderungen hier benötigen einen Rebuild!

  initialization {
    # ---- DNS ----
    # Nameserver für die VM
    #    │
    #    └── Google DNS als Fallback
    #        Kann durch firmeninterne DNS ersetzt werden

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    # ---- IP-KONFIGURATION ----
    # Statische IP-Adresse für den Web-Server
    #    │
    #    └── WICHTIG: Muss im gleichen Subnetz wie Gateway liegen
    #        IP aus terraform.tfvars (10.0.30.101/24)
    #        Gateway aus terraform.tfvars (10.0.30.1)

    ip_config {
      ipv4 {
        address = var.web_server_ip
        gateway = var.network_gateway
      }
    }

    # ---- BENUTZER & SSH-KEY ----
    # Zugangsdaten für die VM
    #    │
    #    └── username "randolph" = MUSS mit Packer übereinstimmen!
    #        SSH-Key wird aus Datei gelesen
    #        Der öffentliche Key wird in die VM eingespielt

    user_account {
          username = "ansible"
          keys     = [trimspace(file(var.ssh_public_key))]
        }

      }
    }