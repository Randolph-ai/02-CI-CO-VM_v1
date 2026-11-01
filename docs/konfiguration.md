# 🔩 Konfiguration

[← Zurück zur README](../README.md)

Wichtige Stellschrauben in `terraform/variables.tf` / `terraform.tfvars`:
- `template_vm_id` – ID des Packer-Golden-Image-Templates, das geklont wird (aktuell noch fest hinterlegt; Packer vergibt die Build-ID seit Phase 2B.2 automatisch, die Verbindung zur Terraform-Variable ist noch nicht angeschlossen – siehe Roadmap)
- `web_server_ip`, `db_server_ip`, `network_gateway` – Netzwerkkonfiguration der VMs
- `web_server_disk_size`, `db_server_disk_size` – Ziel-Diskgröße (muss `>= 40` sein, sonst blockiert `CKV_PROXMOX_3`)
- `db_server_cores`, `db_server_memory` – Ressourcengröße des DB-Servers

Mindestwerte der Custom Checks sind direkt im jeweiligen Check-Code als Konstanten hinterlegt (z. B. `MIN_DISK_SIZE_GB` in `ProxmoxDiskMemorySet.py`) und bei Bedarf dort anpassbar.

## Terraform-State in HCP Terraform (Phase 3)

Der State liegt nicht mehr als Datei `terraform.tfstate` im Arbeitsordner des Runners, sondern zentral in HCP Terraform. Damit ist er **zentral**, **versioniert** (jede Fassung mit Zeitpunkt und Auslöser, Änderungen als Vergleich) und **gesperrt** (Locking: ein zweiter gleichzeitiger Lauf wird mit `Error acquiring the state lock` abgewiesen).

Drei Zutaten machen den Zugriff aus:

| Zutat | Wo | Inhalt |
|---|---|---|
| **Adresse** | `terraform/provider.tf`, `cloud`-Block im `terraform`-Block | Organisation `randolph-iacdeveloping`, Workspace `02-CI-CO-VM` (keine Geheimnisse, darf ins Repo) |
| **Schlüssel** | Pipeline: Job 3 `deploy-vm`, `env:` im Job-Kopf | `TF_TOKEN_app_terraform_io: ${{ secrets.TF_API_TOKEN }}` – gilt für alle Terraform-Befehle des Jobs (`init`, `plan`, `apply`, `output`) |
| **Auslöser** | `terraform init` | verbindet sich mit dem Workspace; in der Pipeline mit `-input=false`, damit ein Lauf bei einer unerwarteten Rückfrage abbricht statt zu hängen |

Der Token steht **nie** im Code. `TF_TOKEN_` ist ein von Terraform vorgegebener Namensanfang, danach folgt die Adresse des Dienstes (`app.terraform.io`, Punkte durch `_` ersetzt). Für manuelle Arbeit im Terminal gilt stattdessen ein persönlicher Token aus `terraform login` (gespeichert in `~/.terraform.d/credentials.tfrc.json`).

**Hinweis zum Umzug:** Beim Umzug eines bestehenden States vergibt HCP Terraform eine neue `lineage` und beginnt mit `serial` 1 – der Inhalt (Ressourcen, Outputs) bleibt gleich. Eine Sicherheitskopie des alten lokalen States wird vor dem Umzug außerhalb von Repo und Runner-Ordner abgelegt.

**Backup / Exit-Strategie (geplant):** Regelmäßige Kopie des aktuellen States per `terraform state pull`, verschlüsselt und außerhalb des Repos – damit der State auch bei Ausfall des Anbieters oder Kontoverlust wiederherstellbar bleibt (`terraform state push` im Notfall).

[← Zurück zur README](../README.md)
