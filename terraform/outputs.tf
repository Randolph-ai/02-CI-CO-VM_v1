# ============================================================
# TERRAFORM OUTPUTS - WEB-SERVER
# ============================================================
# ZWECK 1: Anzeige nach "terraform apply"
# ZWECK 2: IP-Weitergabe an Ansible in der Pipeline
#
# PIPELINE-NUTZUNG:
#   WEB_IP=$(terraform output -raw vm_ip)
#   ansible-playbook -i "$WEB_IP," playbook.yml
# ============================================================

output "vm_ip" {
  value = try(
    proxmox_virtual_environment_vm.web_server.ipv4_addresses[1][0],
    "IP noch nicht verfügbar - qemu-guest-agent startet noch"
  )
  description = "IP-Adresse des Web-Servers"
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.web_server.name
  description = "Name des Web-Servers in Proxmox"
}

output "vm_id" {
  value       = proxmox_virtual_environment_vm.web_server.vm_id
  description = "VM-ID des Web-Servers in Proxmox"
}