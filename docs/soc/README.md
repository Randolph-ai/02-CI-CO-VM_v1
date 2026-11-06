# Cyber Range – Timeline der Übungen

> [← Zurück zur README](../../README.md#-cyber-range)

**Cyber Range – das Übungsgelände für Angriff und Abwehr.** Hier steht jede
Übung in der eigenen Cyber Range, nummeriert und in zeitlicher Reihenfolge.
Jede Übung wird aus Sicht eines SOC-Analysten (L1) ausgewertet und als
Incident-Ticket dokumentiert – mit MITRE-ATT&CK-Zuordnung.

**Lernweg:** Jeder Themenblock wird mindestens **dreimal** geübt –
① vorgezeigt · ② selbst geführt mit Hilfe · ③ allein – erst danach gilt er
als sicher beherrscht.

## Timeline

| Nr | Datum | Block | Was geübt | Bericht | Status |
|---|---|---|---|---|---|
| 001 | 01.11.2026 | Admin-Aktion im Server finden · ① vorgezeigt | Admin installiert `nmap` auf web-server-prod und entfernt es wieder; Spuren in drei Logs gefunden | [Bericht](berichte/2026-11-01_admin-installiert-tool.md) | ✅ |
| 002 | 06.11.2026 | Admin-Aktion im Server finden · ② selbst geführt | Gleiche Übung mit `socat`; Untersuchung selbst geführt, Ticket mit ATT&CK-Zeile | [Bericht](berichte/2026-11-06_admin-installiert-tool-socat.md) | ✅ |

**Legende:** ✅ abgeschlossen · 🔄 läuft · 🔁 wird wiederholt

## Regeln der Cyber Range

- Angriffe nur gegen **eigene VMs** im eigenen Netz.
- Keine Mitschnitte (`.pcap`), Passwörter oder Schlüssel im Repo; Log-Auszüge nur kurz.
