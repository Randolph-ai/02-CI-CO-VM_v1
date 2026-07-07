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
