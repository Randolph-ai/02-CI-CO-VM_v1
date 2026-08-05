# 🔒 Security-Gate mit Checkov

Die Pipeline enthält **zwei** Checkov-Gates mit unterschiedlicher Härte:

- **Terraform-Seite (hart):** Kein `continue-on-error`, kein `|| true`. Verstöße stoppen die Pipeline **vor** dem `terraform apply` – `deploy-vm`, `ansible-security-scan` und `configure-vm` starten in diesem Fall gar nicht erst.
- **Ansible-Seite (weich):** Läuft mit `continue-on-error: true`. Verstöße werden im Report sichtbar, blockieren `configure-vm` aber bewusst nicht (Ansible-Konfiguration wird als weniger kritisch für den sofortigen Stopp eingestuft als die Infrastruktur-Ebene).

## Implementierte Custom Checks

| ID | Name | Framework | Prüft | Status im Projekt |
|----|------|-----------|-------|------|
| `CKV_PROXMOX_1` | ProxmoxAgentEnabled | Terraform | `agent.enabled = true` muss gesetzt sein (sonst kann Terraform die VM-IP nicht auslesen) | Aktiv, PASSED |
| `CKV_PROXMOX_2` | ProxmoxProviderInsecure | Terraform | `insecure = true` im `provider`-Block (TLS-Verifikation deaktiviert) | Aktiv, bewusst geskippt (siehe unten) |
| `CKV_PROXMOX_3` | ProxmoxDiskMemorySet | Terraform | Mindestwerte `memory.dedicated >= 2048` MB und `disk.size >= 40` GB | Aktiv, PASSED (beide VMs) |
| `CKV_ANSIBLE_CUSTOM_1` | CopyModeNotWorldWritable | Ansible | World-writable Dateiberechtigungen (Oktal-Endziffer 2/3/6/7) bei `copy`/`template`-Tasks | Aktiv, PASSED |

**Hintergrund:** Checkov hat keine eingebauten Regeln für den Community-Provider `bpg/proxmox` – die drei Terraform-Checks oben sind projektspezifische Eigenentwicklungen. Der Ansible-Check schließt eine Lücke, die die eingebauten Ansible-Checkov-Regeln nicht abdecken (keine Prüfung von Datei-Berechtigungen bei `copy`/`template`).

## Tech-Schuld dokumentieren mit `checkov:skip`

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
[← Zurück zur README](../README.md)
