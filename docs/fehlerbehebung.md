# 🩹 Fehlerbehebung

[← Zurück zur README](../README.md#-architektur-vertiefungen)

| Symptom | Ursache | Lösung |
|---|---|---|
| Job hängt endlos in "Queued" | Runner-Label passt nicht zu `runs-on` in `pipeline.yml` | Label `proxmox` beim Runner ergänzen |
| `E: Could not get lock /var/lib/apt/lists/lock` im Packer-Build | Cloud-Init läuft beim ersten Boot noch, blockiert `apt`-Lock | `sudo cloud-init status --wait` als erste Zeile im `shell`-Provisioner |
| `config file already exists` beim Terraform-`apply`, obwohl Plan `X to add` zeigt | State-Drift: lokal getesteter State kennt eine VM, die im Runner-eigenen State nicht existiert | Betroffene VM einmalig löschen (`qm destroy <id>`), Pipeline im Runner-Kontext neu bauen lassen. Strukturelle Lösung: zentrales State-Backend (Phase 3) |
| Terraform will VM erneut anlegen, obwohl sie läuft | `terraform.tfstate` ging beim Checkout verloren (self-hosted Runner mit geteiltem Arbeitsordner) | `clean: false` bei **allen** `actions/checkout`-Schritten setzen |
| `Error acquiring the state lock`, obwohl kein anderer Lauf aktiv scheint | Hängender Lock: ein früherer Lauf wurde abgebrochen (Absturz, Runner-Neustart) und konnte die Sperre in HCP Terraform nicht mehr freigeben | Erst **prüfen**, ob wirklich kein Lauf mehr aktiv ist (GitHub Actions, auf dem Runner `pgrep -a terraform`), dann in HCP Terraform unter Workspace → Settings → Locking entsperren, Gegenprobe mit `terraform plan`. Hinweis: Die „Lock Info“ in der Fehlermeldung beschreibt den **eigenen** Versuch, nicht den Halter der Sperre |
| Dienst von einer anderen VM aus nicht erreichbar (`Connection refused`), obwohl Firewall-Regel korrekt ist | Dienst lauscht per Default nur auf `localhost` | Netzwerk-Lauschen (z. B. `listen_addresses` bei PostgreSQL) anpassen, siehe [`db-server-architecture.md`](db-server-architecture.md) |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` bei SSH | VM wurde unter gleicher IP neu aufgebaut, neuer Host-Key | `ssh-keygen -f ~/.ssh/known_hosts -R '<ip>'` |
| Checkov zeigt scheinbar wechselnde Ergebnisse ohne Codeänderung | `--check <ID>`-Flag filtert die Anzeige auf einen Check | Ohne `--check`-Filter testen |
| Checkov lädt Custom-Check gar nicht | Fehlende/falsch benannte `__init__.py`, oder falscher `--external-checks-dir`-Pfad | Ordnerstruktur prüfen; direkter `importlib`-Test macht den Fehler sichtbar |
| `build-template` läuft bei jedem manuellen `workflow_dispatch`-Lauf, auch ohne Packer-Änderung | `paths-filter` vergleicht mangels zweitem Commit (`fetch-depth: 1` Default) gegen einen leeren Zustand – alle Dateien gelten dann als "geändert" | `fetch-depth: 2` im `actions/checkout`-Schritt von `detect-changes` setzen |

[← Zurück zur README](../README.md#-architektur-vertiefungen)
