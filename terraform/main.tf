# ============================================================
# PROXMOX VIRTUAL ENVIRONMENT - VM KONFIGURATION
# ============================================================
# ZWECK:   Erstellt EINE VM auf Proxmox für den Web-Server
#
# AUTOR:       Randolph Bluming
# Erstellt am:     2026-06-27
# Letzte Änderung: 2026-08-28
# ============================================================

# ============================================================
# PROXMOX VM RESSOURCE - WEB-SERVER
# ============================================================
# ZWECK:   Definiert die komplette VM-Konfiguration
#
# WICHTIG: Die VM wird aus einem Packer-Template geklont
#          Das Template muss VOR dem Terraform-Run existieren!
#          (siehe Packer-Build → template-vm)
#
# VERSION: 2.0.0 (Update: 2026-06-29)
# ÄNDERUNGEN:
#   - IP und Gateway als Variablen (kein Hardcode mehr)
#   - timeout_clone hinzugefügt (verhindert Timeout bei 40GB)
# ============================================================

resource "proxmox_virtual_environment_vm" "web_server" {
  # ---- GRUNDEINSTELLUNGEN ----
  # Name, Beschreibung und Tags für die VM
  #    │
  #    └── "web-server-prod" = Hostname der VM
  #        Tags helfen bei der Organisation in Proxmox

  name        = "web-server-prod"
  description = "Web-Server (Nginx) - Managed by Terraform"
  tags        = ["web", "prod"]

  # ---- PROXMOX NODE ----
  # Auf welchem Proxmox-Host wird die VM erstellt?
  node_name = var.target_node
  #    │
  #    └── Wert aus terraform.tfvars
  #        z.B. target_node = "proxmox-host-01"

  # ---- AUTOSTART-VERHALTEN ----
  # Steuert, ob die VM beim Booten des Proxmox-Hosts automatisch startet
  #    │
  #    └── on_boot = var.web_server_on_boot (true/false aus Variable)
  #        → true: VM startet automatisch beim Host-Boot
  #        → false: VM muss manuell gestartet werden, beim Hochfahren des Proxmox-Hosts wird die VM nicht automatisch gestartet 
  on_boot = var.web_server_on_boot

  # ==========================================
  #  START-STEUERUNG
  # ==========================================
  # Steuert, ob die VM nach dem Erstellen automatisch gestartet wird
  #    │
  #    └── started = var.web_server_started (true/false aus Variable)
  #        → true: VM läuft nach dem Erstellen sofort
  #        → false: VM wird erstellt, bleibt aber ausgeschaltet
  #        → MUSS true sein: Der QEMU-Guest-Agent (agent.enabled)
  #          kann nur antworten, wenn die VM tatsächlich läuft.
  #          Ohne laufende VM keine IP-Ausgabe, kein SSH-Zugriff
  #          für Ansible in der Pipeline.
  
  started = var.web_server_started

  # ---- VM-ID ----
  # Eindeutige ID in Proxmox (muss im Cluster einzigartig sein)
  vm_id = var.web_server_vm_id
  #    │
  #    └── Wert aus terraform.tfvars
  #        z.B. web_server_vm_id = 101

  # ---- QEMU GUEST AGENT ----
  # Ermöglicht Kommunikation zwischen Host und Gast
  #    │
  #    └── PFICHT für IP-Output!
  #        Ohne Agent kann Terraform die IP nicht auslesen

  agent {
    enabled = true
  }

  # ---- TIMEOUT CLONE ----
  # Zeitlimit für das Klonen des Templates
  #    │
  #    └── 600 Sekunden = 10 Minuten
  #        Bei 40GB Template kann das Klonen länger dauern
  #        Verhindert Timeout-Fehler in der Pipeline

  timeout_clone = 600

  # ---- TEMPLATE KLONEN ----
  # Welches Template wird als Basis verwendet?
  #    │
  #    └── Das Packer-Template wird hier referenziert
  #        VM-ID aus terraform.tfvars (z.B. 9000)

  clone {
    vm_id = var.template_vm_id # Eingang von welchem Template die VM geklont wird
  }

  # ---- CPU ----
  # Prozessor-Konfiguration für die VM
  #    │
  #    └── "host" = CPU-Typ des Hosts wird durchgereicht
  #        Beste Performance, aber weniger Migration möglich

  cpu {
    cores = var.web_server_cores
    type  = "host"
  }

  # ---- RAM ----
  # Arbeitsspeicher-Konfiguration
  #    │
  #    └── dedicated = exklusiv reservierter RAM
  #        Kein Ballooning (Shared Memory)

  memory {
    dedicated = var.web_server_memory
  }

  # ---- NETZWERK ----
  # Netzwerk-Interface der VM
  #    │
  #    └── bridge = virtueller Switch in Proxmox
  #        vlan_id = VLAN für Netzwerktrennung

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan_id
  }

  # ---- FESTPLATTE ----
  # Speicher-Konfiguration
  #    │
  #    └── MUSS mit Packer übereinstimmen: 40GB
  #        interface "scsi0" = SCSI-Controller
  #        datastore = Speicherort auf Proxmox

  disk {
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.web_server_disk_size
  }

  # ---- CLOUD-INIT ----
  # Automatische Konfiguration beim ersten Start
  #    │
  #    └── Wird NUR beim ersten Boot ausgeführt
  #        Danach ist die VM fertig konfiguriert
  #        Änderungen hier benötigen einen Rebuild!

  initialization {
    # ---- DNS ----
    # Nameserver für die VM
    #    │
    #    └── Google DNS als Fallback
    #        Kann durch firmeninterne DNS ersetzt werden

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    # ---- IP-KONFIGURATION ----
    # Statische IP-Adresse für den Web-Server
    #    │
    #    └── WICHTIG: Muss im gleichen Subnetz wie Gateway liegen
    #        IP aus terraform.tfvars (10.0.30.101/24)
    #        Gateway aus terraform.tfvars (10.0.30.1)

    ip_config {
      ipv4 {
        address = var.web_server_ip
        gateway = var.network_gateway
      }
    }

    # ---- BENUTZERKONTO ----
    # Erstellt einen Benutzer "ansible" mit SSH-Key
    #    │
    #    └── SSH-Key aus terraform.tfvars
    user_account {
      username = "ansible"
      keys     = [trimspace(var.ssh_public_key)]
    }

  }

  # ---- LIFECYCLE: clone-Block nach Import ignorieren ----
  # Proxmox speichert nicht dauerhaft, aus welchem Template eine VM
  # geklont wurde. Nach terraform import ist dieser Wert im State leer,
  # wodurch Terraform sonst bei jedem plan eine komplette
  # Neuerstellung vorschlägt (destroy + create). ignore_changes
  # unterdrückt das gezielt für dieses eine, unproblematische Feld.
  lifecycle {
    ignore_changes = [clone]
  }
}

