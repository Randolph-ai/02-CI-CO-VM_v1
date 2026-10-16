# 🚀 CI/CD Pipeline Setup für Proxmox mit Security-Gate

> Automatisierte Infrastructure-as-Code Pipeline mit Packer, Terraform, Ansible, GitHub Actions und Checkov Custom Policy Checks

![Version](https://img.shields.io/badge/version-1.3.0-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Proxmox](https://img.shields.io/badge/Proxmox-7.x-red)
![Checkov](https://img.shields.io/badge/Checkov-3.3+-brightgreen)

---

## 📋 Inhaltsverzeichnis

- [Projektübersicht](#-projektübersicht)
- [Technologie-Stack](#-technologie-stack)
- [Projektstruktur](#-projektstruktur)
- [Architektur-Vertiefungen](#-architektur-vertiefungen)
- [Voraussetzungen](#️-voraussetzungen)
- [Installation & Setup](#-installation--setup)
- [Nutzung](#️-nutzung)
- [Konfiguration](#-konfiguration)
- [Fehlerbehebung](#-fehlerbehebung)
- [Bekannte technische Schuld](#️-bekannte-technische-schuld-offen)
- [Roadmap - Was als nächstes kommt](#️-roadmap-was-als-nächstes-kommt)
- [Zukunftsausblick](#-zukunftsausblick-ai-driven-siem--monitoring)

---

## 🎯 Projektübersicht

![Proxmox CI/CD Pipeline](docs/images/pipeline_diagramm_mit_server.png)

Dieses Projekt automatisiert die sichere Bereitstellung einer vollständigen Infrastruktur auf Proxmox VE mittels Infrastructure-as-Code (IaC). Ein hartes Security-Gate (Terraform-Seite) sowie ein ergänzendes Soft-Gate (Ansible-Seite) verhindern bzw. dokumentieren fehlerhafte Deployments.

| Komponente | Aufgabe |
|------------|---------|
| **Packer** | Erstellt ein Ubuntu 22.04 Golden-Image-Template (Cloud-Image-basiert, `proxmox-clone`-Builder) |
| **Terraform** | Provisioniert zwei VMs auf Proxmox mittels `bpg/proxmox` Provider: Web-Server und DB-Server |
| **Checkov** | Validiert IaC auf Security-Policies **vor** dem Deploy (Terraform: hartes Gate, Ansible: Soft-Gate) |
| **Ansible** | Konfiguriert die VMs: Nginx auf dem Web-Server, PostgreSQL auf dem DB-Server (inkl. Netzwerkzugriffskonfiguration zwischen beiden) |
| **GitHub Actions** | Automatisiert die komplette Pipeline inkl. beider Security-Gates (self-hosted Runner) |

**Hinweis zur Phasen-Nummerierung:** Die Security-Erweiterung des Projekts läuft in benannten, aufeinander aufbauenden Phasen (2A, 2B, 2C, ...) – jede Referenz auf "Phase X" bezieht sich auf diese interne Roadmap, nicht auf einen externen Standard.

- **Phase 2A** – Statisches Security-Gate (Checkov) in die Pipeline integriert *(abgeschlossen)*
- **Phase 2B** – CIS-Härtung des Packer-Golden-Images *(abgeschlossen)*
- **Phase 2C** – Zweite VM (DB-Server, PostgreSQL) aus dem gehärteten Image, inkl. Netzwerkzugriffskonfiguration Web-Server → DB-Server *(abgeschlossen)*

Die Reise geht danach weiter – Phasen 3 bis 6 (State-Backend, Dynamisches
Inventar, Vault, Compliance-Doku) findest du unter
[🗺️ Roadmap: Was als Nächstes kommt](#️-roadmap-was-als-nächstes-kommt).

[↑ Nach oben](#-inhaltsverzeichnis)

---

## 🛠 Technologie-Stack

| Tool | Version | Zweck |
|------|---------|-------|
| Packer | 1.9+ (Proxmox-Plugin gepinnt auf `1.1.8`) | Template-Erstellung |
| Terraform | 1.5+ | Infrastructure Provisioning |
| HCP Terraform | Free-Tarif | Zentraler Speicher für den Terraform-State (versioniert, mit Locking) – seit Phase 3 |
| Checkov | 3.3.6 | Policy-as-Code Security-Scanning (Terraform- und Ansible-Framework) |
| Ansible | 2.14+ | Configuration Management |
| PostgreSQL | 14 (Ubuntu-22.04-Standardversion) | Datenbank auf dem DB-Server |
| Proxmox VE | 7.x/8.x | Virtualisierungsplattform |
| Ubuntu | 22.04 LTS | Betriebssystem (Cloud-Image) |

[↑ Nach oben](#-inhaltsverzeichnis)

---

## 📁 Projektstruktur

### Hauptverzeichnis
- **`.github/workflows/pipeline.yml`** - GitHub Actions Pipeline mit beiden Security-Gates
- **`README.md`** - Diese Projektübersicht
- **`docs/`** - Vertiefende Architektur-Dokumentation (siehe unten)

### Packer
- **`packer/ubuntu-2204.pkr.hcl`** - Packer Template (`proxmox-clone`-Builder)
- **`packer/setup-base-image.sh`** - Reproduzierbarer Aufbau der Cloud-Image-Basis-VM
- **`packer/_archiv-iso-ansatz/`** - Archivierter, verworfener ISO/Subiquity-Ansatz (Dokumentationszweck)

### Terraform
- **`terraform/main.tf`** - VM-Definitionen: `web_server` und `db_server`
- **`terraform/provider.tf`** - Provider & API-Konfiguration, dazu der `cloud`-Block (Speicherort des States in HCP Terraform, seit Phase 3)
- **`terraform/variables.tf`** - Variablendeklaration (getrennte Abschnitte je VM)
- **`terraform/outputs.tf`** - Ausgaben für Ansible (`vm_ip`, `db_server_ip`, u. a.)
- **`terraform/checks/`** - Custom Checkov Security Checks (`CKV_PROXMOX_1/2/3`)
- **`terraform/terraform.tfvars.example`** - Variablen-Vorlage

### Ansible
- **`ansible/inventory.ini`** - Wird pro Pipeline-Lauf dynamisch aus beiden Terraform-Output-IPs erzeugt
- **`ansible/playbook.yml`** - Zwei eigenständige Plays: Web-Server (Nginx) und DB-Server (PostgreSQL)
- **`ansible/checks/task/`** - Custom Checkov Security Check für Ansible-Tasks (`CKV_ANSIBLE_CUSTOM_1`)

[↑ Nach oben](#-inhaltsverzeichnis)

---

## 📚 Architektur-Vertiefungen

Diese README hält sich bewusst kurz. Wer tiefer in einzelne Entscheidungen einsteigen will, findet die ausführlichen Erklärungen hier:

| Thema | Kurzbeschreibung | Vertiefung |
|---|---|---|
| **Security-Gates** | Zwei Checkov-Gates (hart/weich), Custom Checks, `checkov:skip`-Prinzip | [`docs/security-gates.md`](docs/security-gates.md) |
| **CIS-Härtung (Phase 2B)** | Golden-Image-Härtung: SSH, Firewall, Updates, Dienste | [`docs/cis-hardening.md`](docs/cis-hardening.md) |
| **DB-Server (Phase 2C)** | Drei-Ebenen-Netzwerkmodell (Firewall/Lauschen/Zugriffsregel) | [`docs/db-server-architecture.md`](docs/db-server-architecture.md) |
| **Authentifizierung** | Dual-Auth Proxmox-API + getrennte SSH-Key-Architektur (Build/Produktiv) | [`docs/authentication.md`](docs/authentication.md) |

[↑ Nach oben](#-inhaltsverzeichnis)

---

## ⚙️ Voraussetzungen

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
  - `SSH_PRIVATE_KEY` (dauerhafter Produktiv-Key, User `ansible` – siehe [`docs/authentication.md`](docs/authentication.md))
  - `SSH_PUBLIC_KEY` (öffentlicher Gegenpart, als `TF_VAR_ssh_public_key` an Terraform übergeben)
  - `TF_API_TOKEN` (HCP-Terraform-**Team**-Token, wird in Job 3 als `TF_TOKEN_app_terraform_io` bereitgestellt – siehe [Konfiguration](#-konfiguration))
- Eine bereits existierende Cloud-Image-Basis-VM (Template, standardmäßig VM-ID `9000`) als Klon-Quelle für Packer

## 🔧 Installation & Setup

1. Repository auf den self-hosted Runner klonen
2. Basis-Image einmalig aufbauen:
   ```bash
   chmod +x packer/setup-base-image.sh
   ./packer/setup-base-image.sh
   ```
   Erstellt die Cloud-Image-Basis-VM (Standard: ID `9000`), inkl. Disk-Vergrößerung und Guest-Agent-Flag.
3. Zwei Terraform-Variablen-Dateien anlegen:
   - `terraform/terraform.tfvars` (unkritische Werte: Netzwerk, IPs, Disk-Größe, `template_vm_id`) aus `terraform.tfvars.example`
   - `terraform/secrets.auto.tfvars` (nur die drei Proxmox-Auth-Werte: `pm_api_url`, `pm_api_token_id`, `pm_api_token_secret`) – wird von Terraform automatisch geladen, `.gitignore`-geschützt
4. HCP Terraform einrichten (siehe Voraussetzungen): Workspace anlegen, Execution Mode **Local**, Team-Token erzeugen. Existiert bereits ein lokaler State, wird er **einmalig** nach HCP umgezogen – erst sichern, dann `terraform init` im Ordner mit State und `cloud`-Block, Rückfrage mit `yes` beantworten (Details: [Konfiguration](#-konfiguration))
5. GitHub Secrets im Repo hinterlegen (siehe Voraussetzungen)
6. Self-hosted Runner registrieren und mit dem Label `proxmox` versehen
7. Push auf `main` (oder Pull Request) startet die Pipeline automatisch

## ▶️ Nutzung

Ein Push auf `main` löst die Pipeline mit sechs aufeinander aufbauenden Jobs aus:

```
detect-changes          → Erkennt geänderte Verzeichnisse (packer/terraform/ansible)
build-template          → Packer baut/erneuert das Golden-Image-Template (nur bei Packer-Änderung)
security-scan           → Checkov-Gate, Terraform (hart) – Stop bei Verstoß
deploy-vm               → Terraform provisioniert Web-Server UND DB-Server
ansible-security-scan   → Checkov-Gate, Ansible (weich) – Report, kein Stop
configure-vm            → Ansible konfiguriert Nginx und PostgreSQL
```

`build-template` läuft nur, wenn `detect-changes` eine Änderung im `packer/`-Verzeichnis (oder an `pipeline.yml` selbst) erkennt – bei reinen Terraform-/Ansible-Änderungen wird der Job übersprungen.

Der Fortschritt ist im GitHub-Actions-Tab des Repos einsehbar. Schlägt `security-scan` fehl, werden die folgenden drei Jobs gar nicht erst gestartet ("Skipped", 0 Sekunden Laufzeit). Schlägt dagegen `ansible-security-scan` fehl, läuft `configure-vm` trotzdem an (Soft-Gate).

Nach einem erfolgreichen Lauf sind beide VMs über ihre von Terraform ausgegebenen IPs erreichbar (`terraform output -raw vm_ip` bzw. `terraform output -raw db_server_ip`). Da der State seit Phase 3 in HCP Terraform liegt, braucht dafür auch ein manueller Aufruf im Terminal eine Anmeldung (`terraform login`) und einen Ordner mit `cloud`-Block nach `terraform init`.

## 🔩 Konfiguration

Wichtige Stellschrauben in `terraform/variables.tf` / `terraform.tfvars`:
- `template_vm_id` – ID des Packer-Golden-Image-Templates, das geklont wird (aktuell noch fest hinterlegt; Packer vergibt die Build-ID seit Phase 2B.2 automatisch, die Verbindung zur Terraform-Variable ist noch nicht angeschlossen – siehe Roadmap)
- `web_server_ip`, `db_server_ip`, `network_gateway` – Netzwerkkonfiguration der VMs
- `web_server_disk_size`, `db_server_disk_size` – Ziel-Diskgröße (muss `>= 40` sein, sonst blockiert `CKV_PROXMOX_3`)
- `db_server_cores`, `db_server_memory` – Ressourcengröße des DB-Servers

Mindestwerte der Custom Checks sind direkt im jeweiligen Check-Code als Konstanten hinterlegt (z. B. `MIN_DISK_SIZE_GB` in `ProxmoxDiskMemorySet.py`) und bei Bedarf dort anpassbar.

### Terraform-State in HCP Terraform (Phase 3)

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

[↑ Nach oben](#-inhaltsverzeichnis)

---

## 🩹 Fehlerbehebung

| Symptom | Ursache | Lösung |
|---|---|---|
| Job hängt endlos in "Queued" | Runner-Label passt nicht zu `runs-on` in `pipeline.yml` | Label `proxmox` beim Runner ergänzen |
| `E: Could not get lock /var/lib/apt/lists/lock` im Packer-Build | Cloud-Init läuft beim ersten Boot noch, blockiert `apt`-Lock | `sudo cloud-init status --wait` als erste Zeile im `shell`-Provisioner |
| `config file already exists` beim Terraform-`apply`, obwohl Plan `X to add` zeigt | State-Drift: lokal getesteter State kennt eine VM, die im Runner-eigenen State nicht existiert | Betroffene VM einmalig löschen (`qm destroy <id>`), Pipeline im Runner-Kontext neu bauen lassen. Strukturelle Lösung: zentrales State-Backend (Phase 3) |
| Terraform will VM erneut anlegen, obwohl sie läuft | `terraform.tfstate` ging beim Checkout verloren (self-hosted Runner mit geteiltem Arbeitsordner) | `clean: false` bei **allen** `actions/checkout`-Schritten setzen |
| `Error acquiring the state lock`, obwohl kein anderer Lauf aktiv scheint | Hängender Lock: ein früherer Lauf wurde abgebrochen (Absturz, Runner-Neustart) und konnte die Sperre in HCP Terraform nicht mehr freigeben | Erst **prüfen**, ob wirklich kein Lauf mehr aktiv ist (GitHub Actions, auf dem Runner `pgrep -a terraform`), dann in HCP Terraform unter Workspace → Settings → Locking entsperren, Gegenprobe mit `terraform plan`. Hinweis: Die „Lock Info“ in der Fehlermeldung beschreibt den **eigenen** Versuch, nicht den Halter der Sperre |
| Dienst von einer anderen VM aus nicht erreichbar (`Connection refused`), obwohl Firewall-Regel korrekt ist | Dienst lauscht per Default nur auf `localhost` | Netzwerk-Lauschen (z. B. `listen_addresses` bei PostgreSQL) anpassen, siehe [`docs/db-server-architecture.md`](docs/db-server-architecture.md) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` bei SSH | VM wurde unter gleicher IP neu aufgebaut, neuer Host-Key | `ssh-keygen -f ~/.ssh/known_hosts -R '<ip>'` |
| Checkov zeigt scheinbar wechselnde Ergebnisse ohne Codeänderung | `--check <ID>`-Flag filtert die Anzeige auf einen Check | Ohne `--check`-Filter testen |
| Checkov lädt Custom-Check gar nicht | Fehlende/falsch benannte `__init__.py`, oder falscher `--external-checks-dir`-Pfad | Ordnerstruktur prüfen; direkter `importlib`-Test macht den Fehler sichtbar |
| `build-template` läuft bei jedem manuellen `workflow_dispatch`-Lauf, auch ohne Packer-Änderung | `paths-filter` vergleicht mangels zweitem Commit (`fetch-depth: 1` Default) gegen einen leeren Zustand – alle Dateien gelten dann als "geändert" | `fetch-depth: 2` im `actions/checkout`-Schritt von `detect-changes` setzen |

[↑ Nach oben](#-inhaltsverzeichnis)

---

## ⚠️ Bekannte technische Schuld (offen)

Transparent dokumentiert statt verschwiegen, analog zum `checkov:skip`-Prinzip:

**Ports 80/443 im Golden Image gelten für jede geklonte VM, unabhängig von der Rolle.** Der Packer-Provisioner öffnet UFW-Ports 22/80/443 einmalig im Template (Phase 2B). Für den DB-Server sind das zwei unnötig offene Ports (Verstoß gegen minimale Angriffsfläche) – noch keine Entscheidung getroffen, ob die Ports generell aus dem Template entfernt werden oder rollenspezifische VMs sie aktiv wieder schließen. Details: [`docs/cis-hardening.md`](docs/cis-hardening.md).

**Nginx-Healthcheck läuft bewusst über HTTP, nicht HTTPS.** Der Ansible-Task `Prüfen ob Nginx auf Port 80 antwortet` löst `CKV2_ANSIBLE_1` ("Ensure that HTTPS url is used with uri") im Soft-Gate `ansible-security-scan` aus – TLS ist für den Webserver aktuell nicht eingerichtet, der Check auf Port 80 ist beabsichtigt. Der Job scheitert dadurch reproduzierbar mit Exit-Code 1, `configure-vm` läuft trotzdem an (Soft-Gate-Prinzip). Keine Entscheidung getroffen, ob künftig TLS eingeführt oder der Check gezielt per `checkov:skip` unterdrückt wird.

**Der Pipeline-Token für HCP Terraform hat mehr Rechte als nötig.** Im Free-Tarif gibt es nur das Team `owners`; der Team-Token in `TF_API_TOKEN` hat damit volle Rechte in der Organisation, nicht nur auf den Workspace `02-CI-CO-VM` (Verstoß gegen Least Privilege). Im Betrieb würde man ein eigenes Team mit Rechten nur auf diesen Workspace anlegen. Der Token läuft nach 90 Tagen ab (**12.01.2027**) und muss rechtzeitig erneuert und im Secret ersetzt werden (Rotation).

[↑ Nach oben](#-inhaltsverzeichnis)

---

## 🗺️ Roadmap: Was als Nächstes kommt

Nach Abschluss der Phasen 2A–2C folgen weitere, aufeinander aufbauende Ausbaustufen Richtung Enterprise-Reife:

| Phase | Thema | Kernidee |
|---|---|---|
| **3** | State-Backend | Zentrales, gesperrtes Terraform-State-Backend statt lokaler `.tfstate`-Datei – verhindert State-Drift zwischen verschiedenen Ausführungsorten |
| **4** | Dynamisches Inventar | Ansible fragt Proxmox live nach existierenden VMs ab, statt IPs manuell in `inventory.ini` zu pflegen |
| **5** | Secrets-Management (Vault) | Ablösung von Klartext-Secrets durch HashiCorp Vault, inkl. VM-spezifischer Zugangsdaten |
| **6** | Compliance & Doku-Automatisierung | `terraform-docs`/`ansible-doc` generieren Teile dieser Dokumentation künftig automatisch |

Die vollständige Begründung der Phasenreihenfolge (warum diese Reihenfolge und nicht anders) steht in `00_projekt_ziel_und_lernpfad.md`.

[↑ Nach oben](#-inhaltsverzeichnis)

---

## 🚀 Zukunftsausblick: AI-Driven SIEM & Monitoring

Nach dem erfolgreichen Abschluss der IaC-Phasen wird das Framework um eine automatisierte Sicherheitsüberwachung (SOC-in-a-Box) erweitert:

- **Automated Deployment:** Ansible-gestützte Instanziierung von Netzwerk-Sensoren (**Zeek / Snort**) sowie ein zentraler Log-Cluster (**Grafana / OpenSearch**)
- **Data Pipeline:** Automatisierter Versand von System- und Netzwerktracks (via Promtail/Beats) an das zentrale SIEM
- **AI-Driven Analytics:** Eigenständige Python-Pipeline (**Pandas**) zur Anomalie-Erkennung in Log-Strukturen
- **Automated Reporting:** LLM-gestützte Kontext-Evaluierung von Sicherheitsvorfällen, Generierung von *Executive Security Compliance Reports*

[↑ Nach oben](#-inhaltsverzeichnis)