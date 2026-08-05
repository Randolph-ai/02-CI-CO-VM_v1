# 🗄️ Zweite VM: DB-Server (Phase 2C)

Der DB-Server (`db-server-prod`) wird aus demselben gehärteten Golden Image geklont wie der Web-Server, mit eigenen Terraform-Variablen (IP, VM-ID, Ressourcengröße). Ansible installiert PostgreSQL und konfiguriert den Netzwerkzugriff so, dass **ausschließlich** der Web-Server sich verbinden kann.

## Drei unabhängige Sicherheitsebenen

Eine funktionierende Verbindung vom Web-Server zur Datenbank erfordert, dass **alle drei** Ebenen unabhängig voneinander zustimmen:

| Ebene | Datei/Mechanismus | Beantwortet |
|---|---|---|
| **Firewall** | UFW-Regel (`ufw allow 5432/tcp from 10.0.30.101`) | Darf das Paket überhaupt ankommen? |
| **Netzwerk-Lauschen** | `listen_addresses` in `postgresql.conf` | Lauscht PostgreSQL auf der externen Schnittstelle oder nur auf `localhost`? |
| **Zugriffsregel** | `pg_hba.conf` (Host-Based Authentication) | Wer darf sich mit welcher Auth-Methode verbinden? |

Alle drei sind bewusst auf die Web-Server-IP (`10.0.30.101/32`) beschränkt (Defense-in-Depth statt einer einzelnen Kontrollstelle).

## Umgesetzt
- Terraform-Ressource `db_server`, strukturell identisch zu `web_server`
- Ansible-Play „Basis-Setup DB-Server": PostgreSQL-Installation, `listen_addresses`/`pg_hba.conf`-Konfiguration (über `lineinfile` + Handler), UFW-Regeln, Verifikation via `pg_isready`
- Pipeline liest beide VM-IPs aus (`vm_ip`, `db_vm_ip`) und konfiguriert beide VMs in einem Lauf

## Bewusst nicht umgesetzt (Vorgriff auf Phase 5/Vault vermieden)
Kein eigener Datenbank-User, keine eigene Datenbank, keine differenzierten Zugriffsrechte – nur die PostgreSQL-Instanz selbst läuft und ist für den Web-Server erreichbar.

---
[← Zurück zur README](../README.md)
