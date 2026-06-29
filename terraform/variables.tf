# ============================================================
# TERRAFORM VARIABLEN KONFIGURATION
# ============================================================
# AUTOR:       Randolph Bluming
# Erstellt am:    2026-06-27
# Letzte Änderung:2026-06-28 
# FUNKTION:    Variablen für EINE VM (Web-Server)
# VERSION:     2.0.0
# ÄNDERUNG:    DB-Server Variablen entfernt
#              Template-ID auf 2000 korrigiert (Packer)
#              API-Token auf Passwort umgestellt
# ============================================================

# ============================================================
# TERRAFORM VARIABLEN DEFINITION
# ============================================================
# WICHTIG: Hier stehen NUR Definitionen, KEINE echten Werte!
# Die echten Werte kommen aus terraform.tfvars
# ============================================================

# ============================================================
# 1. PROXMOX VERBINDUNG
# ============================================================

variable "pm_api_url" {
  description = "Proxmox API Endpoint"
  type        = string
  # Kein default → MUSS in terraform.tfvars angegeben werden
}

variable "pm_api_token_id" {
  description = "Proxmox API Token ID (Format: user@realm!tokenname)"
  type        = string
}

variable "pm_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true  # ← Wird in Logs NICHT angezeigt!
}

# ============================================================
# 2. ALLGEMEINE VM EINSTELLUNGEN
# ============================================================

variable "target_node" {
  description = "Name des Proxmox Nodes"
  type        = string
  default     = "proxmox"  # ← Hat einen Default → optional in tfvars
}

variable "template_vm_id" {
  description = "VM-ID des Packer-Templates"
  type        = number
  default     = 2000
}

variable "ssh_public_key" {
  description = "Pfad zum öffentlichen SSH-Key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

# ============================================================
# 3. NETZWERK & STORAGE
# ============================================================

variable "network_bridge" {
  description = "Proxmox Netzwerk-Bridge"
  type        = string
  default     = "vmbr0"
}

variable "network_vlan_id" {
  description = "VLAN ID für die VM"
  type        = number
  default     = 30
}

variable "network_gateway" {
  description = "Standard-Gateway im Netzwerk"
  type        = string
  default     = "10.0.30.1"
}

variable "disk_datastore" {
  description = "Proxmox Storage Pool für VM-Disk"
  type        = string
  default     = "local-lvm"
}

# ============================================================
# 4. WEB-SERVER VM
# ============================================================

variable "web_server_vm_id" {
  description = "Eindeutige VM-ID in Proxmox"
  type        = number
  default     = 1001
}

variable "web_server_cores" {
  description = "Anzahl CPU-Cores"
  type        = number
  default     = 2
}

variable "web_server_memory" {
  description = "RAM in MB"
  type        = number
  default     = 2048
}

variable "web_server_disk_size" {
  description = "Disk in GB - MUSS mit Packer übereinstimmen!"
  type        = number
  default     = 40
}

variable "web_server_ip" {
  description = "Statische IP-Adresse des Web-Servers"
  type        = string
  default     = "10.0.30.101/24"
}