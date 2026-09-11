# =============================================================================
# Datei:    CopyModeNotWorldWritable.py
# Check-ID: CKV_ANSIBLE_CUSTOM_1
# Autor:    Randolph Bluming (mit Claude, Session-Datum: 26.07.2026)
#           letzte Änderung: 30.08.2026
# Projekt:  02-CI-CO-VM_v1 – Phase 2A (Security-Gate), Ansible-Vertiefung
#
# Zweck:
#   Custom Checkov-Check für das Ansible-Framework. Prüft alle Tasks, die
#   die Module "copy" oder "template" verwenden (siehe playbook.yml, Task 7:
#   Ausrollen von index.html), und stellt sicher, dass das gesetzte
#   Datei-"mode"-Attribut keine Schreibrechte für "andere" (world-writable)
#   vergibt - konkret werden die Oktal-Endziffern 2, 3, 6 und 7 als FAILED
#   gewertet.
#
# Warum als eigener Check (nicht durch Checkov-Built-ins abgedeckt):
#   Baseline-Scan vom 09.07.2026 (checkov -d ansible/ --framework ansible)
#   zeigte 5 PASSED (CKV_ANSIBLE_1/5/6) + 1 SKIPPED (CKV2_ANSIBLE_1) - keiner
#   davon prüft Datei-Berechtigungen von copy/template-Tasks. Echte Lücke,
#   kein Duplikat eines eingebauten Checks.
#
# Einordnung: Ergänzt die bestehenden Terraform-Custom-Checks (CKV_PROXMOX_1-3,
#   siehe terraform/checks/) um die Ansible-Seite. Kein Pflichtbestandteil der
#   Roadmap-Phase 2A selbst, sondern bewusster Vertiefungs-Zwischenschritt vor
#   Phase 2B (CIS-Hardening im Packer-Provisioner), siehe
#   00_projekt_ziel_und_lernpfad.md.
#
# Ablageort: ansible/checks/task/CopyModeNotWorldWritable.py
# =============================================================================
from __future__ import annotations
from typing import Any

from checkov.ansible.checks.base_ansible_task_value_check import BaseAnsibleTaskValueCheck
from checkov.common.models.enums import CheckResult, CheckCategories


class CopyModeNotWorldWritable(BaseAnsibleTaskValueCheck):
    """
    Prüft, ob Ansible copy/template Tasks world-writable Dateien erzeugen.
    Sicherheitsrisiko: Jeder Systembenutzer könnte die Datei verändern (z.B. Konfigs, SSH-Keys).
    """
    
    def __init__(self) -> None:
        name = "Ensure files deployed via copy/template are not world-writable"
        id = "CKV_ANSIBLE_CUSTOM_1"
        
        super().__init__(
            name=name,
            id=id,
            categories=(CheckCategories.GENERAL_SECURITY,),
            # Ansible erlaubt beide Schreibweisen (Kurz- und Langname) - wir müssen beide abdecken
            supported_modules=(
                "ansible.builtin.copy", "copy",
                "ansible.builtin.template", "template",
            ),
            # Wenn 'mode' ganz fehlt: PASSED, weil Ansible dann sichere Defaults (z.B. 0644) verwendet
            missing_block_result=CheckResult.PASSED,
        )

    # ===== PFLICHTMETHODEN DER BASISKLASSE =====
    # Diese Methoden werden von der Basisklasse gefordert, aber wir nutzen sie nicht,
    # weil wir unsere eigene komplexe Logik in scan_conf() implementieren.
    def get_inspected_key(self) -> str:
        return "mode"

    def get_expected_value(self) -> Any:
        return None

    # ===== KERNLOGIK =====
    def scan_conf(self, conf: dict[str, Any]) -> tuple[CheckResult, dict[str, Any]]:
        """
        Prüft die letzte Oktal-Ziffer des Mode-Strings auf Schreibrechte für 'Others'.
        Bei Oktalzahlen (z.B. 0644) gibt die letzte Ziffer die Rechte für 'Others' an.
        Ziffern mit Schreib-Bit: 2 (010), 3 (011), 6 (110), 7 (111) -> world-writable.
        """
        
        mode = conf.get("mode")
        
        # Wenn 'mode' nicht existiert: PASSED, weil Ansible dann sichere Defaults (z.B. 0644) verwendet
        if not mode:
            return CheckResult.PASSED, self.entity_conf

        # Quotes entfernen (z.B. '0644' oder "0644"), weil Ansible YAML-Werte oft als Strings mit Quotes kommen
        mode_value = str(mode).strip("'\"")
        
        try:
            # Letzte Ziffer extrahieren und als Integer parsen
            last_digit = int(mode_value[-1])
        except (ValueError, IndexError):
            # Wenn 'mode' nicht als Oktalzahl parsebar ist (z.B. "u+rwx"): FAILED,
            # weil wir es nicht verifizieren können (fail-closed Sicherheitsprinzip)
            return CheckResult.FAILED, self.entity_conf

        # Wenn letzte Ziffer 2,3,6,7 ist: FAILED,
        # weil diese Ziffern das Schreib-Bit für 'Others' haben (world-writable)
        if last_digit in (2, 3, 6, 7):
            return CheckResult.FAILED, self.entity_conf

        # Alle Prüfungen bestanden: PASSED, weil Datei nicht world-writable ist
        return CheckResult.PASSED, self.entity_conf


# Singleton-Instanz für automatische Checkov-Registrierung
check = CopyModeNotWorldWritable()