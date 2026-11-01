# Bericht: Admin installiert ein Tool – nmap auf web-server-prod

> **Cyber Range – Übung vom 01.11.2026.** [← Zurück zur README](../../../README.md#-cyber-range)
>
> **Übungsfall in der eigenen Cyber Range.** Die Admin-Aktion wurde
> bewusst selbst ausgeführt, die Auswertung danach aus Sicht eines SOC-Analysten
> (L1). Alle Daten sind echt und stammen von der eigenen VM 1001.

| Feld | Inhalt |
|---|---|
| **Title** | Manual installation and removal of nmap on web-server-prod (sudo, account ansible) |
| **Severity** | Medium – known key from an internal host, but nmap on a production web server is non-standard and was removed afterwards |
| **Classification** | Suspicious activity – pending verification (change approval not yet checked) |
| **Affected Host** | web-server-prod (10.0.30.101) |
| **Source IP** | 10.0.10.75 (soar-dev-server, intern) |
| **Anlass** | proaktive Log-Prüfung (kein Alarm) |
| **Status** | Open – pending verification |

## Timeline (UTC)

```
07:22:07  SSH login as ansible from 10.0.10.75 (key "terraform-produktiv-zugang")
07:24:17  sudo apt update
07:25:48  sudo apt install -y nmap (nmap + 5 dependencies installed 07:25:51–52)
08:13:57  apt purge -y nmap
08:15:07  apt autoremove -y (5 dependencies removed)
```

## Summary

Das Konto `ansible` hat sich am 01.11. um 07:22 UTC von 10.0.10.75 per SSH auf
web-server-prod (10.0.30.101) angemeldet, per `sudo` mit root-Rechten den
Netzwerk-Scanner nmap installiert und ihn nach ca. 50 Minuten samt
Abhängigkeiten wieder entfernt. Offen ist, ob die Änderung genehmigt war und ob
nmap in dieser Zeit benutzt wurde.

## Evidence (Befehl → Ergebnis)

| # | Befehl (auf 1001, wenn nicht anders angegeben) | Ergebnis |
|---|---|---|
| 1 | `sudo grep "COMMAND=" /var/log/auth.log \| tail -n 5` | 07:24:17 `apt update` · 07:25:48 `apt install -y nmap` – beide `ansible`, `TTY=pts/0` (SSH), `USER=root` |
| 2 | `sudo grep "Accepted" /var/log/auth.log` | 07:22:07 `Accepted publickey for ansible from 10.0.10.75`, Fingerabdruck `SHA256:dFEt…cYM` |
| 3 | `ssh-keygen -lf ~/.ssh/authorized_keys` (1001) und `ssh-keygen -lf ~/.ssh/id_ed25519_terraform` (soar-dev-server) | beide `SHA256:dFEt…cYM`, Kommentar `terraform-produktiv-zugang` – einziger erlaubter Schlüssel auf 1001 |
| 4 | `tail -n 8 /var/log/apt/history.log` | `Commandline: apt install -y nmap` · `Requested-By: ansible (1000)` · 6 Pakete (nmap + 5 `automatic`) |
| 5 | `grep " install " /var/log/dpkg.log \| tail -n 6` | 07:25:51 `install nmap:amd64 <none>` = Neuinstallation |
| 6 | `grep -A3 "Commandline: apt" /var/log/apt/history.log` | install 07:25:52 · purge 08:13:57 · autoremove 08:15:07 – jeweils `Requested-By: ansible (1000)` |
| 7 | `which nmap` | nicht gefunden → auf dem System keine Spur mehr, nur in den Logs |

**Geprüft und ausgeschlossen:** Kernel-Installation um 07:41 UTC – laut
`history.log` `Commandline: /usr/bin/unattended-upgrade`, **kein**
`Requested-By` → automatisches Sicherheitsupdate, **benign**, kein Bezug zum Fall.

## Actions Taken

- Logs auf 1001 proaktiv geprüft: `auth.log`, `apt/history.log`, `dpkg.log`
- Login-Schlüssel per Fingerabdruck verglichen (Log ↔ `authorized_keys` ↔ Schlüssel auf soar-dev-server)
- Kernel-Update um 07:41 als automatische, harmlose Aktivität eingestuft
- eigene Analysten-Befehle im Log erkannt und aus der Timeline herausgehalten (07:26:44, 07:42:41)
- Classification und Severity festgelegt, Ticket erstellt
- **noch keine** Eskalation – zuerst Genehmigung klären

## Recommendations

1. **Change-Management prüfen:** Gab es eine genehmigte Änderung für nmap auf web-server-prod? Wenn nein → an L2 eskalieren.
2. **Nutzung prüfen:** Hat 1001 zwischen 07:25 und 08:15 UTC andere Systeme gescannt? (Netzwerk-Mitschnitt, Firewall-/Zeek-Logs, `~/.bash_history`)
3. **Mensch und Maschine trennen:** Konto `ansible` und Schlüssel `terraform-produktiv-zugang` werden von der Pipeline **und** manuell genutzt → im Log nicht unterscheidbar. Persönliche Konten/Schlüssel für Admins, eigener Schlüssel nur für die Pipeline.
4. **Soll-Liste der Schlüssel:** erlaubte öffentliche Schlüssel mit Besitzer im Repo, per Ansible verteilt.
5. **Spuren sichern:** `auditd` aktivieren und Logs zentral sammeln – lokale Logs kann ein Admin mit root-Rechten löschen; Installationen ohne `apt` (z. B. `curl`, `snap`) stehen nicht in `apt/history.log`.
