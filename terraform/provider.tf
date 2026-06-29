# ============================================================
# TERRAFORM PROVIDER KONFIGURATION - PROXMOX
# ============================================================
# Erstellt am:     2026-06-26
# Letzte Änderung: 2026-06-29
# ENTWICKLER:    Infrastructure Team
# FUNKTION:      Terraform Provider für Proxmox VE
# ANWENDUNG:     Automatisierte VM-Provisionierung - Production
# VERSION:       1.1.0
# BESCHREIBUNG:  Konfiguration des Proxmox Providers für
#                die Kommunikation mit der Proxmox API
# ============================================================
# TERRAFORM PROVIDER KONFIGURATION - PROXMOX
# ============================================================
# DATUM:         2026-06-29  (Update)
# VERSION:       2.0.0
# ÄNDERUNGEN:
#   - Provider: 0.74.1 → 0.111.0
#     Grund: Bugfixes, neue Features, Sicherheitspatches
#   - api_token: Token-ID jetzt auch als Variable
#     Grund: Keine Hardcodes im Code (Security Best Practice)
# ============================================================

terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"

      # GEÄNDERT: 0.74.1 → 0.111.0
      # Das "~>" bedeutet: "mindestens 0.111.0,
      # aber KEINE neue Major-Version (also kein 1.x.x)"
      # Das schützt vor Breaking Changes bei großen Updates.
      version = "~> 0.111.0"
    }
  }
}

provider "proxmox" {

  # API Endpoint – kommt aus terraform.tfvars
  endpoint = var.pm_api_url

  # GEÄNDERT: Beide Teile kommen jetzt aus Variablen
  # Vorher: "root@pam!terraform-automation=${var.pm_api_token_secret}"
  # Nachher: "${var.pm_api_token_id}=${var.pm_api_token_secret}"
  #
  # Warum? Stell dir vor du hast 10 Terraform-Projekte.
  # Wenn du den Token-Namen änderst, musst du sonst in
  # 10 provider.tf Dateien suchen. So nur in einer tfvars.
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"

  # SSL-Zertifikat nicht prüfen (Homelab mit self-signed Cert)
  # Im echten Enterprise: insecure = false + echtes Zertifikat
  insecure = true
}
# ============================================================
# ERWEITERTE PROVIDER KONFIGURATION (OPTIONAL)
# ============================================================
# Diese Einstellungen sind optional, können aber für
# spezielle Anforderungen konfiguriert werden.
# ============================================================

/*
  # OPTION 1: SSH-Konfiguration für Provisioner
  # Wird benötigt für file/remote-exec Provisioner
  ssh {
    # SSH Agent für Authentifizierung
    agent = true
    
    # Username für SSH-Verbindungen
    username = "root"
    
    # Passwort (nicht empfohlen, besser SSH-Key)
    password = var.proxmox_password
  }

  # OPTION 2: CA-Zertifikat für SSL-Validierung
  # Statt insecure=true, kann ein gültiges CA-Zertifikat
  # hinterlegt werden (sicherer!)
  ca_certificate = file("/etc/ssl/certs/proxmox-ca.crt")
  
  # OPTION 3: Timeout für API-Requests
  # Standard: 600 Sekunden
  timeout = 600
*/

# ============================================================
# PROVIDER VERIFIZIERUNG
# ============================================================
# COMMANDS ZUM PRÜFEN:
# ┌─────────────────────────────────────────────────────────────┐
# │ 1. terraform init     → Provider herunterladen             │
# │ 2. terraform validate → Konfiguration prüfen               │
# │ 3. terraform plan     → API-Verbindung testen              │
# │ 4. terraform apply    → VMs erstellen                      │
# └─────────────────────────────────────────────────────────────┘
