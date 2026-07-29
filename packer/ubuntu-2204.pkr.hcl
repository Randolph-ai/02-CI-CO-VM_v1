# ============================================================
# PACKER KONFIGURATION - UBUNTU 22.04 TEMPLATE
# ============================================================
# ZWECK:   Erstellt ein Ubuntu 22.04 Template für Proxmox
#          Das Template wird von Terraform für VM-Deployments verwendet
#
# AUTOR:       Randolph Bluming
# Erstellt am:     2026-06-27
# Letzte Änderung: 2026-07-29
# ============================================================
# ========================
# required_plugins
# ========================
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

  # HINWEIS Dual-Auth: Packer nutzt hier Passwort, Terraform (siehe
  # terraform/variables.tf) nutzt API-Token. Historisch gewachsen.
  # Passwort = volle Rechte, nur per Passwortänderung widerrufbar.
  # Token = granular einschränkbar, einzeln widerrufbar.

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

  proxmox_url              = var.proxmox_url
  username                 = var.proxmox_username
  password                 = var.proxmox_password
  insecure_skip_tls_verify = true
  node                     = "proxmox"
  #    │
  #    └── Proxmox-Node auf dem die VM läuft

  # ---- WAS GEKLONT WIRD ----
  # Welche VM wird als Basis verwendet?
  #    │
  #    └── clone_vm = Name der Quell-VM (muss existieren)
  #        full_clone = Kompletter Klon (kein Link-Klon)

  clone_vm   = "ubuntu-2204-cloudinit-base" # VM 9000
  full_clone = true

  # ---- ZIEL-TEMPLATE ----
  # Wie soll das fertige Template heißen?
  #    │
  #    └── vm_id = 2000 (muss im Proxmox-Cluster einzigartig sein)
  #        vm_name und template_name müssen übereinstimmen
  #        template_description = Info für Proxmox-Admin

  vm_id                = 2000
  vm_name              = "ubuntu-2204-golden"
  template_name        = "ubuntu-2204-golden"
  template_description = "Ubuntu 22.04 Golden Image - gebaut von Packer aus Cloud-Image-Basis (VM 9000)"

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
  
  #=====================
  provisioner "shell" {
    # ---- SHELL-BEFEHLE ----
    # Wird auf der VM ausgeführt
    #    │
    #    └── Inline = Liste von Shell-Befehlen
    #        Wird in der Reihenfolge ausgeführt
    inline = [
      "df -h /",
      "lsblk",

      #=====================
      # ---- SYSTEM AKTUALISIEREN ----
      # Updates und Upgrades für Sicherheit und Stabilität#=====================
      "sudo cloud-init status --wait",
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      
      #=====================
      # ---- QEMU-GUEST-AGENT INSTALLIEREN ----
      # PFICHT für Terraform IP-Output!
      #    │
      #    └── Wird später für Kommunikation benötigt
      #        Ermöglicht IP-Abfrage durch Proxmox
      "sudo apt-get install -y qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",

      #=====================
      # NEU: 20.07.26 CIS-Härtung: SSH-Passwort-Login global sperren
      #
      # WAS: Erzwingt, dass SSH-Logins nur noch per Key funktionieren.
      # Ein Passwort-Login wird komplett abgelehnt, kein Prompt mehr.
      #
      # WARUM DAS GEFAHRLOS IST: In der gesamten VM-Kette (VM 9000 ->
      # Packer-Build -> Template 2000 -> Terraform-VM) wird schon
      # jetzt ausschließlich mit SSH-Keys gearbeitet (User "randolph"
      # beim Build, User "ubuntu" in Produktion). Passwort-Login wurde
      # nie tatsächlich genutzt - diese Einstellung schließt also nur
      # einen theoretischen, ungenutzten Zugangsweg.
      "sudo sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config",
      "sudo systemctl restart sshd",

      #=====================
      # NEU: 28.07.26 CIS-Härtung: Firewall-Baseline (UFW)
      #
      # UFW blockiert standardmäßig ALLE eingehenden Verbindungen und
      # lässt nur explizit erlaubte Ports durch ("Default Deny").
      # Offen bleiben: 22 (SSH, für Verwaltung) sowie 80/443
      # (HTTP/HTTPS, für den Webserver-Dienst auf VM 1001).
      #
      # WICHTIG: Die "allow"-Regeln müssen vor "ufw enable" stehen,
      # sonst würde die Firewall sich selbst den Zugriff sperren.
      "sudo ufw allow 22/tcp",
      "sudo ufw allow 80/tcp",
      "sudo ufw allow 443/tcp",
      "sudo ufw --force enable",
      "sudo ufw status verbose",

      #=====================
      # NEU: 28.07.26 CIS-Härtung: Automatische Security-Updates
      #
      # WAS: unattended-upgrades installiert einen täglichen
      # systemd-Timer, der sicherheitsrelevante Patches automatisch
      # einspielt - auch Wochen/Monate nach dem Klonen der VM, ganz
      # ohne manuelles Zutun.
      #
      # WARUM NUR SECURITY-UPDATES: Reguläre Paket-Updates könnten
      # unerwartet Verhalten ändern, ohne dass jemand es aktiv
      # angestoßen hat - für eine Produktions-VM zu riskant.
      #
      # WIE: Statt uns auf die Ubuntu-Standardkonfiguration zu
      # verlassen (kann sich zwischen Versionen ändern), löschen wir
      # die Standard-Quellenliste explizit ("#clear") und definieren
      # sie neu mit AUSSCHLIESSLICH der Security-Quelle. Eigene
      # Config-Datei statt sed, weil das Original mehrzeilig ist und
      # ein sed-Eingriff darin fehleranfällig und schwer lesbar wäre.
      "sudo apt-get install -y unattended-upgrades",
      "printf '%s\\n' '#clear Unattended-Upgrade::Allowed-Origins;' 'Unattended-Upgrade::Allowed-Origins {' '    \"Ubuntu:jammy-security\";' '};' | sudo tee /etc/apt/apt.conf.d/51security-only > /dev/null",
      "sudo dpkg-reconfigure -f noninteractive unattended-upgrades",
      "systemctl is-enabled unattended-upgrades",
        
      #=====================
      # NEU: 29.07.26 CIS-Härtung: Unnötige Dienste deaktivieren
      #
      # Ubuntu-Cloud-Images sind "Universal-Images" für verschiedene
      # Plattformen - dadurch bringen sie Dienste mit, die auf unserer
      # Proxmox/KVM-Umgebung nie gebraucht werden. Jeder unnötig laufende
      # Dienst ist unnötige Angriffsfläche ("Minimal Attack Surface").
      #
      # Gruppe 1: Fremde Hypervisor-Werkzeuge (VMware/LXD, nicht Proxmox/KVM)
      "sudo systemctl disable --now open-vm-tools.service",
      "sudo systemctl disable --now vgauth.service",
      "sudo systemctl disable --now lxd-agent.service",
      "sudo systemctl disable --now snap.lxd.activate.service",
      #
      # Gruppe 2: Nicht genutzte Storage-Protokolle (kein SAN/iSCSI im Homelab)
      "sudo systemctl disable --now multipathd.service",
      "sudo systemctl disable --now open-iscsi.service",
      #
      # Gruppe 3: Nicht genutzte Ubuntu-spezifische Dienste
      "sudo systemctl disable --now ubuntu-advantage.service",
      "sudo systemctl disable --now ua-reboot-cmds.service",
      "sudo systemctl disable --now pollinate.service",

      #=====================
      # ---- CLOUD-INIT CLEANUP ----
      # Bereinigt Cloud-Init für nächsten Start
      #    │
      #    └── Verhindert dass alte Konfiguration übernommen wird
      #        Wichtig für statische IPs in Terraform
      "sudo cloud-init clean",

      #=====================
      # ---- MACHINE-ID ZURÜCKSETZEN ----
      # Verhindert Duplikate im Netzwerk
      #    │
      #    └── Jede VM bekommt beim ersten Start eine neue ID
      #        Wichtig für DHCP und Netzwerk-Kommunikation
      "sudo rm -f /etc/machine-id",
      "sudo touch /etc/machine-id",
      "sudo userdel -f -r randolph" # ← jetzt als letzter Befehl im gesamten Block
    ]
  }
}