# ============================================================
# PROXMOX VM RESSOURCE - DATENBANK -SERVER
# Erstellt am : 2026-08-02
# Letzter Edit: 2026-08-11
# ============================================================
# ZWECK:   Definiert eine Proxmox-VM für den Datenbank-Server (PostgreSQL)
#          Die VM wird aus einem Template geklont und per Cloud-Init initialisiert.
#          Alle Hardware-Parameter (CPU, RAM, Festplatte) sowie Netzwerk und
#          Benutzerzugang werden über Terraform-Variablen gesteuert.
#
# WICHTIG: - Das Template (var.template_vm_id) MUSS vor dem ersten `apply` existieren.
#          - Die VM-ID (var.db_server_vm_id) muss im gesamten Proxmox-Cluster
#            eindeutig sein – andernfalls schlägt das Erstellen fehl.
#          - Der QEMU-Guest-Agent ist zwingend aktiviert, damit Terraform
#            die IP-Adresse auslesen kann.
#          - Die IP-Adresse (var.db_server_ip) wird statisch vergeben und
#            muss zum definierten Subnetz passen.
# ============================================================

resource "proxmox_virtual_environment_vm" "db_server" {
  
  # ==========================================
  #  GRUNDEINSTELLUNGEN
  # ==========================================
  # Name, Beschreibung und Tags für die VM
  #    │
  #    └── name        = Hostname in Proxmox (muss eindeutig sein)
  #        description = Kurzbeschreibung für Admins
  #        tags        = Liste zur Kategorisierung (z.B. für Filter)

  name        = "db-server-prod"
  description = "DB-Server (PostgreSQL) - Managed by Terraform"
  tags        = ["db", "prod"]

  # ==========================================
  #  PROXMOX NODE
  # ==========================================
  # Auf welchem Proxmox-Node die VM laufen soll
  #    │
  #    └── node_name = Variable (z.B. "proxmox1")
  #        → Kann je nach Umgebung (prod/staging) unterschiedlich sein

  node_name = var.target_node

  # ==========================================
  #  VM-ID
  # ==========================================
  # Eindeutige ID im gesamten Proxmox-Cluster
  #    │
  #    └── vm_id = Zahl (z.B. 101)
  #        → Wird als Variable übergeben, um Kollisionen zu vermeiden

  vm_id = var.db_server_vm_id

  # ==========================================
  #  AUTOSTART-VERHALTEN
  # ==========================================
  # Steuert, ob die VM beim Booten des Proxmox-Hosts automatisch startet
  #    │
  #    └── on_boot = var.db_server_on_boot (true/false aus Variable)
  #        → true: VM startet automatisch beim Host-Boot
  #        → false: VM muss manuell gestartet werden
  #        → hier auf false, da beim Hochfahren des Proxmox-Hosts die DB-VM nicht sofort benötigt wird

  on_boot = var.db_server_on_boot

  # ==========================================
  #  START-STEUERUNG
  # ==========================================
  # Steuert, ob die VM nach dem Erstellen automatisch gestartet wird
  #    │
  #    └── started = var.db_server_started (true/false aus Variable)
  #        → true: VM läuft nach dem Erstellen sofort
  #        → false: VM wird erstellt, bleibt aber ausgeschaltet
  #        → MUSS true sein: Der QEMU-Guest-Agent (agent.enabled)
  #          kann nur antworten, wenn die VM tatsächlich läuft.
  #          Ohne laufende VM keine IP-Ausgabe, kein SSH-Zugriff
  #          für Ansible in der Pipeline.

  started = var.db_server_started
  
  # ==========================================
  #  QEMU GUEST AGENT
  # ==========================================
  # Aktiviert den QEMU-Gast-Agent (PFICHT für IP-Abfrage und ordentliches Herunterfahren)
  #    │
  #    └── enabled = true
  #        → Ermöglicht Terraform, die IP-Adresse der VM auszulesen
  #        → Verbessert das Shutdown-Verhalten
  
  agent {
    enabled = true
  }

  # ==========================================
  #  TIMEOUT CLONE
  # ==========================================
  # Maximale Wartezeit beim Klonen der Vorlage (in Sekunden)
  #    │
  #    └── timeout_clone = 600 (10 Minuten)
  #        → Bei großen Vorlagen oder langsamen Storage nötig
  #        → Verhindert Timeout-Fehler bei Terraform

  timeout_clone = 600

  # ==========================================
  #  TEMPLATE KLONEN
  # ==========================================
  # Welche Vorlage (Template) als Basis verwendet wird
  #    │
  #    └── clone { vm_id = var.template_vm_id }
  #        → Die Quell-VM muss ein Template sein (oder eine VM)
  #        → Terraform erstellt einen vollständigen Klon (full clone)
  #        → Die VM-ID des Templates wird als Variable übergeben

  clone {
    vm_id = var.template_vm_id
  }

  # ==========================================
  #  CPU
  # ==========================================
  # CPU-Konfiguration
  #    │
  #    └── cores = Anzahl der CPU-Kerne (aus Variable)
  #        type  = "host" (beste Performance, gibt Host-CPU an Gast weiter)
  #        → "host" ist empfehlenswert für maximale Kompatibilität
  #        → Kann bei Migration zu Problemen führen (dann "kvm64" verwenden)

  cpu {
    cores = var.db_server_cores
    type  = "host"
  }

  # ==========================================
  #  RAM
  # ==========================================
  # Arbeitsspeicher-Konfiguration
  #    │
  #    └── dedicated = Größe in MB (aus Variable)
  #        → Hier wird ausschließlich dedizierter RAM vergeben (kein Ballooning)
  #        → Für Datenbanken ist dedizierter RAM oft stabiler

  memory {
    dedicated = var.db_server_memory
  }

  # ==========================================
  #  NETZWERK
  # ==========================================
  # Netzwerk-Adapter der VM
  #    │
  #    └── bridge  = Virtueller Switch (aus Variable)
  #        vlan_id = VLAN-Tag (aus Variable)
  #        → Gleiche Bridge/VLAN wie web-server – geteilte Variable, bewusst keine
  #          eigene db_server-Variante, da die Netzwerk-Zuordnung projektweit
  #          (nicht VM-spezifisch) definiert ist.
  #        → So wird sichergestellt, dass alle VMs im selben Subnetz kommunizieren
  #          können, ohne dass jede VM eigene Netzwerkvariablen erhält.

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan_id
  }

  # ==========================================
  #  FESTPLATTE
  # ==========================================
  # Festplattenkonfiguration
  #    │
  #    └── datastore_id = Speicher-Pool (z.B. "local-lvm") – aus Variable
  #        interface    = SCSI-Controller und Laufwerksnummer (scsi0)
  #        size         = Plattenplatz in GB (aus Variable)
  #        → Die Festplatte wird als SCSI-Gerät angelegt (beste Performance)
  #        → Die Größe ist für den DB-Server separat definiert, weil DBs oft
  #          mehr Speicher benötigen als Webserver

  disk {
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.db_server_disk_size
  }

  # ==========================================
  #  CLOUD-INIT
  # ==========================================
  # Initialisierung der VM bei der ersten Inbetriebnahme
  #    │
  #    └── DNS-Server, IP-Konfiguration, Benutzerkonto
  #        → Cloud-Init wird bei Proxmox über eine separate CD-ROM bereitgestellt
  #        → Terraform generiert die Konfiguration automatisch

  initialization {

    # ---- DNS ----
    # DNS-Server für die VM (statisch gesetzt, da keine DHCP-Übergabe)
    #    │
    #    └── servers = ["8.8.8.8", "1.1.1.1"] (Google DNS)
    #        → Kann durch unternehmenseigene DNS-Server ersetzt werden

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    # ---- IP-KONFIGURATION ----
    # Statische IPv4-Konfiguration für die VM
    #    │
    #    └── address = var.db_server_ip (z.B. "10.0.30.10/24")
    #        gateway = var.network_gateway (z.B. "10.0.30.1")
    #        → Die IP wird als Variable übergeben, damit sie pro Umgebung
    #          angepasst werden kann (z.B. .10 für DB, .11 für Web)

    ip_config {
      ipv4 {
        address = var.db_server_ip
        gateway = var.network_gateway
      }
    }

    # ---- BENUTZERKONTO ----
    # Anlegen eines Benutzers für den SSH-Zugriff
    #    │
    #    └── username = "ansible" (gleicher User wie web-server)
    #        keys     = [trimspace(var.ssh_public_key)] (öffentlicher SSH-Key)
    #        → Der gleiche User/Key wird vorerst für alle VMs verwendet
    #        → In Phase 5 (Vault) wird das pro VM differenziert,
    #          aktuell bewusst identisch gehalten, um die Komplexität
    #          während der Entwicklung zu reduzieren.

    user_account {
      username = "ansible"
      keys     = [trimspace(var.ssh_public_key)]
    }

  } # Ende initialization

  # ---- LIFECYCLE: clone-Block nach Import ignorieren ----
  lifecycle {
    ignore_changes = [clone]
  }

} # Ende resource

