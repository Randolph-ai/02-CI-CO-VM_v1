# 🔐 Authentifizierung: Proxmox-API und SSH

## Dual-Authentifizierung: Packer vs. Terraform

Das Projekt nutzt bewusst zwei unterschiedliche Authentifizierungsmechanismen gegen die Proxmox-API. Historisch gewachsen, aber dokumentiert statt stillschweigend inkonsistent.

| | Packer | Terraform |
|---|---|---|
| Auth-Typ | Benutzername/Passwort (`PROXMOX_USER`/`PROXMOX_PASSWORD`) | API-Token (`pm_api_token_id`/`pm_api_token_secret`) |
| Widerruf | Nur durch globale Passwortänderung (betrifft alle Nutzer dieses Kontos) | Einzeln widerrufbar, ohne andere Zugänge zu beeinflussen |
| Rechteumfang | Volle Kontorechte | Granular einschränkbar über Proxmox API-Token-Permissions |

**Warum nicht vereinheitlicht:** Beide Tools unterstützen technisch beide Auth-Typen (der `bpg/proxmox`-Provider akzeptiert auch Passwort-Auth). Die Trennung ist keine funktionale Notwendigkeit, sondern historisch entstanden. Eine Vereinheitlichung auf Token für beide Tools ist als mögliche künftige Verbesserung vorgemerkt.

**Injection-Mechanismus (eigene Ebene, nicht mit dem Auth-Typ zu verwechseln):**
- Packer: `env("PROXMOX_PASSWORD")` explizit im HCL-Code (Packer-eigene Syntax)
- Terraform: automatischer `TF_VAR_`-Präfix aus der Umgebung (Terraform-Konvention, kein expliziter Code-Aufruf nötig)

---

## SSH-Key-Architektur: Build vs. Produktiv

Analog zur Dual-Authentifizierung auf Proxmox-API-Ebene wird auch beim SSH-Zugriff **innerhalb** der VMs strikt zwischen Build- und Produktivzugang getrennt – zwei unabhängige Schlüsselpaare für zwei unabhängige Vertrauenszonen. Beide VMs (Web-Server und DB-Server) nutzen denselben Produktiv-Key (`id_ed25519_terraform`, User `ansible`) – eine VM-spezifische Trennung ist als Phase-5/Vault-Thema vorgesehen.

| | Packer (Build) | Terraform/Ansible (Produktiv) |
|---|---|---|
| Privater Key | `id_ed25519` | `id_ed25519_terraform` |
| Username | temporär, wird als letzter Provisioner-Schritt per `userdel` entfernt | `ansible` (dauerhaft) |
| Lebensdauer des Zugangs | Minuten (nur während des Builds) | Dauerhaft (solange die VM läuft) |
| Verbindungsweg | Packer verbindet sich aktiv per SSH gegen die Build-VM | Terraform spricht **ausschließlich** mit der Proxmox-API, nie per SSH – Ansible verbindet sich aktiv per SSH gegen die fertigen VMs |
| Key-Übergabe an die VM | Direkt durch Packers `proxmox-clone`-Builder | Terraform platziert nur den **Public Key** via Cloud-Init (separates virtuelles CD-ROM-Medium, gelesen ausschließlich beim allerersten Boot einer neuen Instance-ID) |

**Warum getrennt und nicht ein gemeinsamer Key:** Ein gestohlener Build-Key öffnet nur eine VM, die es in Kürze ohnehin nicht mehr gibt (Blast-Radius-Begrenzung). Bei einem gemeinsamen Key hätte derselbe Diebstahl dauerhaften Zugriff auf die laufende Produktions-VM bedeutet. Ein Angreifer müsste bei getrennten Keys zwei unabhängige Diebstähle erfolgreich durchführen statt nur einen.

**Variable als Wert statt als Pfad:** `var.ssh_public_key` in `terraform.tfvars` enthält den Public-Key-**Inhalt** direkt (kein `file()`-Aufruf, kein Dateipfad). Grund: Ein Pfad mit `~` wird von Terraform nicht wie in der Bash-Shell automatisch aufgelöst, und der GitHub-Actions-Runner checkt das Repo ohnehin in ein komplett anderes Arbeitsverzeichnis aus, in dem eine lokale `terraform.tfvars` gar nicht existiert. Der Key-Inhalt kommt in der Pipeline stattdessen aus dem GitHub Secret `SSH_PUBLIC_KEY` (`TF_VAR_ssh_public_key`).

---
[← Zurück zur README](../README.md)
