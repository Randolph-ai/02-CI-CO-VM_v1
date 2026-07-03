# #========================================================================
# #PACKER KONFIGURATION - UBUNTU 22.04 TEMPLATE
# #========================================================================
# #Autor:       Randolph Bluming
# #Erstellt am:     2026-06-27
# #Letzte Änderung: 2026-07-02
# #Projekt:     CI-CO Setup - Proxmox Infrastructure
# #Zweck:       Erstellt ein Ubuntu 22.04 Template für Proxmox
# #             Das Template wird von Terraform für VM-Deployments verwendet
# #=========================================================================
#
## ============================================================
## PACKER-TEMPLATE: Ubuntu 22.04 via Cloud-Image + proxmox-clone
## ============================================================
## Ersetzt den ISO-basierten Ansatz komplett.
## Quelle: VM 9000 (ubuntu-2204-cloudinit-base) - einmalig manuell
##         aus dem Ubuntu-Cloud-Image erstellt (siehe Session-Notizen).
## Ziel:   Template 2000 (ubuntu-2204-golden)
## ============================================================
#
#packer {
#  required_plugins {
#    proxmox = {
#      version = "1.1.8"
#      source  = "github.com/hashicorp/proxmox"
#    }
#  }
#}
#
## ============================================================
## VARIABLEN
## ============================================================
## env() darf NUR hier als default stehen, nie direkt im source-Block!
#
#variable "proxmox_url" {
#  type    = string
#  default = env("PROXMOX_URL")
#}
#
#variable "proxmox_username" {
#  type    = string
#  default = env("PROXMOX_USER")
#}
#
#variable "proxmox_password" {
#  type      = string
#  default   = env("PROXMOX_PASSWORD")
#  sensitive = true
#}
#
## ============================================================
## SOURCE: proxmox-clone
## ============================================================
#
#source "proxmox-clone" "ubuntu" {
#  # --- Proxmox-Verbindung ---
#  proxmox_url               = var.proxmox_url
#  username                  = var.proxmox_username
#  password                  = var.proxmox_password
#  insecure_skip_tls_verify  = true
#  node                      = "proxmox"
#
#  # --- Was geklont wird ---
#  clone_vm   = "ubuntu-2204-cloudinit-base"   # VM 9000
#  full_clone = true
#
#  # --- Ziel-Template ---
#  vm_id                 = 2000
#  vm_name               = "ubuntu-2204-golden"
#  template_name         = "ubuntu-2204-golden"
#  template_description  = "Ubuntu 22.04 Golden Image - gebaut von Packer aus Cloud-Image-Basis (VM 9000)"
#
#  # --- Hardware ---
#  cores   = 2
#  sockets = 1
#  memory  = 2048
#  os      = "l26"
#
#  scsi_controller = "virtio-scsi-pci"
#  qemu_agent      = true
#
#  network_adapters {
#    model    = "virtio"
#    bridge   = "vmbr0"
#    vlan_tag = "30"
#  }
#
#  # --- NEU: Feste IP nur für den Build-Vorgang ---
#  # Umgeht das Henne-Ei-Problem mit dem noch fehlenden Guest-Agent
#  ipconfig {
#    ip      = "10.0.30.199/24"
#    gateway = "10.0.30.1"
#  }
#  # --- NEU: DNS-Server, da statische IP keinen DHCP-DNS mitbekommt ---
#  nameserver= "8.8.8.8 1.1.1.1"
#
#  # --- Cloud-Init: leeres CDROM fürs fertige Template ---
#  # Terraform füllt es bei jeder neuen VM selbst (wie bisher).
#  cloud_init              = true
#  cloud_init_storage_pool = "local-lvm"
#
#  # --- SSH-Zugriff WÄHREND des Builds ---
#  # Packer schreibt diesen User automatisch ins Cloud-Init der
#  # temporären Build-VM, um die Provisioner ausführen zu können.
#  ssh_username         = "randolph"
#  ssh_private_key_file = "~/.ssh/id_ed25519"
#
#  # --- NEU: Packer soll DIESE IP direkt nutzen, ---
#  # --- statt sie über den Guest-Agent zu suchen  ---
#  ssh_host    = "10.0.30.199"
#  ssh_timeout = "20m"
#}
#
## ============================================================
## BUILD: Provisionierung
## ============================================================
#
#build {
#  sources = ["source.proxmox-clone.ubuntu"]
#
#  provisioner "shell" {
#    inline = [
#      "sudo apt-get update",
#      "sudo apt-get upgrade -y",
#      "sudo apt-get install -y qemu-guest-agent",
#      "sudo systemctl enable qemu-guest-agent",
#      "sudo cloud-init clean",
#      "sudo rm -f /etc/machine-id",
#      "sudo touch /etc/machine-id"
#    ]
#  }
#}
#**************************************************************
#*2026-07-03** von DeepSeek formattiert ***********************
#**************************************************************
# ============================================================
# PACKER KONFIGURATION - UBUNTU 22.04 TEMPLATE
# ============================================================
# ZWECK:   Erstellt ein Ubuntu 22.04 Template für Proxmox
#          Das Template wird von Terraform für VM-Deployments verwendet
#
# AUTOR:       Randolph Bluming
# Erstellt am:     2026-06-27
# Letzte Änderung: 2026-07-02
# ============================================================

