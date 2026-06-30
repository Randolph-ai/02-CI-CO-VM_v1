 #========================================================================
 #PACKER KONFIGURATION - UBUNTU 22.04 TEMPLATE
 #========================================================================
 #Autor:       Randolph Bluming
 #Erstellt am:     2026-06-27
 #Letzte Änderung: 2026-06-30
 #Projekt:     CI-CO Setup - Proxmox Infrastructure
 #Zweck:       Erstellt ein Ubuntu 22.04 Template für Proxmox
 #             Das Template wird von Terraform für VM-Deployments verwendet
 #=========================================================================

# ============================================================
# PACKER PLUGINS
# ============================================================

 packer {
  required_plugins {
    # Proxmox Plugin für Packer
    # Änderung: Version von ">= 1.0.0" auf ">= 1.1.2" angehoben
    # Grund: Native Kompatibilität mit bpg/terraform-provider-proxmox
    proxmox = {
      version = "1.1.8"
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

variable "proxmox_password" {
  type      = string
  default   = env("PROXMOX_PASSWORD")
  sensitive = true
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
  password                 = var.proxmox_password # kommt aus GitHub Secret!
  node                     = var.proxmox_node

  # SSL/TLS-Konfiguration
  insecure_skip_tls_verify = true

  # ---- VM-BASIS-EINSTELLUNGEN ----
  # VM_ID 2000 vergeben (nicht 1000!)
  # 1000 ist die Template-ID für Terraform, Packer erstellt das Template
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
    type         = "scsi"
    
    # Format "raw" für lvm-thin/local-lvm Kompatibilität
    format       = "raw"
  }

  # ---- NETZWERK ----
  network_adapters {
    bridge   = "vmbr0"
    model    = "virtio"
    vlan_tag = "30"
  }

  # ---- ISO-IMAGE (Boot-Medium) ----
  iso_file                 = "ISO-Storage-LexarNQ:iso/ubuntu-22.04.5-live-server-amd64.iso"
  iso_url                  = "https://releases.ubuntu.com/22.04/ubuntu-22.04-live-server-amd64.iso"
  iso_checksum             = "sha256:9bc6028870aef3f74f4e16b900008179e78b130e6b0b9a140635434a46aa98b0"

  # ---- ZUSÄTZLICHES CD-ROM: CLOUD-INIT (NoCloud) ----
  # Enthält user-data + meta-data, vorher mit genisoimage zu cidata.iso gepackt
  # und auf den Proxmox-Storage hochgeladen.
  # cloud-init erkennt dieses Laufwerk automatisch über das Label "cidata",
  # OHNE dass wir während des Boots etwas eintippen oder per HTTP abrufen müssen.
  additional_iso_files {
    device   = "ide3"
    iso_file = "local:iso/cidata.iso"
    unmount  = true
  }

  # ---- BOOT-KONFIGURATION ----
  # Wartezeit, damit ISO-Bootmenü geladen ist
  boot_wait                = "5s"

  boot_command = [
    "<wait>",
    "e<wait>",
    "<down><down><down><end>",
    " autoinstall ds=nocloud",
    "<wait><f10>"
  ]

  # ---- SSH-KONFIGURATION ----
  ssh_username             = "randolph"
  ssh_private_key_file     = "~/.ssh/id_ed25519"
  ssh_timeout              = "20m"
}

# ============================================================
# BUILD - PROVISIONING
# ============================================================

build {
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