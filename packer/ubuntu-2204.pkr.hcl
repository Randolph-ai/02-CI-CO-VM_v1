 #========================================================================
 #PACKER KONFIGURATION - UBUNTU 22.04 TEMPLATE
 #========================================================================
 #Autor:       Randolph Bluming
 #Erstellt am:     2026-06-27
 #Letzte Änderung: 2026-07-02
 #Projekt:     CI-CO Setup - Proxmox Infrastructure
 #Zweck:       Erstellt ein Ubuntu 22.04 Template für Proxmox
 #             Das Template wird von Terraform für VM-Deployments verwendet
 #=========================================================================

# ============================================================
# PACKER-TEMPLATE: Ubuntu 22.04 via Cloud-Image + proxmox-clone
# ============================================================
# Ersetzt den ISO-basierten Ansatz komplett.
# Quelle: VM 9000 (ubuntu-2204-cloudinit-base) - einmalig manuell
#         aus dem Ubuntu-Cloud-Image erstellt (siehe Session-Notizen).
# Ziel:   Template 2000 (ubuntu-2204-golden)
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
# env() darf NUR hier als default stehen, nie direkt im source-Block!

variable "proxmox_url" {
  type    = string
  default = env("PROXMOX_URL")
}

variable "proxmox_username" {
  type    = string
  default = env("PROXMOX_USER")
}

variable "proxmox_password" {
  type      = string
  default   = env("PROXMOX_PASSWORD")
  sensitive = true
}

# ============================================================
# SOURCE: proxmox-clone
# ============================================================

source "proxmox-clone" "ubuntu" {
  # --- Proxmox-Verbindung ---
  proxmox_url               = var.proxmox_url
  username                  = var.proxmox_username
  password                  = var.proxmox_password
  insecure_skip_tls_verify  = true
  node                      = "proxmox"

  # --- Was geklont wird ---
  clone_vm   = "ubuntu-2204-cloudinit-base"   # VM 9000
  full_clone = true

  # --- Ziel-Template ---
  vm_id                 = 2000
  vm_name               = "ubuntu-2204-golden"
  template_name         = "ubuntu-2204-golden"
  template_description  = "Ubuntu 22.04 Golden Image - gebaut von Packer aus Cloud-Image-Basis (VM 9000)"

  # --- Hardware ---
  cores   = 2
  sockets = 1
  memory  = 2048
  os      = "l26"

  scsi_controller = "virtio-scsi-pci"
  qemu_agent      = true

  network_adapters {
    model    = "virtio"
    bridge   = "vmbr0"
    vlan_tag = "30"
  }

  # --- NEU: Feste IP nur für den Build-Vorgang ---
  # Umgeht das Henne-Ei-Problem mit dem noch fehlenden Guest-Agent
  ipconfig {
    ip      = "10.0.30.199/24"
    gateway = "10.0.30.1"
  }
  # --- NEU: DNS-Server, da statische IP keinen DHCP-DNS mitbekommt ---
  nameserver= "8.8.8.8 1.1.1.1"

  # --- Cloud-Init: leeres CDROM fürs fertige Template ---
  # Terraform füllt es bei jeder neuen VM selbst (wie bisher).
  cloud_init              = true
  cloud_init_storage_pool = "local-lvm"

  # --- SSH-Zugriff WÄHREND des Builds ---
  # Packer schreibt diesen User automatisch ins Cloud-Init der
  # temporären Build-VM, um die Provisioner ausführen zu können.
  ssh_username         = "randolph"
  ssh_private_key_file = "~/.ssh/id_ed25519"

  # --- NEU: Packer soll DIESE IP direkt nutzen, ---
  # --- statt sie über den Guest-Agent zu suchen  ---
  ssh_host    = "10.0.30.199"
  ssh_timeout = "20m"
}

# ============================================================
# BUILD: Provisionierung
# ============================================================

build {
  sources = ["source.proxmox-clone.ubuntu"]

  provisioner "shell" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo cloud-init clean",
      "sudo rm -f /etc/machine-id",
      "sudo touch /etc/machine-id"
    ]
  }
}

