# ========================================================================
# PACKER KONFIGURATION - UBUNTU 22.04 TEMPLATE
# ========================================================================
# Autor:       Randolph Bluming
# Erstellt am:     2026-06-27
# Letzte Änderung: 2026-06-28
# Projekt:     CI-CO Setup - Proxmox Infrastructure
# Zweck:       Erstellt ein Ubuntu 22.04 Template für Proxmox
#              Das Template wird von Terraform für VM-Deployments verwendet
# =========================================================================

# ============================================================
# PACKER PLUGINS
# ============================================================

packer {
  required_plugins {
    # Proxmox Plugin für Packer
    # Änderung: Version von ">= 1.0.0" auf ">= 1.1.2" angehoben
    # Grund: Native Kompatibilität mit bpg/terraform-provider-proxmox
    proxmox = {
      version = ">= 1.1.2"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ============================================================
# VARIABLEN
# ============================================================

# Proxmox API URL
variable "proxmox_url" {
  type    = string
  default = "https://10.0.30.22:8006/api2/json"
}

# Proxmox Node Name
variable "proxmox_node" {
  type    = string
  default = "proxmox"
}

# ============================================================
# PACKER SOURCE - PROXMOX ISO
# ============================================================

source "proxmox-iso" "ubuntu-template" {
  # ---- PROXMOX VERBINDUNG ----
  # Änderung: Typ von "proxmox" auf "proxmox-iso" korrigiert
  # Grund: Modernes Plugin unterstützt "proxmox" nicht mehr
  proxmox_url              = var.proxmox_url
  username                 = "root@pam"
  password                 = "${env("PROXMOX_PASSWORD")}"  # kommt aus GitHub Secret!
  node                     = var.proxmox_node
  
  # SSL/TLS-Konfiguration
  # Ergänzung: Verhindert Abbruch bei selbstsignierten Zertifikaten (Lab-Umgebung)
  insecure_skip_tls_verify = true

  # ---- VM-BASIS-EINSTELLUNGEN ----
  # Ergänzung: VM_ID 2000 vergeben (nicht 1000!)
  # Grund: Vermeidet Konflikte mit Terraform-VMs (1001, 1002)
  #        1000 ist die Template-ID für Terraform, Packer erstellt das Template
  vm_id                    = 2000
  vm_name                  = "ubuntu-template"
  template_name            = "ubuntu-2204-template"
  template_description     = "Ubuntu 22.04.5 Template erstellt mit Packer für CI-CO Setup"

  # ---- HARDWARE ----
  cores                    = 2
  sockets                  = 1  # Best Practice für virtuelle Umgebungen
  memory                   = 2048
  
  # CPU-Typ "host" für beste Performance (nutzt Host-CPU-Features)
  cpu_type                 = "host"
  
  # Betriebssystem-Typ: Linux 2.6 - 6.x Kernel
  os                       = "l26"
  
  # QEMU Agent aktivieren (für IP-Abfrage durch Terraform)
  qemu_agent               = true

  # ---- FESTPLATTEN ----
  # Änderung: Controller auf "virtio-scsi-pci" für moderne SCSI-Disks
  scsi_controller          = "virtio-scsi-pci"
  
  disks {
    # Änderung: disk_size von "20G" auf "40G" erhöht
    # Grund: Terraform fordert 40GB (Größen müssen identisch sein!)
    disk_size    = "40G"
    storage_pool = "local-lvm"
    
    # Änderung: Typ von "virtio" auf "scsi" geändert
    # Grund: Moderne Proxmox-Infrastruktur verwendet SCSI
    type         = "scsi"
    
    # Format "raw" für lvm-thin/local-lvm Kompatibilität
    format       = "raw"
  }

  # ---- NETZWERK ----
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    
    # Ergänzung: VLAN-Tag 30
    # Grund: Produktive VMs laufen in VLAN 30 (wie in Terraform definiert)
    vlan_tag = "30"
  }

  # ---- HTTP-SERVER (für Cloud-Init) ----
  http_directory           = "http"
  
  # Port-Range für Packer-Webserver (vermeidet Firewall-Blockaden)
  http_port_min            = 8820
  http_port_max            = 8830

  # ---- ISO-IMAGE ----
  iso_file                 = "ISO-Storage-LexarNQ:iso/ubuntu-22.04.5-live-server-amd64.iso"
  iso_url                  = "https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso"
  iso_checksum             = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

  # ---- BOOT-KONFIGURATION ----
  # Wartezeit, damit ISO-Bootmenü geladen ist
  boot_wait                = "5s"
  
  # Änderung: Boot-Befehle strukturiert und korrigiert
  # Grund: Korrekte HCL-Syntax und Leerzeichen
  boot_command = [
    "<esc><wait>",                                         # ESC zum Interrupt
    "c<wait>",                                             # c für Kommandozeile
    "linux /casper/vmlinuz ",                              # Kernel laden
    "autoinstall ",                                        # Autoinstall-Modus
    "ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ ", # Cloud-Init Config
    "--- <enter><wait>",                                   # Parameter abschließen
    "initrd /casper/initrd<enter><wait>",                 # Initramfs laden
    "boot<enter>"                                          # Booten starten
  ]

  # ---- SSH-KONFIGURATION ----
  # Ergänzung: SSH-Parameter für Post-Provisioning
  # Grund: Packer muss sich nach dem Booten einloggen können
  ssh_username             = "soar-admin"
  ssh_private_key_file     = "~/.ssh/id_ed25519"
  ssh_timeout              = "20m"
}

# ============================================================
# BUILD - PROVISIONING
# ============================================================

build {
  # Änderung: Source-Referenz angepasst
  # Grund: Neuer Source-Name "source.proxmox-iso.ubuntu-template"
  sources = ["source.proxmox-iso.ubuntu-template"]

  # ---- SHELL PROVISIONER ----
  provisioner "shell" {
    # Änderung: Script erweitert
    inline = [
      # 1. Warten auf Cloud-Init (damit alle Konfigurationen angewendet sind)
      "echo 'Warte auf den Abschluss der Wolken-Initialisierung...'",
      "sudo cloud-init status --wait",
      
      # 2. System aktualisieren
      "echo 'Aktualisiere Systemkomponenten...'",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      
      # 3. Notwendige Pakete installieren
      "sudo apt-get install -y qemu-guest-agent openssh-server",
      
      # 4. Bereinigung für saubere Klone
      "echo 'Bereinige Netzwerkkennungen für saubere Klone...'",
      "sudo apt-get clean",                                    # Cache leeren
      "sudo truncate -s 0 /etc/machine-id",                   # Machine-ID zurücksetzen
      "sudo rm -f /var/lib/dbus/machine-id",                  # DBus-ID löschen
      "sudo sync"                                             # Festplatten-Cache schreiben
    ]
  }
}

# ============================================================
# ÄNDERUNGEN IM ÜBERBLICK
# ============================================================
#
# 🔴 GEÄNDERT:
#   1. Plugin-Version: ">= 1.0.0" → ">= 1.1.2"
#   2. Source-Typ: "proxmox" → "proxmox-iso"
#   3. disk_size: "20G" → "40G"
#   4. Disk-Typ: "virtio" → "scsi"
#   5. scsi_controller: "virtio-scsi-pci" (neu)
#   6. Source-Referenz im Build: "source.proxmox-iso.ubuntu-template"
#   7. Provisioner-Script: Cloud-Init Wartezeit + Systembereinigung
#
# 🟢 ERGÄNZT:
#   1. insecure_skip_tls_verify = true
#   2. vm_id = 2000
#   3. sockets = 1
#   4. cpu_type = "host"
#   5. os = "l26"
#   6. qemu_agent = true
#   7. disk.format = "raw"
#   8. network_adapters.vlan_tag = "30"
#   9. http_port_min = 8820 / http_port_max = 8830
#   10. boot_wait = "5s"
#   11. ssh_username, ssh_private_key_file, ssh_timeout
#   12. Bereinigung: /etc/machine-id, /var/lib/dbus/machine-id
#
# ============================================================