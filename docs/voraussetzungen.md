# ⚙️ Voraussetzungen

[← Zurück zur README](../README.md)

- Proxmox VE Host, erreichbar über die API (`https://<proxmox-ip>:8006/api2/json`)
- Self-hosted GitHub Actions Runner, registriert mit den Labels `self-hosted` **und** `proxmox` (ohne exaktes Label-Match hängt der Job endlos in der Warteschlange, ohne Fehlermeldung)
- Auf dem Runner installiert: Packer, Terraform, Ansible, Checkov (>= 3.3.6)
- HCP Terraform (Free-Tarif) als zentraler Speicher für den Terraform-State (seit Phase 3):
  - Organisation `randolph-iacdeveloping`, Workspace `02-CI-CO-VM`
  - Workflow **CLI-driven**, Execution Mode **Local** (Plan/Apply laufen auf dem Runner, HCP speichert nur den State – HCP-Server würden Proxmox im Heimnetz nicht erreichen)
  - Remote State Sharing: **keiner** (der State kann sensible Werte enthalten)
- GitHub Secrets gesetzt:
  - `PROXMOX_URL`, `PACKER_TOKEN_ID`, `PACKER_TOKEN_SECRET` (für Packer, API-Token-Auth)
  - `TF_VAR_*`-Secrets passend zu den in `variables.tf` deklarierten Variablen
  - `SSH_PRIVATE_KEY` (dauerhafter Produktiv-Key, User `ansible` – siehe [`authentication.md`](authentication.md))
  - `SSH_PUBLIC_KEY` (öffentlicher Gegenpart, als `TF_VAR_ssh_public_key` an Terraform übergeben)
  - `TF_API_TOKEN` (HCP-Terraform-**Team**-Token, wird in Job 3 als `TF_TOKEN_app_terraform_io` bereitgestellt – siehe [Konfiguration](konfiguration.md))
- Eine bereits existierende Cloud-Image-Basis-VM (Template, standardmäßig VM-ID `9000`) als Klon-Quelle für Packer

[← Zurück zur README](../README.md)
