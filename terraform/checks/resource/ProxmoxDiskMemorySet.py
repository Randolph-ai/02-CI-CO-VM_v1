# =============================================================================
# Datei:    ProxmoxDiskMemorySet.py
# Check-ID: CKV_PROXMOX_3
# Autor:    Randolph Bluming (mit Claude, Session-Datum: 08.07.2026)
# Projekt:  02-CI-CO-VM_v1 – Phase 2A (Security-Gate)
#
# Zweck:
#   Custom Checkov-Check für das Terraform-Framework. Prüft alle
#   proxmox_virtual_environment_vm-Resources auf Mindestgrößen:
#   memory.dedicated >= 2048 MB und disk.size >= 40 GB. Generisch
#   gehalten, greift automatisch auch für künftige VMs (z.B. db-server
#   in Phase 2C), ohne Codeänderung.
#
# Design-Entscheidung:
#   Bewusst Mindestgrenzen statt reiner Existenz- oder
#   Positivwert-Prüfung (> 0). Eine reine ">0"-Prüfung hätte auch
#   unsinnig kleine Werte (z.B. 1 GB Disk) durchgelassen - siehe
#   Diskussion vom 08.07.2026.
#
# Nummerierung:
#   Ursprünglich als vierter Check konzipiert (ein früherer,
#   verworfener Zwischenentwurf sollte CKV_PROXMOX_3 werden), auf
#   fortlaufende Nummerierung 1/2/3 korrigiert, bevor er ins Repo kam.
#
# Ablageort: terraform/checks/resource/ProxmoxDiskMemorySet.py
# =============================================================================

from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
from checkov.common.models.enums import CheckCategories, CheckResult


class ProxmoxDiskMemorySet(BaseResourceCheck):
    def __init__(self):
        name = "Ensure Proxmox VM has minimum memory and disk size defined"
        id = "CKV_PROXMOX_3"
        supported_resources = ["proxmox_virtual_environment_vm"]
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)

    # Mindestwerte, zentral an einer Stelle definiert
    MIN_DISK_SIZE_GB = 40
    MIN_MEMORY_MB = 2048

    def scan_resource_conf(self, conf):
        # --- Memory prüfen ---
        memory = conf.get("memory")
        if not memory:
            return CheckResult.FAILED

        memory_block = memory[0]
        dedicated = memory_block.get("dedicated")
        if not dedicated:
            return CheckResult.FAILED

        dedicated_value = dedicated[0]
        try:
            if int(dedicated_value) < self.MIN_MEMORY_MB:
                return CheckResult.FAILED
        except (ValueError, TypeError):
            return CheckResult.FAILED



        # --- Disk prüfen ---
        disk = conf.get("disk")
        if not disk:
            return CheckResult.FAILED

        disk_block = disk[0]
        size = disk_block.get("size")
        if not size:
            return CheckResult.FAILED

        size_value = size[0]
        try:
            if int(size_value) < self.MIN_DISK_SIZE_GB:
                return CheckResult.FAILED
        except (ValueError, TypeError):
            return CheckResult.FAILED

        return CheckResult.PASSED


check = ProxmoxDiskMemorySet()