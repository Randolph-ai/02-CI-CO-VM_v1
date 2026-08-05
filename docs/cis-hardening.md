# 🛡️ CIS-Härtung des Golden Images (Phase 2B)

Das Packer-Template wird vor der Auslieferung nach CIS-Benchmark-Prinzipien gehärtet – Security als integraler Bestandteil des Image-Builds, nicht als nachträglicher Schritt:

| Maßnahme | Umsetzung |
|---|---|
| SSH-Passwort-Login | Global gesperrt (`PasswordAuthentication no`), ausschließlich Key-Auth über die gesamte Kette |
| Firewall-Baseline | UFW aktiv, Default-Deny eingehend, Ports 22/80/443 im Template erlaubt |
| Security-Updates | `unattended-upgrades`, ausschließlich Security-Only-Kanal (keine regulären Feature-Updates) |
| Unnötige Dienste | Neun Dienste deaktiviert (VMware/LXD-Gast-Tools, iSCSI/Multipath, Ubuntu-Advantage, Pollinate) |
| Build-User-Cleanup | Temporärer Packer-Build-User wird als letzter Schritt im Provisioner entfernt (`userdel`) |

Jede Maßnahme ist über einen vollständigen Packer-Build plus Verifikation gegen eine Wegwerf-VM (`qm guest exec`) bestätigt, bevor sie als abgeschlossen gilt.

> **Hinweis:** Die im Template global erlaubten Ports 80/443 gelten für **jede** aus diesem Image geklonte VM, unabhängig von deren späterer Rolle. Für den DB-Server ist das aktuell unnötig offen – siehe [Bekannte technische Schuld](../README.md#-bekannte-technische-schuld-offen) in der README.

---
[← Zurück zur README](../README.md)
