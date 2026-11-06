# Bericht: Admin installiert ein Tool – socat auf web-server-prod

> **Cyber Range – Übung vom 06.11.2026 (Timeline Nr. 002).** [← Zurück zur Timeline](../README.md) · [← README](../../../README.md#-cyber-range)
>
> **Übungsfall in der eigenen Cyber Range.** Die Admin-Aktion wurde
> bewusst selbst ausgeführt, die Auswertung danach aus Sicht eines SOC-Analysten
> (L1). Alle Daten sind echt und stammen von der eigenen VM 1001.
> Zweiter Durchgang derselben Übung wie am [01.11.](2026-11-01_admin-installiert-tool.md),
> diesmal mit anderem Tool und **selbst geführt**.

| Feld | Inhalt |
|---|---|
| **Title** | Installation and removal of `socat` via sudo by account `ansible` on web-server-prod (10.0.30.101) |
| **Severity** | Medium – dual-use tool installed and quickly removed on a production server; authorization unverified, no damage observed |
| **Classification** | Suspicious activity – pending verification (change approval not yet checked) |
| **MITRE ATT&CK** | T1078 Valid Accounts · T1021.004 Remote Services: SSH · T1105 Ingress Tool Transfer · T1070.004 Indicator Removal: File Deletion |
| **Affected Host** | web-server-prod (10.0.30.101, VLAN 30, VM 1001) |
| **Source IP** | 10.0.10.75 (soar-dev-server, intern – Admin-Host und Pipeline-Runner) |
| **Anlass** | proaktive Log-Prüfung (kein Alarm) |
| **Status** | Open – pending verification (awaiting authorization check) |

**MITRE ATT&CK aus Verteidiger-Sicht:** Die Zeile nennt die **erkannten Muster**,
nicht das Urteil „Angriff“ – darum bleibt die Classification offen.

## Timeline (UTC)

```
05:49:52  SSH login as ansible from 10.0.10.75 (key "terraform-produktiv-zugang") – unexplained
05:51:52  SSH login as ansible from 10.0.10.75 – confirmed by account owner (test)
05:53:11  SSH login as ansible from 10.0.10.75 – session of the action (wtmp/lastlog 05:53)
05:57:45  sudo apt install socat
05:57:46  socat installed (new package, 1.7.4.1-3ubuntu4)
07:45:04  apt purge -y socat
~07:45    apt autoremove -y (nothing removed, only visible in auth.log)
```

## Summary

Das Konto `ansible` hat sich am 06.11. von soar-dev-server (10.0.10.75) per SSH
mit dem gemeinsam genutzten Schlüssel `terraform-produktiv-zugang` auf
web-server-prod angemeldet, per `sudo` mit root-Rechten das Dual-Use-Tool
`socat` installiert und es knapp zwei Stunden später wieder entfernt. Laut
`Requested-By` stand ein Mensch dahinter; ob die Änderung genehmigt war, ist
offen. Weil Mensch und Pipeline dasselbe Konto und denselben Schlüssel nutzen,
können die Logs nicht zeigen, **wer** gehandelt hat.

## Evidence (Befehl → Ergebnis)

| # | Befehl (auf 1001, wenn nicht anders angegeben) | Ergebnis |
|---|---|---|
| 1 | `ls -l /var/log` | um 05:57 geändert: `apt/`, `auth.log`, `dpkg.log`, `syslog` · `wtmp`/`lastlog` 05:53 · 05:36 = VM-Start (harmlos) |
| 2 | `sudo grep "COMMAND=" /var/log/auth.log \| tail -n 5` | 05:57:45 `ansible : TTY=pts/0 ; USER=root ; COMMAND=/usr/bin/apt install socat` |
| 3 | `sudo grep "Accepted" /var/log/auth.log \| tail -n 5` | drei Anmeldungen 05:49:52 · 05:51:52 · 05:53:11, alle `ansible` von 10.0.10.75, Fingerabdruck `SHA256:dFEt…cYM` |
| 4 | `ssh-keygen -lf ~/.ssh/authorized_keys` (1001) und `ssh-keygen -lf ~/.ssh/id_ed25519_terraform` (soar-dev-server) | beide `SHA256:dFEt…cYM`, Kommentar `terraform-produktiv-zugang` |
| 5 | `tail -n 8 /var/log/apt/history.log` | `Commandline: apt install socat` · `Requested-By: ansible (1000)` · 1 Paket, keine Abhängigkeiten |
| 6 | `grep " install " /var/log/dpkg.log \| tail -n 6` | 05:57:46 `install socat:amd64 <none>` = Neuinstallation |
| 7 | `grep -A3 "Commandline: apt" /var/log/apt/history.log \| tail -n 12` | install 05:57:46 · purge 07:45:05 – jeweils `Requested-By: ansible (1000)` |
| 8 | `zgrep -hE ' (install\|remove\|purge) ' /var/log/dpkg.log* \| sort \| tail -n 30` | ganze Paket-Geschichte: gleiches Muster „installieren → kurz danach entfernen“ schon am 01.11. (nmap) |
| 9 | `which socat` | vorher leer · nach Installation `/usr/bin/socat` · nach `purge` wieder leer |

**Geprüft und ausgeschlossen:** Kernel-Wechsel am 16.10. und 01.11. – regelmäßiges
4-Zeilen-Muster von `unattended-upgrade`, **benign**.
Eigene Analysten-Befehle (`sudo grep …` um 06:08 und 06:14) im Log erkannt und
aus der Timeline herausgehalten.

## Actions Taken

- `auth.log`, `apt/history.log`, `dpkg.log` (inkl. rotierter Logs) ausgewertet, Timeline rekonstruiert
- Login-Schlüssel per Fingerabdruck verglichen (Log ↔ `authorized_keys` ↔ Schlüssel auf soar-dev-server): identisch
- aktuellen Zustand geprüft: `socat` nicht mehr vorhanden
- gleiches Muster am 01.11. (nmap) gefunden
- Kontoinhaber befragt: Login 05:51 = Test (bestätigt), Login 05:49 = **ungeklärt**
- **keine** Eindämmung (keine Sperre, kein Konto gesperrt), noch keine Eskalation

## Recommendations

1. **Genehmigung prüfen** (Change-Antrag, Kontoinhaber): genehmigt → schließen; nicht genehmigt → an L2 eskalieren.
2. **Login 05:49 klären:** Gab es um 05:49 UTC einen Pipeline-Lauf (GitHub Actions)?
3. **Mensch und Maschine trennen:** persönliche Konten und Schlüssel für Admins, eigener Schlüssel nur für die Pipeline; Soll-Liste der öffentlichen Schlüssel mit Besitzer im Repo, per Ansible verteilt.
4. **Schlüsselablage schützen:** soar-dev-server hält den privaten Schlüssel – Dateirechte prüfen (z. B. `secrets.auto.tfvars` → `600`).
5. **Spuren sichern:** Logs zentral sammeln (geplant: Wazuh), `auditd` für Installationen außerhalb von `apt` (z. B. `curl`).

## Spickzettel: welche Frage → welcher Befehl

| Frage des Analysten | Befehl | Log |
|---|---|---|
| Wer hat sich angemeldet, von wo, mit welchem Schlüssel? | `sudo grep "Accepted" /var/log/auth.log` | `auth.log` |
| Welche `sudo`-Befehle wurden ausgeführt? | `sudo grep "COMMAND=" /var/log/auth.log` | `auth.log` |
| Was wurde mit `apt` gemacht, und wer wollte es (Mensch/Automatik)? | `grep -A3 "Commandline: apt" /var/log/apt/history.log` | `apt/history.log` |
| Welche Pakete kamen neu dazu? | `grep " install " /var/log/dpkg.log` | `dpkg.log` |
| Ist so etwas schon früher passiert? | `zgrep -hE ' (install\|remove\|purge) ' /var/log/dpkg.log* \| sort` | alle `dpkg.log*` |
| Wer war zuletzt eingeloggt? | `last -n 5` | `wtmp` |
| Ist das Tool jetzt da? | `which <tool>` | Live-Zustand |
| Welcher Schlüssel war es? | `ssh-keygen -lf <datei>` | Schlüssel / `authorized_keys` |

**Reihenfolge:** wer (`auth.log`) → was (`apt/history.log`) → welches Paket (`dpkg.log`) → früher schon? (`dpkg.log*`) → beweisen (Fingerabdruck).

**Gelernt:** `USER=root` ist nur die Rechte-Stufe – der Täter steht direkt nach `sudo:`.
Ein `autoremove`, das nichts entfernt, schreibt keinen Block in `apt/history.log`.
