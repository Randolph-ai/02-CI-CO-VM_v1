from checkov.common.models.enums import CheckResult, CheckCategories
from checkov.terraform.checks.resource.base_resource_check import BaseResourceCheck


class ProxmoxAgentEnabled(BaseResourceCheck):
    """
    Eigene Regel fuer 02-CI-CO-VM_v1:
    Der QEMU-Guest-Agent MUSS fuer jede proxmox_virtual_environment_vm
    aktiviert sein (agent { enabled = true }), da Terraform sonst die
    VM-IP nicht auslesen kann und pipeline.yml (Job deploy-vm) auf
    genau diesen Output angewiesen ist.
    """

    def __init__(self):
        name = "Ensure QEMU Guest Agent is enabled on Proxmox VMs"
        id = "CKV_PROXMOX_1"
        supported_resources = ["proxmox_virtual_environment_vm"]
        categories = [CheckCategories.GENERAL_SECURITY]
        super().__init__(
            name=name,
            id=id,
            categories=categories,
            supported_resources=supported_resources,
        )

    def scan_resource_conf(self, conf):
        agent = conf.get("agent")
        if not agent:
            return CheckResult.FAILED

        agent_block = agent[0]
        # In Checkov-HCL2-Parsing kommen Werte meist als Liste an: [True]
        enabled = agent_block.get("enabled")
        if enabled in (True, [True], "true", ["true"]):
            return CheckResult.PASSED

        return CheckResult.FAILED


check = ProxmoxAgentEnabled()
