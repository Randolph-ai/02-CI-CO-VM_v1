# 🚀 CI/CD Pipeline Setup für Proxmox

> Automatisierte Infrastructure-as-Code Pipeline mit Packer, Terraform, Ansible und GitHub Actions

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-orange)
![Proxmox](https://img.shields.io/badge/Proxmox-7.x-red)

---

## 📋 Inhaltsverzeichnis

- [Projektübersicht](#projektübersicht)
- [Technologie-Stack](#technologie-stack)
- [Projektstruktur](#projektstruktur)
- [Voraussetzungen](#voraussetzungen)
- [Installation & Setup](#installation--setup)
- [Nutzung](#nutzung)
- [Konfiguration](#konfiguration)
- [Fehlerbehebung](#fehlerbehebung)

---

## 🎯 Projektübersicht

Dieses Projekt automatisiert die Bereitstellung einer vollständigen Infrastruktur auf Proxmox VE mittels Infrastructure-as-Code (IaC).

| Komponente | Aufgabe |
|------------|---------|
| **Packer** | Erstellt ein Ubuntu 22.04 Template mit Cloud-Init |
| **Terraform** | Provisioniert VMs auf Proxmox |
| **Ansible** | Konfiguriert Nginx und PostgreSQL |
| **GitHub Actions** | Automatisiert die Pipeline |

---

## 🛠️ Technologie-Stack

| Tool | Version | Zweck |
|------|---------|-------|
| Packer | 1.9+ | Template-Erstellung |
| Terraform | 1.5+ | Infrastructure Provisioning |
| Ansible | 2.14+ | Configuration Management |
| Proxmox VE | 7.x | Virtualisierungsplattform |
| Ubuntu | 22.04 LTS | Betriebssystem |

---

## 📁 Projektstruktur

### Hauptverzeichnis
- **`.github/workflows/pipeline.yml`** - GitHub Actions Pipeline
- **`README.md`** - Projektdokumentation

### Packer
- **`packer/http/meta-data`** - Cloud-Init Meta-Daten
- **`packer/http/user-data`** - Cloud-Init Autoinstall Konfiguration
- **`packer/ubuntu-2204.pkr.hcl`** - Packer Template

### Terraform
- **`terraform/main.tf`** - VM-Definitionen (bpg/proxmox)
- **`terraform/provider.tf`** - Provider & API-Konfiguration
- **`terraform/variables.tf`** - Variablendeklaration
- **`terraform/outputs.tf`** - Ausgaben für Ansible
- **`terraform/terraform.tfvars.example`** - Variablen-Vorlage

### Ansible
- **`ansible/inventory.ini`** - Dynamisches Host-Inventory
- **`ansible/playbook.yml`** - Nginx & PostgreSQL Setup

---

## 📋 Voraussetzungen

### Lokale Entwicklungsumgebung

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y packer terraform ansible git

# macOS mit Homebrew
brew install packer terraform ansible git
