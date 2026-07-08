#from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck
#from checkov.common.models.enums import CheckCategories, CheckResult
#
#class ProxmoxDiskMemorySet(BaseResourceCheck):
#    def __init__(self):
#        name = "Ensure Proxmox VM has explicit memory and disk size defined"
#        id = "CKV_PROXMOX_4"
#        supported_resources = ["proxmox_virtual_environment_vm"]
#        categories = [CheckCategories.GENERAL_SECURITY]
#        super().__init__(name=name, id=id, categories=categories, supported_resources=supported_resources)
#
#    def scan_resource_conf(self, conf):
#        # Memory Block + dedicated prüfen
#        if "memory" not in conf:
#            return CheckResult.FAILED
#        memory_block = conf["memory"][0]
#        if "dedicated" not in memory_block:
#            return CheckResult.FAILED
#            
#        # Disk Block + size prüfen 
#        if "disk" not in conf:
#            return CheckResult.FAILED
#        disk_block = conf["disk"][0]
#        if "size" not in disk_block:
#            return CheckResult.FAILED
#            
#        return CheckResult.PASSED
#
#check = ProxmoxDiskMemorySet()

#==================================================================
# 2026-07-08 -- code s.o. wurde mit Meta und Claude ff. modifiziert
#==================================================================
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