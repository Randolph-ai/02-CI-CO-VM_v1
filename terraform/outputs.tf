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


# ============================================================
# OUTPUT: DB_SERVER_IP
# ============================================================
# ZWECK:   Gibt die IPv4-Adresse des DB-Servers zurück.
#          Diese wird z.B. für Ansible-Inventare oder andere
#          Module benötigt, die auf die Datenbank zugreifen.
#
# DATENQUELLE: proxmox_virtual_environment_vm.db_server
#   → Die Ressource liefert eine Liste aller IPv4-Adressen
#     des QEMU-Guest-Agents.
#
# STRUKTUR DER IP-LISTE:
#   ipv4_addresses = [
#     ["127.0.0.1"],          # [0] = Loopback (localhost)
#     ["10.0.30.10"],         # [1] = Die eigentliche Netzwerk-IP
#   ]
#
# ZUGRIFF:
#   ipv4_addresses[1]   → greift auf die NETZWERK-IP zu (nicht Loopback)
#   ipv4_addresses[1][0] → nimmt den ersten (einzigen) Eintrag aus der
#                           Sub-Liste (bei mehreren IPs pro Interface)
#
# TRY-FUNKTION:
#   try(AUSDRUCK, FALLBACK)
#     → Versucht den ersten Ausdruck, gibt bei Fehler den Fallback zurück.
#     → Verhindert einen Terraform-Fehler, wenn der Guest-Agent noch
#        nicht gestartet hat und die IP noch nicht verfügbar ist.
#
# FALLBACK-NACHRICHT:
#   "IP noch nicht verfügbar - qemu-guest-agent startet noch"
#     → Wird ausgegeben, wenn die IP nicht ausgelesen werden kann.
#     → Tritt meistens direkt nach dem ersten `apply` auf, da der
#        Guest-Agent in der VM erst starten muss.
#
# NUTZEN:
#   Du kannst diesen Output in anderen Modulen oder Skripten verwenden,
#   z.B. um den DB-Server in ein Ansible-Inventory einzutragen:
#     ansible_host = module.db_server.db_server_ip
# ============================================================
output "db_server_ip" {
  value = try(
    proxmox_virtual_environment_vm.db_server.ipv4_addresses[1][0],
    "IP noch nicht verfügbar - qemu-guest-agent startet noch"
  )
  description = "IP-Adresse des DB-Servers"
}

# ============================================================
# OUTPUT: DB_SERVER_NAME
# ============================================================
# ZWECK:   Gibt den Proxmox-Hostnamen des DB-Servers zurück.
#          Dies entspricht dem `name`-Attribut in der Ressource.
#
# DATENQUELLE: proxmox_virtual_environment_vm.db_server.name
#   → Direkter Zugriff auf das Namensattribut der VM.
#
# VERWENDUNG:
#   - Zur Identifikation in Logs oder Monitoring
#   - Als Hostname für Ansible (wenn dieser mit dem System-Hostname
#     übereinstimmt – hier: "db-server-prod")
#   - Zur Anzeige in der Proxmox-UI
#
# HINWEIS:
#   Dieser Name kann sich von der internen Hostname-Konfiguration
#   der VM unterscheiden, wenn Cloud-Init den Hostname überschreibt.
#   In diesem Setup ist beides konsistent ("db-server-prod").
# ============================================================
output "db_server_name" {
  value       = proxmox_virtual_environment_vm.db_server.name
  description = "Name des DB-Servers in Proxmox"
}

# ============================================================
# OUTPUT: DB_SERVER_VM_ID
# ============================================================
# ZWECK:   Gibt die eindeutige VM-ID des DB-Servers im Proxmox-Cluster zurück.
#          Diese ID wird von Proxmox intern zur Identifikation verwendet.
#
# DATENQUELLE: proxmox_virtual_environment_vm.db_server.vm_id
#   → Direkter Zugriff auf die `vm_id` der Ressource.
#
# VERWENDUNG:
#   - Für Skripte, die direkt auf die Proxmox-API zugreifen
#     (z.B. für Snapshots, Backups oder Migrationen)
#   - Zur Kollisionsvermeidung, wenn manuell mit VMs gearbeitet wird
#   - Als Referenz in anderen Terraform-Modulen
#
# WICHTIG:
#   Diese ID MUSS im gesamten Proxmox-Cluster eindeutig sein.
#   Sie wird über die Variable `var.db_server_vm_id` gesteuert
#   (z.B. aus terraform.tfvars).
# ============================================================
output "db_server_vm_id" {
  value       = proxmox_virtual_environment_vm.db_server.vm_id
  description = "VM-ID des DB-Servers in Proxmox"
}


# ============================================================
# OUTPUT: TEST_VM_IP
# ZWECK: IP-Adresse der Wegwerf-Test-VM, für die SSH-Warteschleife
#        und den Ansible-Testlauf in Phase 2B.2 benötigt.
# ============================================================
output "test_vm_ip" {
  value = try(
    proxmox_virtual_environment_vm.test_vm.ipv4_addresses[1][0],
    "IP noch nicht verfügbar - qemu-guest-agent startet noch"
  )
  description = "IP-Adresse der Wegwerf-Test-VM (Phase 2B.2)"
}