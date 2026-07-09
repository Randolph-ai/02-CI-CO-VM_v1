# =============================================================================
# Datei:    ProxmoxProviderInsecure.py
# Check-ID: CKV_PROXMOX_2
# Autor:    Randolph Bluming (mit Claude, Session-Datum: 07.07.2026)
# Projekt:  02-CI-CO-VM_v1 – Phase 2A (Security-Gate)
#
# Zweck:
#   Custom Checkov-Check für das Terraform-Framework. Prüft den
#   provider "proxmox"-Block und meldet, wenn insecure = true gesetzt
#   ist (TLS-Zertifikatsprüfung deaktiviert). Im Homelab bewusst so
#   konfiguriert (self-signed Zertifikat), soll aber als sichtbares,
#   dokumentiertes Finding erscheinen statt stillschweigend akzeptiert
#   zu werden.
#
# Status: Aktuell per "checkov:skip"-Kommentar in provider.tf mit
#   Begründung unterdrückt (SKIPPED statt FAILED) - Check selbst läuft
#   weiterhin bei jedem Scan, siehe provider.tf für den Skip-Kommentar.
#
# Wichtiger technischer Hinweis:
#   Basisklasse-Import in Checkov 3.3.6 ist
#   "checkov.terraform.checks.provider.base_check.BaseProviderCheck"
#   (NICHT "base_provider_check", wie ältere Tutorials teils zeigen -
#   dieser Pfad existiert in 3.3.6 nicht mehr).
#
# Ablageort: terraform/checks/provider/ProxmoxProviderInsecure.py
# =============================================================================
from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.provider.base_check import BaseProviderCheck


class ProxmoxProviderInsecure(BaseProviderCheck):
    """
    Eigene Regel fuer 02-CI-CO-VM_v1:
    Meldet, wenn im provider "proxmox"-Block insecure = true gesetzt ist
    (TLS-Zertifikatspruefung deaktiviert). Im Homelab aktuell bewusst so
    gesetzt (self-signed Cert), aber als dokumentiertes Finding im Gate
    sichtbar machen statt stillschweigend zu akzeptieren.
    """

    def __init__(self):
        name = "Ensure Proxmox provider does not disable TLS verification (insecure=true)"
        id = "CKV_PROXMOX_2"
        supported_provider = ["proxmox"]
        categories = [CheckCategories.NETWORKING]
        super().__init__(
            name=name,
            id=id,
            categories=categories,
            supported_provider=supported_provider,
        )

    def scan_provider_conf(self, conf):
        insecure = conf.get("insecure")
        if insecure in (True, [True], "true", ["true"]):
            return CheckResult.FAILED

        return CheckResult.PASSED


check = ProxmoxProviderInsecure()
