#!/bin/bash
# ============================================================
# setup-base-image.sh
# ============================================================
# ZWECK:   Baut die Basis-VM 9000 (ubuntu-2204-cloudinit-base) auf,
#          aus der Packer (proxmox-clone) das Golden Image
#          Template 2000 klont.
#
# WICHTIG: Dieses Skript ist NICHT Teil der GitHub-Actions-Pipeline!
#          Es läuft einmalig, manuell, direkt auf dem Proxmox-Host.
#          Ausführung: ssh root@10.0.30.22, dann dieses Skript starten.
#
# WANN AUSFÜHREN:
#   - Beim erstmaligen Aufbau der Infrastruktur (einmalig)
#   - Falls der Proxmox-Host neu aufgesetzt werden muss
#   - Falls VM 9000 versehentlich gelöscht wurde
#
# VORAUSSETZUNG: Muss auf dem Proxmox-Host selbst laufen (nicht auf
#                soar-dev-server!), da qm-Befehle nur dort existieren.
# 
# AUTOR:       Randolph Bluming
# Erstellt am:     2026-07-04
# Letzte Änderung: 2026-07-04
# ============================================================

set -e
# set -e: Skript bricht sofort ab, wenn ein Befehl fehlschlägt.
#         Verhindert, dass bei einem Fehler mitten im Ablauf
#         eine halb-fertige, kaputte VM 9000 zurückbleibt.

VM_ID=9000
VM_NAME="ubuntu-2204-cloudinit-base"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
IMAGE_PATH="/var/lib/vz/template/iso/jammy.img"
STORAGE="local-lvm"
# ---- KONFIGURATION ----
#    │
#    └── Zentrale Variablen statt Hardcode im Skript.
#        Bei Änderungen (z.B. andere Ubuntu-Version) nur hier anpassen.

# ---- SICHERHEITSCHECK: EXISTIERT VM 9000 SCHON? ----
#    │
#    └── Verhindert versehentliches Überschreiben einer laufenden
#        Basis-VM, an der andere VMs/Templates bereits hängen.
if qm status "$VM_ID" &>/dev/null; then
  echo "FEHLER: VM $VM_ID existiert bereits."
  echo "Falls ein Neuaufbau gewollt ist, zuerst manuell entfernen:"
  echo "  qm destroy $VM_ID"
  exit 1
fi

# ---- SCHRITT 1: CLOUD-IMAGE HERUNTERLADEN ----
#    │
#    └── Nur herunterladen, falls noch nicht vorhanden
#        (spart Zeit bei wiederholten Testläufen dieses Skripts)
if [ ! -f "$IMAGE_PATH" ]; then
  echo "==> Lade Ubuntu 22.04 Cloud-Image herunter..."
  wget -O "$IMAGE_PATH" "$IMAGE_URL"
else
  echo "==> Cloud-Image bereits vorhanden, Download übersprungen."
fi

# ---- SCHRITT 2: LEERE BASIS-VM ANLEGEN ----
#    │
#    └── net0 mit VLAN-Tag 30, passend zur Prod-Umgebung
echo "==> Erstelle leere Basis-VM $VM_ID..."
qm create "$VM_ID" \
  --name "$VM_NAME" \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0,tag=30

# ---- SCHRITT 3: CLOUD-IMAGE ALS DISK IMPORTIEREN ----
#    │
#    └── WICHTIG: local-lvm, NICHT local!
#        local-lvm hat den benötigten Speicherplatz,
#        local ist für diesen Zweck zu klein dimensioniert.
echo "==> Importiere Cloud-Image als Disk..."
qm importdisk "$VM_ID" "$IMAGE_PATH" "$STORAGE"

# ---- SCHRITT 4: IMPORTIERTE DISK EINHÄNGEN ----
echo "==> Hänge importierte Disk als scsi0 ein..."
qm set "$VM_ID" --scsihw virtio-scsi-pci --scsi0 "$STORAGE:vm-$VM_ID-disk-0"

# ---- SCHRITT 5: DISK VERGRÖSSERN (Fix vom 04.07.) ----
#    │
#    └── WARUM DIESER SCHRITT NÖTIG IST:
#        Die importierte Cloud-Image-Disk ist bewusst winzig (~2,2 GB).
#        Das reicht nicht für "apt-get upgrade" während des späteren
#        Packer-Builds (siehe Fehler vom 04.07.: "No space left on
#        device"). Ein Versuch, dies stattdessen über einen separaten
#        "disks"-Block direkt in Packer zu lösen, ist gescheitert:
#        Packer legte dabei eine ZWEITE, leere Disk an statt die
#        bestehende zu vergrößern, wodurch die VM nicht mehr bootete.
#
#        LÖSUNG: Die Basis-VM 9000 selbst hier, einmalig, vergrößern.
#        Jeder künftige Klon (Template 2000, spätere Terraform-VMs)
#        bringt dadurch automatisch genug Platz mit. Cloud-Init
#        vergrößert dann bei jedem ersten Boot automatisch die
#        Partition/das Dateisystem passend zur Disk-Größe (growpart).
#
#    └── Zielgröße: ~20 GB (2,2 GB Basis + 18 GB Zuwachs)
echo "==> Vergrößere Basis-Disk um 18G (auf ca. 20G gesamt)..."
qm resize "$VM_ID" scsi0 +18G

# ---- SCHRITT 6: CLOUD-INIT-DRIVE HINZUFÜGEN ----
#    │
#    └── Leer - wird von Packer/Terraform später individuell befüllt
echo "==> Füge Cloud-Init-Drive hinzu..."
qm set "$VM_ID" --ide2 "$STORAGE:cloudinit"
qm set "$VM_ID" --boot c --bootdisk scsi0
qm set "$VM_ID" --serial0 socket --vga serial0

# ---- SCHRITT 7: GUEST-AGENT-FLAG SETZEN ----
#    │
#    └── Vererbt sich auf jeden Klon (Template 2000, Terraform-VMs)
#        Muss trotzdem in jedem Image separat installiert werden -
#        dieses Flag sorgt nur dafür, dass Proxmox danach fragt.
echo "==> Aktiviere Guest-Agent-Flag..."
qm set "$VM_ID" --agent enabled=1

# ---- SCHRITT 8: DHCP EXPLIZIT SETZEN ----
#    │
#    └── Klarheit im Config-File, auch wenn ohnehin Standard
echo "==> Setze DHCP als Standard-Netzwerkkonfiguration..."
qm set "$VM_ID" --ipconfig0 ip=dhcp

# ---- SCHRITT 9: IN TEMPLATE UMWANDELN ----
#    │
#    └── Ab jetzt read-only, kann nur noch geklont werden
echo "==> Wandle VM $VM_ID in Template um..."
qm template "$VM_ID"

echo ""
echo "==> Fertig! VM $VM_ID ($VM_NAME) ist als Template einsatzbereit."
echo "    Packer (proxmox-clone) kann jetzt daraus Template 2000 bauen."