# ============================================================
# PACKER-TEMPLATE: Ubuntu 22.04 via Cloud-Image + proxmox-clone
# ============================================================
# ZWECK:   Ersetzt den ISO-basierten Ansatz komplett
#          Schneller und zuverlässiger durch Cloud-Image
#
# QUELLE:  VM 9000 (ubuntu-2204-cloudinit-base)
#          Einmalig manuell aus Ubuntu-Cloud-Image erstellt
#          (siehe Session-Notizen)
#
# ZIEL:    Template 2000 (ubuntu-2204-golden)
#          Wird von Terraform für alle VMs verwendet
# ============================================================

packer {
  required_plugins {
    proxmox = {
      version = "1.1.8"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

# ============================================================
# VARIABLEN
# ============================================================
# ZWECK:   Umgebungsvariablen für sensible Daten
#          Passwörter und API-Zugangsdaten
#
# WICHTIG: env() darf NUR hier als default stehen,
#          nie direkt im source-Block!
# ============================================================

variable "proxmox_url" {
  type    = string
  default = env("PROXMOX_URL")
  #    │
  #    └── Aus Umgebungsvariable gelesen aus git secrets
  #        z.B. export PROXMOX_URL="https://10.0.30.1:8006/"
}

variable "proxmox_username" {
  type    = string
  default = env("PROXMOX_USER")
  #    │
  #    └── Aus Umgebungsvariable gelesen aus git secrets
  #        z.B. export PROXMOX_USER="root@pam"
}

variable "proxmox_password" {
  type      = string
  default   = env("PROXMOX_PASSWORD")
  sensitive = true
  #    │
  #    └── SENSITIVE! Wird nicht in Logs ausgegeben
  #        Aus Umgebungsvariable gelesen aus git secrets
  #        z.B. export PROXMOX_PASSWORD="secret"
}

# ============================================================
# SOURCE: proxmox-clone
# ============================================================
# ZWECK:   Definiert die Quelle für Packer
#          Klont eine existierende VM und erstellt ein Template
#
# WICHTIG: Die Quell-VM MUSS vor dem Build existieren!
#          (VM 9000 - ubuntu-2204-cloudinit-base)
# ============================================================

source "proxmox-clone" "ubuntu" {
  # ---- PROXMOX-VERBINDUNG ----
  # Zugangsdaten für die Proxmox-API
  #    │
  #    └── Alle Werte aus Umgebungsvariablen
  #        insecure_skip_tls_verify = true (für Testumgebung)
  
  proxmox_url               = var.proxmox_url
  username                  = var.proxmox_username
  password                  = var.proxmox_password
  insecure_skip_tls_verify  = true
  node                      = "proxmox"
  #    │
  #    └── Proxmox-Node auf dem die VM läuft

  # ---- WAS GEKLONT WIRD ----
  # Welche VM wird als Basis verwendet?
  #    │
  #    └── clone_vm = Name der Quell-VM (muss existieren)
  #        full_clone = Kompletter Klon (kein Link-Klon)
  
  clone_vm   = "ubuntu-2204-cloudinit-base"   # VM 9000
  full_clone = true

  # ---- ZIEL-TEMPLATE ----
  # Wie soll das fertige Template heißen?
  #    │
  #    └── vm_id = 2000 (muss im Proxmox-Cluster einzigartig sein)
  #        vm_name und template_name müssen übereinstimmen
  #        template_description = Info für Proxmox-Admin
  
  vm_id                 = 2000
  vm_name               = "ubuntu-2204-golden"
  template_name         = "ubuntu-2204-golden"
  template_description  = "Ubuntu 22.04 Golden Image - gebaut von Packer aus Cloud-Image-Basis (VM 9000)"

  # ---- HARDWARE ----
  # Standard-Hardware für das Template
  #    │
  #    └── Diese Werde können von Terraform überschrieben werden
  #        os = "l26" = Linux 2.6 Kernel (für Proxmox)
  
  cores   = 2
  sockets = 1
  memory  = 2048
  os      = "l26"

  # ---- STEUERUNG ----
  # SCSI-Controller und QEMU-Guest-Agent
  #    │
  #    └── scsi_controller = "virtio-scsi-pci" (beste Performance)
  #        qemu_agent = true (PFICHT für Terraform IP-Output!)
  
  scsi_controller = "virtio-scsi-pci"
  qemu_agent      = true

  # ---- NETZWERK ----
  # Netzwerk-Interface für die Build-VM
  #    │
  #    └── model = "virtio" (beste Performance)
  #        bridge = "vmbr0" (Proxmox-Standard)
  #        vlan_tag = "30" (VLAN für Prod-Umgebung)
  
  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    vlan_tag = "30"
  }

  # ---- STATISCHE IP FÜR BUILD ----
  # Feste IP nur für den Build-Vorgang
  #    │
  #    └── Umgeht das Henne-Ei-Problem:
  #        Guest-Agent ist noch nicht installiert
  #        Packer braucht aber die IP für SSH
  #        → Statische IP 10.0.30.199/24
  #        Gateway = 10.0.30.1
  
  ipconfig {
    ip      = "10.0.30.199/24"
    gateway = "10.0.30.1"
  }
  
  # ---- DNS FÜR BUILD ----
  # DNS-Server für statische IP-Konfiguration
  #    │
  #    └── Da keine DHCP, muss DNS manuell gesetzt werden
  #        Google DNS als Fallback
  
  nameserver = "8.8.8.8 1.1.1.1"

  # ---- CLOUD-INIT ----
  # Cloud-Init für das fertige Template
  #    │
  #    └── leeres CDROM fürs fertige Template
  #        Terraform füllt es bei jeder neuen VM selbst
  #        cloud_init_storage_pool = "local-lvm"
  
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  # ---- SSH-ZUGRIFF WÄHREND BUILD ----
  # Packer schreibt diesen User automatisch ins Cloud-Init
  #    │
  #    └── ssh_username = "randolph" (MUSS mit späterem User übereinstimmen!)
  #        ssh_private_key_file = Pfad zum privaten SSH-Key
  #        Wird für Provisioner benötigt
  
  ssh_username         = "randolph"
  ssh_private_key_file = "~/.ssh/id_ed25519"

  # ---- SSH HOST ----
  # Packer soll DIESE IP direkt nutzen
  #    │
  #    └── Statt über Guest-Agent zu suchen
  #        Vermeidet Timeout bei noch fehlendem Agent
  #        ssh_timeout = 20 Minuten (bei großen Updates)
  
  ssh_host    = "10.0.30.199"
  ssh_timeout = "20m"
}

# ============================================================
# BUILD: PROVISIONIERUNG
# ============================================================
# ZWECK:   Installiert Software und bereitet Template vor
#          Wird auf der temporären Build-VM ausgeführt
#
# WICHTIG: Alle Befehle werden als root ausgeführt
#          (sudo für User randolph notwendig)
# ============================================================

build {
  sources = ["source.proxmox-clone.ubuntu"]
  #    │
  #    └── Verwendet die oben definierte Source

  provisioner "shell" {
    # ---- SHELL-BEFEHLE ----
    # Wird auf der VM ausgeführt
    #    │
    #    └── Inline = Liste von Shell-Befehlen
    #        Wird in der Reihenfolge ausgeführt
    
    inline = [
      # ---- SYSTEM AKTUALISIEREN ----
      # Updates und Upgrades für Sicherheit und Stabilität
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      
      # ---- QEMU-GUEST-AGENT INSTALLIEREN ----
      # PFICHT für Terraform IP-Output!
      #    │
      #    └── Wird später für Kommunikation benötigt
      #        Ermöglicht IP-Abfrage durch Proxmox
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      
      # ---- CLOUD-INIT CLEANUP ----
      # Bereinigt Cloud-Init für nächsten Start
      #    │
      #    └── Verhindert dass alte Konfiguration übernommen wird
      #        Wichtig für statische IPs in Terraform
      "sudo cloud-init clean",
      
      # ---- MACHINE-ID ZURÜCKSETZEN ----
      # Verhindert Duplikate im Netzwerk
      #    │
      #    └── Jede VM bekommt beim ersten Start eine neue ID
      #        Wichtig für DHCP und Netzwerk-Kommunikation
      "sudo rm -f /etc/machine-id",
      "sudo touch /etc/machine-id"
    ]
  }
}