# ============================================================
# RESOURCE: proxmox_virtual_environment_vm.test_vm
# ************************************************************
# ZWECK: Wegwerf-Test-VM für Phase 2B.2 (Test-vor-Promotion)
#        Wird aus dem frisch gebauten, noch ungetesteten Template
#        geklont, dient nur der automatisierten Qualitätskontrolle.
#
# ERSTELLT:         2026-08-16
# LETZTE ÄNDERUNG:  2026-08-16
# VON:              Infrastructure Team
#
# WICHTIG: Diese VM ist NUR für Testzwecke gedacht!
#          - Sie wird automatisiert erstellt, getestet und wieder gelöscht
#          - Keine dauerhaften Daten oder Konfigurationen speichern
#          - DHCP verwendet (keine statische IP, um Konflikte zu vermeiden)
#          - Die VM dient als Qualitätsgate: Nur bei erfolgreichem Test
#            wird das Template für Produktion freigegeben
# ============================================================

resource "proxmox_virtual_environment_vm" "test_vm" {
  # ---- GRUNDEINSTELLUNGEN ----
  # Name, Beschreibung und Tags für die Test-VM
  #    │
  #    └── "test-vm-temp" = Deutlicher Hinweis auf temporären Charakter
  #        description = Erklärt den Zweck für andere Admins
  #        tags = ["test", "temporary"] → Erleichtert das Auffinden und spätere Löschen

  name        = "test-vm-temp"
  description = "Wegwerf-Test-VM - Phase 2B.2 Qualitätskontrolle"
  tags        = ["test", "temporary"]

  # ---- PROXMOX NODE ----
  # Auf welchem Proxmox-Host wird die VM erstellt?
  #    │
  #    └── Gleicher Node wie Produktions-VMs für realistische Testbedingungen

  node_name = var.target_node

  # ---- VM-ID ----
  # Keine feste vm_id! Proxmox vergibt automatisch eine freie ID
  #    │
  #    └── Grund: Analog zur Template-Logik vom 15.08.
  #        → Vermeidet Kollisionen bei parallelen Testläufen
  #        → Keine manuelle Verwaltung von Test-VM-IDs nötig
  #        → Wichtig: Die ID wird für nachfolgende Schritte benötigt
  #          (z.B. zum Löschen oder für Test-Ausgaben)

  # ---- AUTOSTART & START-STEUERUNG ----
  # Steuerung des Startverhaltens
  #    │
  #    └── on_boot = false → VM startet nicht automatisch beim Host-Boot
  #        started = true  → VM wird sofort nach Erstellung gestartet
  #        → Warum started = true? Der QEMU-Guest-Agent benötigt eine
  #          laufende VM, um die IP-Adresse zu melden. Ohne diese Info
  #          kann Terraform die IP nicht auslesen und Tests schlagen fehl.

  on_boot = false
  started = true          # Pflicht: Guest-Agent braucht laufende VM für IP-Meldung

  # ---- QEMU GUEST AGENT ----
  # Aktiviert den QEMU-Gast-Agent
  #    │
  #    └── PFICHT für die IP-Abfrage und für Tests!
  #        → Ohne Agent kann Terraform die IP nicht auslesen
  #        → Test-Scripts können keine Verbindung zur VM herstellen
  #        → Daher: zwingend enabled = true

  agent {
    enabled = true
  }

  # ---- TIMEOUT CLONE ----
  # Maximale Wartezeit beim Klonen der Vorlage (in Sekunden)
  #    │
  #    └── 600 Sekunden = 10 Minuten
  #        → Auch Test-VMs können groß sein (abh. vom Template)
  #        → Verhindert Timeout-Fehler in der CI/CD-Pipeline

  timeout_clone = 600

  # ---- TEMPLATE KLONEN ----
  # Welches Template wird als Basis verwendet?
  #    │
  #    └── var.test_template_id = ID des frisch gebauten Templates
  #        → Das ist das Template, das in Phase 2B.1 gebaut wurde
  #        → Es wird hier getestet, bevor es für Produktion freigegeben wird
  #        → Wichtige Entscheidung: Das Template wird NUR getestet
  #          wenn dieser Klon erfolgreich alle Tests durchläuft

  clone {
    vm_id = var.test_template_id    # Template-ID der Wegwerf-Test-VM
  }

  # ---- CPU ----
  # Prozessor-Konfiguration für die Test-VM
  #    │
  #    └── cores = var.web_server_cores → vorerst wiederverwendet
  #        → Grund: Einfache Implementierung, geringerer Wartungsaufwand
  #        → Ggf. später eigene Variable: var.test_vm_cores
  #        → type = "host" → Beste Performance für Tests

  cpu {
    cores = var.web_server_cores    # vorerst wiederverwendet, ggf. eigene Variable später
    type  = "host"
  }

  # ---- RAM ----
  # Arbeitsspeicher-Konfiguration für die Test-VM
  #    │
  #    └── dedicated = var.web_server_memory → Wiederverwendung der Web-VM-Werte
  #        → Test-VM sollte ähnliche Ressourcen haben wie Produktion
  #        → Sonst sind Testergebnisse nicht aussagekräftig
  #        → Ggf. später eigene Variable

  memory {
    dedicated = var.web_server_memory
  }

  # ---- NETZWERK ----
  # Netzwerk-Interface der Test-VM
  #    │
  #    └── bridge = var.network_bridge → Gleicher virtueller Switch
  #        vlan_id = var.network_vlan_id → Gleiches VLAN
  #        → Grund: Test-VM sollte im gleichen Netzwerk sein wie die
  #          späteren Produktions-VMs für realistische Tests
  #        → Aber: DHCP statt statischer IP (s.u.) um Konflikte zu vermeiden

  network_device {
    bridge  = var.network_bridge
    vlan_id = var.network_vlan_id
  }

  # ---- FESTPLATTE ----
  # Speicher-Konfiguration für die Test-VM
  #    │
  #    └── datastore_id = var.disk_datastore → Gleicher Speicherort
  #        interface = "scsi0" → SCSI-Controller für Performance
  #        size = var.web_server_disk_size → Wiederverwendung der Web-VM-Größe
  #        → Test-VM sollte gleiche Speichergröße haben wie Produktion
  #        → Sonst können Tests (z.B. Disk-Space) nicht repräsentativ sein

  disk {
    datastore_id = var.disk_datastore
    interface    = "scsi0"
    size         = var.web_server_disk_size
  }

  # ---- CLOUD-INIT ----
  # Automatische Konfiguration beim ersten Start
  #    │
  #    └── Hier wird die Test-VM initialisiert
  #        → Wichtig: Die gleiche Konfiguration wie Produktion?
  #        → Für Tests: So nah wie möglich am Produktionssetup

  initialization {
    # ---- DNS ----
    # Nameserver für die Test-VM
    #    │
    #    └── Gleiche DNS-Server wie Produktion
    #        → Sonst können Tests (DNS-Auflösung) fehlschlagen

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    # ---- IP-KONFIGURATION ----
    # Wichtige Abweichung zur Produktion!
    #    │
    #    └── address = "dhcp" → KEINE statische IP!
    #        → Warum DHCP? Vermeidet IP-Konflikte mit Produktion
    #        → Test-VM wird nur kurzzeitig benötigt → DHCP reicht
    #        → Keine manuelle IP-Planung für Tests nötig
    #        → Die IP wird vom Guest-Agent ausgelesen für Tests
    #        → Nachteil: IP kann sich ändern (unwichtig für Wegwerf-VM)

    ip_config {
      ipv4 {
        address = "dhcp"     # keine feste IP - DHCP übernimmt
      }
    }

    # ---- BENUTZERKONTO ----
    # Anlegen eines Benutzers für SSH-Zugriff (Tests)
    #    │
    #    └── username = "ansible" → Gleicher User wie Produktion
    #        keys = [trimspace(var.ssh_public_key)] → Gleicher SSH-Key
    #        → Grund: Test-Scripts sollen gleichen Zugang haben wie Produktion
    #        → Erleichtert die automatisierte Testdurchführung
    #        → Wichtig: Der User/Key muss für die Test-Scripts verfügbar sein

    user_account {
      username = "ansible"
      keys     = [trimspace(var.ssh_public_key)]
    }
  }

}

# ============================================================
# NACH DEM TEST (Phase 2B.3):
#   Diese VM wird automatisch wieder gelöscht!
#   - Sie ist NUR für den Test-Zeitraum gedacht
#   - Keine manuelle Bereinigung nötig
#   - Bei Fehlern: VM bleibt als "test-vm-temp" sichtbar
#   - Manuelles Löschen: qm destroy <VM-ID> (nach Rücksprache)
# ============================================================