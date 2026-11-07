# Incident-Ticket: chisel per curl installiert (ohne apt-Spur)

> [← Zurück zur Timeline](../README.md)

**Übung 003 · Block 1.1 „Admin-Aktion im Server finden“ · ③ allein**
Datum: 07.11.2026 · Analyst: Randolph (L1) · Host: web-server-prod

Diese Übung zeigt die **Lücke** der apt-basierten Erkennung: Wird ein Tool
nicht über `apt`, sondern per `curl` als Datei geholt, schweigen
`apt/history.log` und `dpkg.log`. Nur `auth.log` zeigt eine Spur – und auch
nur, weil `sudo` benutzt wurde.

---

## Ticket

| Feld | Inhalt |
|---|---|
| **Title** | Installation von chisel durch Konto ansible auf web-server-prod (per curl, ohne apt) |
| **Severity** | Medium – chisel ist ein Dual-Use-Tunnel-Tool (legitim für Admins, klassisch für Command & Control), liegt auf einem produktiven Web-Server und wurde an apt vorbei installiert (erschwert Entdeckung). Dagegen: kein Hinweis, dass chisel gestartet wurde → kein belegter Schaden. |
| **Classification** | Suspicious activity – pending verification (verdächtig, aber nicht belegt, ob böswillig oder nicht dokumentierte Admin-Aktion) |
| **MITRE ATT&CK** | T1078 (Valid Accounts) · T1021.004 (Remote Services: SSH) · T1105 (Ingress Tool Transfer – per curl) · T1572 (Protocol Tunneling – chisel) |
| **Affected Host** | web-server-prod, 10.0.30.101 (VLAN 30) |
| **Source IP** | 10.0.10.75 (soar-dev-server, VLAN 10), SSH / pts/0 |
| **Status** | pending |

### Timeline (UTC)

| Zeit (UTC) | Ereignis |
|---|---|
| 04:11:21 | Login ansible von 10.0.10.75 – geprüft: kein Pipeline-Lauf um diese Zeit → eigener Zugriff (bestätigt) |
| 04:12:15 | Login ansible (vorige Sitzung, „Last login“) |
| 04:22:10 | Login ansible – Täter-Sitzung (passt zu `date` 04:22:14) |
| 04:31:55 | `sudo install -m 755 /tmp/chisel /usr/local/bin/chisel` |

### Summary

Am 07.11.2026 meldete sich das Konto **ansible** per SSH von **10.0.10.75** auf
dem produktiven Web-Server **web-server-prod (10.0.30.101)** an. Um
**04:31:55 UTC** installierte es mit `sudo` (root-Rechten) das Tunnel-Tool
**chisel** nach `/usr/local/bin/`. Das Programm wurde zuvor per **curl** aus dem
Internet geholt und **an apt vorbei** installiert – deshalb findet sich **keine
Spur** in `apt/history.log` oder `dpkg.log`, nur in `auth.log`. chisel hat auf
einem Web-Server keine legitime Funktion und wird typischerweise für **Command &
Control** genutzt; eine Genehmigung ist nicht belegt.

### Evidence

| # | Befund | Beleg (Befehl → Ergebnis) |
|---|---|---|
| 1 | Tool ist vorhanden | `which chisel` → `/usr/local/bin/chisel` · `chisel --version` → `1.11.5` |
| 2 | Wer / wann / wie | `sudo grep "COMMAND=" /var/log/auth.log` → `install … /usr/local/bin/chisel` um 04:31:55, Konto `ansible`, `USER=root`, `TTY=pts/0` |
| 3 | Keine apt-Spur | `grep chisel /var/log/apt/history.log` → **leer** |
| 4 | Keine dpkg-Spur | `grep chisel /var/log/dpkg.log` → **leer** |
| 5 | Logins der Quelle | `sudo grep "Accepted" /var/log/auth.log` → ansible von 10.0.10.75 um 04:11 / 04:12 / 04:22, Schlüssel `SHA256:dFEt…cYM` |

### Actions Taken

- `auth.log` ausgewertet (`COMMAND=` und `Accepted`): Tat um 04:31:55 UTC, drei Logins der Quelle rekonstruiert.
- `apt/history.log` und `dpkg.log` geprüft → keine Spur (bestätigt: Installation an apt vorbei).
- Live-Zustand geprüft (`which chisel` → vorhanden).
- Login 04:11 UTC über `gh run list` geprüft (kein Pipeline-Lauf → eigener Zugriff).
- Ticket erstellt, Classification auf *pending verification* gesetzt (offen bleibt die Genehmigungsfrage, nicht der Login).
- **Keine Eindämmung** durchgeführt (chisel bleibt installiert, Quelle nicht gesperrt) – L1 dokumentiert, Eindämmung erst nach Klärung (L2).

### Recommendations

1. Mit dem Zuständigen klären, ob die Installation geplant/genehmigt war (Change-Ticket vorhanden?) – erst danach über das Entfernen entscheiden.
2. Klären, warum per curl (an apt vorbei) installiert wurde – legitimer Grund oder Verschleierung?
3. Login 04:11 UTC: geprüft über `gh run list` – jüngster Pipeline-Lauf war 21 Tage alt, also kein Lauf um diese Zeit → eigener Zugriff (bestätigt), nicht die Pipeline.
4. **auditd / Wazuh einführen:** Diese Übung zeigt, dass eine curl-Installation nur in `auth.log` sichtbar ist (und auch nur wegen `sudo`). Host-Logging würde solche Vorgänge zuverlässig erfassen.
5. Gemeinsamen Zugang auftrennen: Mensch und Pipeline teilen Konto `ansible`, Schlüssel und Quell-IP → Täter nicht eindeutig zuordenbar. Persönliche Konten/Schlüssel einführen.

---

## Lernpunkt dieser Übung

**curl holt das Tool an apt vorbei** → `apt/history.log` und `dpkg.log` bleiben
leer. Übrig bleibt nur `auth.log`, und das auch nur, weil `sudo` benutzt wurde.
Hätte der Angreifer chisel nach `/home/ansible/` (ohne `sudo`) gelegt, gäbe es
auch diese Spur nicht. **Darum braucht man host-basiertes Logging (auditd /
Wazuh)** – es sieht, was apt nicht protokolliert.

> [← Zurück zur Timeline](../README.md)
