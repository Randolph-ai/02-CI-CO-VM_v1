# 🚀 CI/CD Pipeline Setup für Proxmox mit Security-Gate

> Automatisierte Infrastructure-as-Code Pipeline mit Packer, Terraform, Ansible, GitHub Actions und Checkov Custom Policy Checks


![Version](https://img.shields.io/badge/version-1.2.0-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Proxmox](https://img.shields.io/badge/Proxmox-7.x-red)
![Checkov](https://img.shields.io/badge/Checkov-3.3+-brightgreen)

---

## 📋 Inhaltsverzeichnis

- [Projektübersicht](#projektübersicht)
- [Technologie-Stack](#technologie-stack)
- [Projektstruktur](#projektstruktur)
- [Security-Gate mit Checkov](#security-gate-mit-checkov)
- [CIS-Härtung des Golden Images](#-cis-härtung-des-golden-images-phase-2b)
- [Dual-Authentifizierung: Packer vs. Terraform](#-dual-authentifizierung-packer-vs-terraform)
- [SSH-Key-Architektur: Build vs. Produktiv](#-ssh-key-architektur-build-vs-produktiv)
- [Voraussetzungen](#voraussetzungen)
- [Installation & Setup](#installation--setup)
- [Nutzung](#nutzung)
- [Konfiguration](#konfiguration)
- [Fehlerbehebung](#fehlerbehebung)
- [Zukunftsausblick & Next Steps](#-zukunftsausblick--next-steps-ai-driven-siem--monitoring)

---
## 🎯 Projektübersicht

![Proxmox CI/CD Pipeline](docs/images/pipeline-diagramm.png)
Dieses Projekt automatisiert die sichere Bereitstellung einer vollständigen Infrastruktur auf Proxmox VE mittels Infrastructure-as-Code (IaC). Ein hartes Security-Gate (Terraform-Seite) sowie ein ergänzendes Soft-Gate (Ansible-Seite) verhindern bzw. dokumentieren fehlerhafte Deployments.

| Komponente | Aufgabe |
|------------|---------|
| **Packer** | Erstellt ein Ubuntu 22.04 Golden-Image-Template (Cloud-Image-basiert, `proxmox-clone`-Builder) |
| **Terraform** | Provisioniert VMs auf Proxmox mittels `bpg/proxmox` Provider |
| **Checkov** | Validiert IaC auf Security-Policies **vor** dem Deploy (Terraform: hartes Gate, Ansible: Soft-Gate) |
| **Ansible** | Konfiguriert Nginx auf den VMs |
| **GitHub Actions** | Automatisiert die komplette Pipeline inkl. beider Security-Gates (self-hosted Runner) |

---

## 🛠 Technologie-Stack

| Tool | Version | Zweck |
|------|---------|-------|
| Packer | 1.9+ (Proxmox-Plugin gepinnt auf `1.1.8`) | Template-Erstellung |
| Terraform | 1.5+ | Infrastructure Provisioning |
| Checkov | 3.3.6 | Policy-as-Code Security-Scanning (Terraform- und Ansible-Framework) |
| Ansible | 2.14+ | Configuration Management |
| Proxmox VE | 7.x/8.x | Virtualisierungsplattform |
| Ubuntu | 22.04 LTS | Betriebssystem (Cloud-Image) |

---

## 📁 Projektstruktur

### Hauptverzeichnis
- **`.github/workflows/pipeline.yml`** - GitHub Actions Pipeline mit beiden Security-Gates
- **`README.md`** - Projektdokumentation

### Packer
- **`packer/ubuntu-2204.pkr.hcl`** - Packer Template (`proxmox-clone`-Builder)
- **`packer/setup-base-image.sh`** - Reproduzierbarer Aufbau der Cloud-Image-Basis-VM
- **`packer/_archiv-iso-ansatz/`** - Archivierter, verworfener ISO/Subiquity-Ansatz (Dokumentationszweck)

### Terraform
- **`terraform/main.tf`** - VM-Definitionen
- **`terraform/provider.tf`** - Provider & API-Konfiguration
- **`terraform/variables.tf`** - Variablendeklaration
- **`terraform/outputs.tf`** - Ausgaben für Ansible
- **`terraform/checks/`** - Custom Checkov Security Checks
    - **`__init__.py`** - Python Package Marker
    - **`resource/`** - Checks für `resource`-Blöcke
        - **`__init__.py`** - Python Package Marker
        - **`ProxmoxAgentEnabled.py`** - `CKV_PROXMOX_1`: Erzwingt QEMU Guest Agent
        - **`ProxmoxDiskMemorySet.py`** - `CKV_PROXMOX_3`: Erzwingt Mindest-RAM/Disk
    - **`provider/`** - Checks für `provider`-Blöcke
        - **`__init__.py`** - Python Package Marker
        - **`ProxmoxProviderInsecure.py`** - `CKV_PROXMOX_2`: Meldet `insecure=true` (TLS-Verifikation deaktiviert)
- **`terraform/terraform.tfvars.example`** - Variablen-Vorlage

### Ansible
- **`ansible/inventory.ini`** - Wird pro Pipeline-Lauf dynamisch aus der Terraform-Output-IP erzeugt
- **`ansible/playbook.yml`** - Nginx-Setup (Firewall, Service, individuelle index.html)
- **`ansible/checks/task/`** - Custom Checkov Security Check für Ansible-Tasks
    - **`__init__.py`** - Python Package Marker
    - **`CopyModeNotWorldWritable.py`** - `CKV_ANSIBLE_CUSTOM_1`: Meldet world-writable Dateiberechtigungen bei `copy`/`template`-Tasks

---

## 🔒 Security-Gate mit Checkov

Die Pipeline enthält **zwei** Checkov-Gates mit unterschiedlicher Härte:

- **Terraform-Seite (hart):** Kein `continue-on-error`, kein `|| true`. Verstöße stoppen die Pipeline **vor** dem `terraform apply` – `deploy-vm`, `ansible-security-scan` und `configure-vm` starten in diesem Fall gar nicht erst.
- **Ansible-Seite (weich):** Läuft mit `continue-on-error: true`. Verstöße werden im Report sichtbar, blockieren `configure-vm` aber bewusst nicht (Ansible-Konfiguration wird als weniger kritisch für den sofortigen Stopp eingestuft als die Infrastruktur-Ebene).

### Implementierte Custom Checks

| ID | Name | Framework | Prüft | Status im Projekt |
|----|------|-----------|-------|------|
| `CKV_PROXMOX_1` | ProxmoxAgentEnabled | Terraform | `agent.enabled = true` muss gesetzt sein (sonst kann Terraform die VM-IP nicht auslesen) | Aktiv, PASSED |
| `CKV_PROXMOX_2` | ProxmoxProviderInsecure | Terraform | `insecure = true` im `provider`-Block (TLS-Verifikation deaktiviert) | Aktiv, bewusst geskippt (siehe unten) |
| `CKV_PROXMOX_3` | ProxmoxDiskMemorySet | Terraform | Mindestwerte `memory.dedicated >= 2048` MB und `disk.size >= 40` GB | Aktiv, PASSED |
| `CKV_ANSIBLE_CUSTOM_1` | CopyModeNotWorldWritable | Ansible | World-writable Dateiberechtigungen (Oktal-Endziffer 2/3/6/7) bei `copy`/`template`-Tasks | Aktiv, PASSED |

**Hintergrund:** Checkov hat keine eingebauten Regeln für den Community-Provider `bpg/proxmox` – die drei Terraform-Checks oben sind projektspezifische Eigenentwicklungen. Der Ansible-Check schließt eine Lücke, die die eingebauten Ansible-Checkov-Regeln nicht abdecken (keine Prüfung von Datei-Berechtigungen bei `copy`/`template`).

### Tech-Schuld dokumentieren mit `checkov:skip`

Bewusst akzeptierte Ausnahmen werden als dokumentierte Tech-Schuld direkt im Code vermerkt, nicht stillschweigend übergangen. Der Skip-Kommentar steht **direkt über** dem betroffenen Attribut.

**Aktuelles Beispiel aus `terraform/provider.tf`:**
```hcl
# checkov:skip=CKV_PROXMOX_2: Homelab mit self-signed Zertifikat,
# kein produktives TLS-Ziel vorhanden. Bewusst akzeptiertes Risiko,
# dokumentiert und verifiziert in Phase 2A.
insecure = true
```

`CKV_PROXMOX_1`, `CKV_PROXMOX_3` und `CKV_ANSIBLE_CUSTOM_1` sind aktuell ungeskippt und müssen PASSED liefern, damit das jeweilige Gate grün wird (beim Ansible-Check nur im Sinne des Reports, da Soft-Gate).

---

## 🛡️ CIS-Härtung des Golden Images (Phase 2B)

Das Packer-Template wird vor der Auslieferung nach CIS-Benchmark-Prinzipien gehärtet – Security als integraler Bestandteil des Image-Builds, nicht als nachträglicher Schritt:

| Maßnahme | Umsetzung |
|---|---|
| SSH-Passwort-Login | Global gesperrt (`PasswordAuthentication no`), ausschließlich Key-Auth über die gesamte Kette |
| Firewall-Baseline | UFW aktiv, Default-Deny eingehend, nur Ports 22/80/443 erlaubt |
| Security-Updates | `unattended-upgrades`, ausschließlich Security-Only-Kanal (keine regulären Feature-Updates) |
| Unnötige Dienste | Neun Dienste deaktiviert (VMware/LXD-Gast-Tools, iSCSI/Multipath, Ubuntu-Advantage, Pollinate) |
| Build-User-Cleanup | Temporärer Packer-Build-User wird als letzter Schritt im Provisioner entfernt (`userdel`) |

Jede Maßnahme ist über einen vollständigen Packer-Build plus Verifikation gegen eine Wegwerf-VM (`qm guest exec`) bestätigt, bevor sie als abgeschlossen gilt.

---

## 🔐 Dual-Authentifizierung: Packer vs. Terraform

Das Projekt nutzt bewusst zwei unterschiedliche Authentifizierungsmechanismen
gegen die Proxmox-API. Historisch gewachsen, aber dokumentiert statt
stillschweigend inkonsistent.

| | Packer | Terraform |
|---|---|---|
| Auth-Typ | Benutzername/Passwort (`PROXMOX_USER`/`PROXMOX_PASSWORD`) | API-Token (`pm_api_token_id`/`pm_api_token_secret`) |
| Widerruf | Nur durch globale Passwortänderung (betrifft alle Nutzer dieses Kontos) | Einzeln widerrufbar, ohne andere Zugänge zu beeinflussen |
| Rechteumfang | Volle Kontorechte | Granular einschränkbar über Proxmox API-Token-Permissions |

**Warum nicht vereinheitlicht:** Beide Tools unterstützen technisch beide
Auth-Typen (der `bpg/proxmox`-Provider akzeptiert auch Passwort-Auth). Die
Trennung ist keine funktionale Notwendigkeit, sondern historisch entstanden.
Eine Vereinheitlichung auf Token für beide Tools ist als mögliche künftige
Verbesserung vorgemerkt.

**Injection-Mechanismus (eigene Ebene, nicht mit dem Auth-Typ zu verwechseln):**
- Packer: `env("PROXMOX_PASSWORD")` explizit im HCL-Code (Packer-eigene Syntax)
- Terraform: automatischer `TF_VAR_`-Präfix aus der Umgebung (Terraform-Konvention, kein expliziter Code-Aufruf nötig)

---

## 🔑 SSH-Key-Architektur: Build vs. Produktiv

Analog zur Dual-Authentifizierung auf Proxmox-API-Ebene wird auch beim SSH-Zugriff **innerhalb** der VMs strikt zwischen Build- und Produktivzugang getrennt – zwei unabhängige Schlüsselpaare für zwei unabhängige Vertrauenszonen:

| | Packer (Build) | Terraform/Ansible (Produktiv) |
|---|---|---|
| Privater Key | `id_ed25519` | `id_ed25519_terraform` |
| Username | temporär, wird als letzter Provisioner-Schritt per `userdel` entfernt | `ansible` (dauerhaft) |
| Lebensdauer des Zugangs | Minuten (nur während des Builds) | Dauerhaft (solange die VM läuft) |
| Verbindungsweg | Packer verbindet sich aktiv per SSH gegen die Build-VM | Terraform spricht **ausschließlich** mit der Proxmox-API, nie per SSH – Ansible verbindet sich aktiv per SSH gegen die fertige VM |
| Key-Übergabe an die VM | Direkt durch Packers `proxmox-clone`-Builder | Terraform platziert nur den **Public Key** via Cloud-Init (separates virtuelles CD-ROM-Medium, gelesen ausschließlich beim allerersten Boot einer neuen Instance-ID) |

**Warum getrennt und nicht ein gemeinsamer Key:** Ein gestohlener Build-Key öffnet nur eine VM, die es in Kürze ohnehin nicht mehr gibt (Blast-Radius-Begrenzung). Bei einem gemeinsamen Key hätte derselbe Diebstahl dauerhaften Zugriff auf die laufende Produktions-VM bedeutet. Ein Angreifer müsste bei getrennten Keys zwei unabhängige Diebstähle erfolgreich durchführen statt nur einen.

**Variable als Wert statt als Pfad:** `var.ssh_public_key` in `terraform.tfvars` enthält den Public-Key-**Inhalt** direkt (kein `file()`-Aufruf, kein Dateipfad). Grund: Ein Pfad mit `~` wird von Terraform nicht wie in der Bash-Shell automatisch aufgelöst, und der GitHub-Actions-Runner checkt das Repo ohnehin in ein komplett anderes Arbeitsverzeichnis aus, in dem eine lokale `terraform.tfvars` gar nicht existiert. Der Key-Inhalt kommt in der Pipeline stattdessen aus dem GitHub Secret `SSH_PUBLIC_KEY` (`TF_VAR_ssh_public_key`).

---

## ⚙️ Voraussetzungen

- Proxmox VE Host, erreichbar über die API (`https://<proxmox-ip>:8006/api2/json`)
- Self-hosted GitHub Actions Runner, registriert mit den Labels `self-hosted` **und** `proxmox` (ohne exaktes Label-Match hängt der Job endlos in der Warteschlange, ohne Fehlermeldung)
- Auf dem Runner installiert: Packer, Terraform, Ansible, Checkov (>= 3.3.6)
- GitHub Secrets gesetzt:
  - `PROXMOX_URL`, `PROXMOX_USER`, `PROXMOX_PASSWORD` (für Packer)
  - `TF_VAR_*`-Secrets passend zu den in `variables.tf` deklarierten Variablen (für Terraform)
  - `SSH_PRIVATE_KEY` (dauerhafter Produktiv-Key für Terraform/Ansible,
    User `ansible` – strikt getrennt vom temporären, nur build-lebendigen
    Packer-SSH-Key, siehe Abschnitt [SSH-Key-Architektur](#-ssh-key-architektur-build-vs-produktiv))
  - `SSH_PUBLIC_KEY` (öffentlicher Gegenpart, wird als `TF_VAR_ssh_public_key`
    an Terraform übergeben)
- Eine bereits existierende Cloud-Image-Basis-VM (Template, standardmäßig VM-ID `9000`) als Klon-Quelle für Packer

## 🔧 Installation & Setup

1. Repository auf den self-hosted Runner klonen
2. Basis-Image einmalig aufbauen:
   ```bash
   chmod +x packer/setup-base-image.sh
   ./packer/setup-base-image.sh
   ```
   Erstellt die Cloud-Image-Basis-VM (Standard: ID `9000`), inkl. Disk-Vergrößerung und Guest-Agent-Flag.
3. `terraform/terraform.tfvars` aus `terraform/terraform.tfvars.example` erstellen und mit den eigenen Werten befüllen (Netzwerk, IPs, Disk-Größe, `template_vm_id`)
4. GitHub Secrets im Repo hinterlegen (siehe Voraussetzungen)
5. Self-hosted Runner registrieren und mit dem Label `proxmox` versehen
6. Push auf `main` (oder Pull Request) startet die Pipeline automatisch

## ▶️ Nutzung

Ein Push auf `main` löst die Pipeline mit fünf aufeinander aufbauenden Jobs aus:

```
build-template          → Packer baut/erneuert das Golden-Image-Template
security-scan           → Checkov-Gate, Terraform (hart) – Stop bei Verstoß
deploy-vm               → Terraform provisioniert die VM aus dem Template
ansible-security-scan   → Checkov-Gate, Ansible (weich) – Report, kein Stop
configure-vm            → Ansible konfiguriert Nginx auf der VM
```

Der Fortschritt ist im GitHub-Actions-Tab des Repos einsehbar. Schlägt `security-scan` fehl, werden `deploy-vm`, `ansible-security-scan` und `configure-vm` gar nicht erst gestartet (als "Skipped" markiert, 0 Sekunden Laufzeit). Schlägt dagegen `ansible-security-scan` fehl, läuft `configure-vm` trotzdem an (Soft-Gate, `continue-on-error: true`).

Nach einem erfolgreichen Lauf ist die VM über die von Terraform ausgegebene IP erreichbar (`terraform output -raw vm_ip`), Nginx liefert dort eine mit Live-Facts (Hostname, IP) generierte `index.html`.

## 🔩 Konfiguration

Wichtige Stellschrauben in `terraform/variables.tf` / `terraform.tfvars`:
- `template_vm_id` – ID des Packer-Golden-Image-Templates, das geklont wird
- `web_server_ip`, `network_gateway` – Netzwerkkonfiguration der VM
- `web_server_disk_size` – Ziel-Diskgröße nach Cloud-Init-Resize (muss `>= 40` sein, sonst blockiert `CKV_PROXMOX_3`)

Mindestwerte der Custom Checks sind direkt im jeweiligen Check-Code als Konstanten hinterlegt (z. B. `MIN_DISK_SIZE_GB`, `MIN_MEMORY_MB` in `ProxmoxDiskMemorySet.py`) und bei Bedarf dort anpassbar.

## 🩹 Fehlerbehebung

| Symptom | Ursache | Lösung |
|---|---|---|
| Job hängt endlos in "Queued" | Runner-Label passt nicht zu `runs-on` in `pipeline.yml` | Label `proxmox` beim Runner ergänzen |
| `E: Could not get lock /var/lib/apt/lists/lock` im Packer-Build | Cloud-Init läuft beim ersten Boot noch, blockiert `apt`-Lock | `sudo cloud-init status --wait` als erste Zeile im `shell`-Provisioner |
| `config file already exists` beim Packer-Build | Template-VM-ID existiert in Proxmox bereits | Cleanup-Step (`qm destroy <id> \|\| true`) vor dem Build, bereits in `pipeline.yml` integriert |
| Terraform will VM erneut anlegen, obwohl sie läuft | `terraform.tfstate` ging beim Checkout verloren (self-hosted Runner mit geteiltem Arbeitsordner) | `clean: false` bei **allen** `actions/checkout`-Schritten setzen, nicht nur bei einem Job |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` bei SSH | VM wurde unter gleicher IP neu aufgebaut, neuer Host-Key | `ssh-keygen -f ~/.ssh/known_hosts -R '<ip>'` |
| Checkov zeigt scheinbar wechselnde Ergebnisse ohne Codeänderung | `--check <ID>`-Flag filtert die Anzeige auf einen Check, sieht wie fehlende Checks aus | Ohne `--check`-Filter testen, um alle Checks gemeinsam zu sehen |
| Checkov lädt Custom-Check gar nicht | Fehlende/falsch benannte `__init__.py`, oder Check-Ordner liegt nicht an der erwarteten Stelle unter `--external-checks-dir` | Ordnerstruktur und Dateinamen exakt prüfen; direkter `importlib`-Test macht den echten Fehler sichtbar (Checkov selbst loggt das oft nur als leises `INFO`) |

---

## 🚀 Zukunftsausblick & Next Steps: AI-Driven SIEM & Monitoring

Nach dem erfolgreichen Abschluss der IaC-Phasen wird das Framework um eine automatisierte Sicherheitsüberwachung (SOC-in-a-Box) erweitert:

- **Automated Deployment:** Ansible-gestützte Instanziierung von Netzwerk-Sensoren (**Zeek / Snort**) auf den Ziel-VMs sowie ein zentraler Log-Cluster (**Grafana / OpenSearch**).
- **Data Pipeline:** Automatisierter Versand von System- und Netzwerktracks (via Promtail/Beats) an das zentrale SIEM.
- **AI-Driven Analytics:** Eigenständige Python-Pipeline unter Verwendung von **Pandas** zur Anomalie-Erkennung in Log-Strukturen.
- **Automated Reporting:** Integration von AI-Modellen (LLMs) zur automatisierten Kontext-Evaluierung von Sicherheitsvorfällen und Generierung von *Executive Security Compliance Reports*.