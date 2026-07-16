# 🚀 CI/CD Pipeline Setup für Proxmox mit Security-Gate

> Automatisierte Infrastructure-as-Code Pipeline mit Packer, Terraform, Ansible, GitHub Actions und Checkov Custom Policy Checks

![Version](https://img.shields.io/badge/version-1.1.0-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Proxmox](https://img.shields.io/badge/Proxmox-7.x-red)
![Checkov](https://img.shields.io/badge/Checkov-3.3+-brightgreen)

---

## 📋 Inhaltsverzeichnis

- [Projektübersicht](#projektübersicht)
- [Technologie-Stack](#technologie-stack)
- [Projektstruktur](#projektstruktur)
- [Security-Gate mit Checkov](#security-gate-mit-checkov)
- [Voraussetzungen](#voraussetzungen)
- [Installation & Setup](#installation--setup)
- [Nutzung](#nutzung)
- [Konfiguration](#konfiguration)
- [Fehlerbehebung](#fehlerbehebung)
- [Zukunftsausblick & Next Steps](#-zukunftsausblick--next-steps-ai-driven-siem--monitoring)

---

## 🎯 Projektübersicht

Dieses Projekt automatisiert die sichere Bereitstellung einer vollständigen Infrastruktur auf Proxmox VE mittels Infrastructure-as-Code (IaC). Ein hartes Security-Gate verhindert fehlerhafte Deployments.

| Komponente | Aufgabe |
|------------|---------|
| **Packer** | Erstellt ein Ubuntu 22.04 Golden-Image-Template (Cloud-Image-basiert, `proxmox-clone`-Builder) |
| **Terraform** | Provisioniert VMs auf Proxmox mittels `bpg/proxmox` Provider |
| **Checkov** | Validiert IaC auf Security-Policies **vor** dem Deploy (hartes Gate, kein Soft-Fail) |
| **Ansible** | Konfiguriert Nginx auf den VMs |
| **GitHub Actions** | Automatisiert die komplette Pipeline inkl. Security-Gate (self-hosted Runner) |

---

## 🛠 Technologie-Stack

| Tool | Version | Zweck |
|------|---------|-------|
| Packer | 1.9+ (Proxmox-Plugin gepinnt auf `1.1.8`) | Template-Erstellung |
| Terraform | 1.5+ | Infrastructure Provisioning |
| Checkov | 3.3.6 | Policy-as-Code Security-Scanning |
| Ansible | 2.14+ | Configuration Management |
| Proxmox VE | 7.x/8.x | Virtualisierungsplattform |
| Ubuntu | 22.04 LTS | Betriebssystem (Cloud-Image) |

---

## 📁 Projektstruktur

### Hauptverzeichnis
- **`.github/workflows/pipeline.yml`** - GitHub Actions Pipeline mit Security-Gate
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

---

## 🔒 Security-Gate mit Checkov

Die Pipeline enthält ein **hartes** Security-Gate mittels Custom Checkov Checks (kein `continue-on-error`, kein `|| true`). Verstöße gegen die Policies stoppen die Pipeline **vor** dem `terraform apply` – `deploy-vm` und `configure-vm` starten in diesem Fall gar nicht erst.

### Implementierte Custom Checks

| ID | Name | Prüft | Status im Projekt |
|----|------|-------|------|
| `CKV_PROXMOX_1` | ProxmoxAgentEnabled | `agent.enabled = true` muss gesetzt sein (sonst kann Terraform die VM-IP nicht auslesen) | Aktiv, PASSED |
| `CKV_PROXMOX_2` | ProxmoxProviderInsecure | `insecure = true` im `provider`-Block (TLS-Verifikation deaktiviert) | Aktiv, bewusst geskippt (siehe unten) |
| `CKV_PROXMOX_3` | ProxmoxDiskMemorySet | Mindestwerte `memory.dedicated >= 2048` MB und `disk.size >= 40` GB | Aktiv, PASSED |

**Hintergrund:** Checkov hat keine eingebauten Regeln für den Community-Provider `bpg/proxmox` – alle drei Checks oben sind projektspezifische Eigenentwicklungen, keine Standard-Checkov-Policies.

### Tech-Schuld dokumentieren mit `checkov:skip`

Bewusst akzeptierte Ausnahmen werden als dokumentierte Tech-Schuld direkt im Code vermerkt, nicht stillschweigend übergangen. Der Skip-Kommentar steht **direkt über** dem betroffenen Attribut.

**Aktuelles Beispiel aus `terraform/provider.tf`:**
```hcl
# checkov:skip=CKV_PROXMOX_2: Homelab mit self-signed Zertifikat,
# kein produktives TLS-Ziel vorhanden. Bewusst akzeptiertes Risiko,
# dokumentiert und verifiziert in Phase 2A.
insecure = true
```

`CKV_PROXMOX_1` und `CKV_PROXMOX_3` sind aktuell ungeskippt und müssen PASSED liefern, damit das Gate grün wird.

---

## ⚙️ Voraussetzungen

- Proxmox VE Host, erreichbar über die API (`https://<proxmox-ip>:8006/api2/json`)
- Self-hosted GitHub Actions Runner, registriert mit den Labels `self-hosted` **und** `proxmox` (ohne exaktes Label-Match hängt der Job endlos in der Warteschlange, ohne Fehlermeldung)
- Auf dem Runner installiert: Packer, Terraform, Ansible, Checkov (>= 3.3.6)
- GitHub Secrets gesetzt:
  - `PROXMOX_URL`, `PROXMOX_USER`, `PROXMOX_PASSWORD` (für Packer)
  - `TF_VAR_*`-Secrets passend zu den in `variables.tf` deklarierten Variablen (für Terraform)
  - `SSH_PRIVATE_KEY` (temporärer Key für den Ansible-Zugriff auf die frisch deployte VM – getrennt vom dauerhaften Packer-SSH-Key)
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

Ein Push auf `main` löst die Pipeline mit vier aufeinander aufbauenden Jobs aus:

```
build-template   → Packer baut/erneuert das Golden-Image-Template
security-scan    → Checkov-Gate (siehe oben) – hartes Stop bei Verstoß
deploy-vm        → Terraform provisioniert die VM aus dem Template
configure-vm     → Ansible konfiguriert Nginx auf der VM
```

Der Fortschritt ist im GitHub-Actions-Tab des Repos einsehbar. Schlägt `security-scan` fehl, werden `deploy-vm` und `configure-vm` gar nicht erst gestartet (als "Skipped" markiert, 0 Sekunden Laufzeit).

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
| Checkov lädt Custom-Check gar nicht | Fehlende/falsch benannte `__init__.py`, oder Check-Ordner liegt nicht unter `terraform/checks/{resource,provider}/` | Ordnerstruktur und Dateinamen exakt prüfen; direkter `importlib`-Test macht den echten Fehler sichtbar (Checkov selbst loggt das oft nur als leises `INFO`) |

---

## 🚀 Zukunftsausblick & Next Steps: AI-Driven SIEM & Monitoring

Nach dem erfolgreichen Abschluss der IaC-Phasen wird das Framework um eine automatisierte Sicherheitsüberwachung (SOC-in-a-Box) erweitert:

- **Automated Deployment:** Ansible-gestützte Instanziierung von Netzwerk-Sensoren (**Zeek / Snort**) auf den Ziel-VMs sowie ein zentraler Log-Cluster (**Grafana / OpenSearch**).
- **Data Pipeline:** Automatisierter Versand von System- und Netzwerktracks (via Promtail/Beats) an das zentrale SIEM.
- **AI-Driven Analytics:** Eigenständige Python-Pipeline unter Verwendung von **Pandas** zur Anomalie-Erkennung in Log-Strukturen.
- **Automated Reporting:** Integration von AI-Modellen (LLMs) zur automatisierten Kontext-Evaluierung von Sicherheitsvorfällen und Generierung von *Executive Security Compliance Reports*.