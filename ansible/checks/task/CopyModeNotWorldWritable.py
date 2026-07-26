# =============================================================================
# Datei:    CopyModeNotWorldWritable.py
# Check-ID: CKV_ANSIBLE_CUSTOM_1
# Autor:    Randolph Bluming (mit Claude, Session-Datum: 26.07.2026)
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
# Ermöglicht moderne Typ-Annotationen wie "dict[str, Any]" statt "Dict[str, Any]",
# auch wenn das Projekt evtl. mit einer älteren Python-Version läuft. Reines
# Kompatibilitäts-Feature, hat keinen Einfluss auf die Check-Logik selbst.

from typing import Any
# Nur für die Typ-Hints (z.B. "-> Any", "dict[str, Any]") – rein zur besseren
# Lesbarkeit/IDE-Unterstützung, wird zur Laufzeit nicht ausgewertet.

from checkov.ansible.checks.base_ansible_task_value_check import BaseAnsibleTaskValueCheck
# DIE zentrale Zeile, analog zu eurem "BaseResourceCheck" bei Terraform bzw.
# "BaseProviderCheck" bei CKV_PROXMOX_2. Das ist die Basisklasse, die Checkov
# intern für alle Ansible-TASK-Checks (nicht Blöcke, nicht Playbooks als Ganzes)
# bereitstellt. Sie übernimmt im Hintergrund:
#   - das Einlesen/Parsen von playbook.yml (ihr müsst kein YAML selbst parsen)
#   - das Herausfiltern genau der Tasks, die eines der "supported_modules" nutzen
#   - die Umsetzung von CheckResult in die PASSED/FAILED/SKIPPED-Ausgabe, die ihr
#     schon aus den Terraform-Checks kennt

from checkov.common.models.enums import CheckResult, CheckCategories
# Gleiche zwei Enums wie bei euren Terraform-Checks (CKV_PROXMOX_1-3):
#   - CheckResult: die drei möglichen Ausgänge (PASSED / FAILED / UNKNOWN),
#     "SKIPPED" kommt NICHT von hier, das setzt Checkov selbst nachträglich,
#     wenn ein "checkov:skip"-Kommentar im YAML gefunden wird (exakt der
#     Mechanismus, den ihr bei CKV_PROXMOX_2 am 07.07. kennengelernt habt)
#   - CheckCategories: nur für die Einordnung/Anzeige (z.B. in --list), hat
#     keinen Einfluss auf PASSED/FAILED selbst


class CopyModeNotWorldWritable(BaseAnsibleTaskValueCheck):
    # Klassenname ist frei wählbar (wie bei ProxmoxDiskMemorySet) - Checkov
    # erkennt den Check nicht am Klassennamen, sondern an der "id" weiter unten
    # UND daran, dass ganz am Dateiende "check = CopyModeNotWorldWritable()"
    # steht (die eigentliche Registrierung, dazu gleich mehr).

    def __init__(self) -> None:
        # Wird EINMAL beim Laden des Checks durch Checkov ausgeführt (beim
        # Scan-Start, nicht pro gefundenem Task) - hier wird nur die
        # "Visitenkarte" des Checks definiert, noch keine Prüf-Logik.

        name = "Ensure files deployed via copy/template are not world-writable"
        # Freitext, erscheint 1:1 in der Konsolen-Ausgabe hinter "Check: CKV_...".
        # Nur Dokumentation, keine funktionale Bedeutung.

        id = "CKV_ANSIBLE_CUSTOM_1"
        # Die eindeutige Check-ID. WICHTIG: "CKV_ANSIBLE_" ist der Namensraum,
        # den Bridgecrew selbst für offizielle eingebaute Checks nutzt (siehe
        # eure Baseline: CKV_ANSIBLE_1, _5, _6). Um Kollisionen mit künftigen
        # offiziellen Checkov-Updates zu vermeiden (z.B. falls Bridgecrew
        # irgendwann selbst einen "CKV_ANSIBLE_7" einführt), wäre ein Präfix
        # wie "CKV_CUSTOM_" oder "CKV2_HOMELAB_" sauberer. Bewusst als
        # Diskussionspunkt stehen gelassen, kein Blocker.

        super().__init__(
            # Ruft den Konstruktor der Basisklasse (BaseAnsibleTaskValueCheck)
            # auf und übergibt ihm die "Visitenkarte" - genau wie bei euren
            # Terraform-Checks das super().__init__(name=..., id=..., ...).

            name=name,
            id=id,

            categories=(CheckCategories.GENERAL_SECURITY,),
            # Gleiche Kategorie wie bei CKV_PROXMOX_1-3, nur zur Einordnung.

            supported_modules=(
                "ansible.builtin.copy", "copy",
                "ansible.builtin.template", "template",
            ),
            # DAS ist der Ansible-spezifische Ersatz für "supported_resources"
            # (das kanntet ihr bei Terraform als z.B. ["proxmox_virtual_environment_vm"]).
            # Checkov filtert damit NUR die Tasks heraus, die eines dieser vier
            # Modul-Namen verwenden - euer Task 7 nutzt "copy" (bzw. je nach
            # Ansible-Version intern "ansible.builtin.copy"), daher stehen
            # beide Schreibweisen hier drin, um sicher zu gehen.

            missing_block_result=CheckResult.PASSED,
            # Was soll passieren, wenn ein "copy"/"template"-Task gefunden
            # wird, der GAR KEIN "mode"-Attribut gesetzt hat? Wir sagen: PASSED
            # (kein Fehler), weil Ansible dann selbst einen sicheren
            # Standard-Mode setzt (abhängig vom umask des Zielsystems) - wir
            # wollen nur explizit UNSICHERE Werte melden, nicht das Fehlen
            # einer Angabe bestrafen. Vergleichbar mit eurer Entscheidung bei
            # CKV_PROXMOX_2, wo ihr auch nur den gefährlichen Fall (insecure=true)
            # melden wolltet, nicht die Abwesenheit des Parameters.
        )

    def get_inspected_key(self) -> str:
        # Diese Methode VERLANGT die Basisklasse zwingend (abstrakte Methode -
        # ohne sie würde die Klasse gar nicht instanziierbar sein, ähnlich wie
        # scan_resource_conf() bei BaseResourceCheck Pflicht ist). Normalerweise
        # sagt sie Checkov, welchen YAML-Key es aus dem Task-Dict lesen soll,
        # für den einfachen "Ist Attribut X == erwarteter Wert"-Fall.
        return "mode"
        # Wir geben hier trotzdem "mode" zurück (korrekt, aber ungenutzt),
        # weil wir die Prüf-LOGIK gleich komplett selbst in scan_conf()
        # übernehmen - dazu unten mehr. Diese Methode ist quasi nur noch
        # Pflichterfüllung gegenüber der Basisklasse.

    def get_expected_value(self) -> Any:
        # Ebenfalls von der Basisklasse verlangt. Sie ist für den einfachen
        # Fall gedacht: "conf[get_inspected_key()] muss GENAU get_expected_value()
        # entsprechen, sonst FAILED" - das reicht für simple Ja/Nein-Prüfungen
        # (z.B. "force muss False sein", wie im echten Bridgecrew-Beispiel
        # AptForce.py, das ich vorhin recherchiert habe).
        return None
        # Für UNSEREN Fall ("ist die letzte Ziffer von mode gefährlich?")
        # reicht eine einfache Gleichheitsprüfung nicht - "0644" != "0777"
        # wäre schon durch simplen String-Vergleich FAILED, obwohl beide
        # eigentlich win Value haben könnten der geprüft werden muss anhand
        # einer Regel, nicht eines fixen Sollwerts. Deshalb bleibt der
        # Rückgabewert hier bedeutungslos (None) - siehe scan_conf() unten,
        # das diesen Mechanismus komplett übersteuert.

    def scan_conf(self, conf: dict[str, Any]) -> tuple[CheckResult, dict[str, Any]]:
        # Das ist der eigentliche Prüf-Kern, direkt vergleichbar mit eurem
        # "scan_resource_conf(self, conf)" bei den Terraform-Checks - nur
        # heißt die Methode bei Ansible-Task-Checks "scan_conf" statt
        # "scan_resource_conf" (anderer Rahmen, gleiches Prinzip: Checkov
        # ruft diese Methode EINMAL PRO GEFUNDENEM TASK auf, der zu den
        # oben genannten supported_modules passt).
        #
        # "conf" ist hier das Dict der Task-Parameter, z.B. bei eurem Task 7
        # ungefähr:
        #   {"src": "index.html", "dest": "/var/www/html/index.html",
        #    "owner": "www-data", "group": "www-data", "mode": "0644"}
        #
        # Überschreiben wir diese Methode selbst, wird get_inspected_key()/
        # get_expected_value() von der Basisklasse NICHT mehr automatisch
        # ausgewertet - unsere eigene Logik hat Vorrang. Exakt das gleiche
        # Muster wie im echten Bridgecrew-Check "EC2EBSOptimized", den ich
        # als Referenz herangezogen habe.

        mode = conf.get("mode")
        # Holt den Wert des "mode"-Attributs aus dem Task. Falls das
        # Attribut fehlt, ist "mode" hier None (kein Fehler, siehe nächste
        # Zeile).

        if not mode:
            return CheckResult.PASSED, self.entity_conf
            # Kein "mode" gesetzt -> laut unserer Entscheidung oben (siehe
            # missing_block_result) kein Fehlerfall. "self.entity_conf" ist
            # ein von der Basisklasse bereitgestelltes Attribut - es enthält
            # die vollständige Task-Konfiguration inkl. Zeilennummern-Infos,
            # die Checkov braucht, um in der Ausgabe "File: /playbook.yml:X-Y"
            # korrekt anzuzeigen. Muss bei JEDEM Return mitgegeben werden.

        mode_value = str(mode).strip("'\"")
        # Ansible/YAML liefert "mode" manchmal als String mit Anführungszeichen
        # (z.B. wenn im YAML "mode: '0644'" steht, kommt teils der Rohwert
        # inklusive Quotes an). .strip("'\"") entfernt einfache und doppelte
        # Anführungszeichen am Anfang/Ende, damit wir sauber mit der Ziffer
        # arbeiten können, unabhängig von der Schreibweise im YAML.

        try:
            last_digit = int(mode_value[-1])
            # Nimmt das letzte Zeichen des Mode-Strings (z.B. bei "0644" die
            # "4") und wandelt es in eine Zahl um. In der Unix-Rechtevergabe
            # kodiert die LETZTE Ziffer die Rechte für "andere" (also alle
            # außer Besitzer und Gruppe) - genau die Zielgruppe, die bei
            # "world-writable" gemeint ist. Analogie zu eurem
            # 00_projekt_ziel_und_lernpfad.md-Stil: Die drei Ziffern in "0644"
            # sind wie drei Schlüssel für drei Personengruppen (Eigentümer /
            # Gruppe / Rest der Welt) - uns interessiert hier nur der dritte
            # Schlüssel.
        except (ValueError, IndexError):
            return CheckResult.UNKNOWN, self.entity_conf
            # Absicherung: falls "mode" mal kein normaler Zahlen-String ist
            # (z.B. ein Ansible-Jinja2-Ausdruck wie "{{ some_var }}", oder ein
            # leerer String), können wir seriös weder PASSED noch FAILED sagen
            # - UNKNOWN ist der ehrliche dritte Zustand dafür (kennt ihr aus
            # der CheckResult-Enum-Liste, wurde bisher bei euch aber noch
            # nicht gebraucht).

        if last_digit in (2, 3, 6, 7):
            # Oktal-Ziffern 2, 3, 6, 7 sind GENAU die vier Ziffern, deren
            # Bit-Muster das Schreibbit (Wert 2 im rwx-Schema: r=4, w=2, x=1)
            # enthalten - 2=nur schreiben, 3=schreiben+ausführen, 6=lesen+
            # schreiben, 7=alles. Die anderen vier Ziffern (0,1,4,5) enthalten
            # dieses Bit nicht. Das ist eine feste, seit Jahrzehnten stabile
            # Unix-Konvention, keine projektspezifische Annahme.
            return CheckResult.FAILED, self.entity_conf
            # Weltweit schreibbare Datei gefunden -> echter Sicherheitsbefund,
            # analog zu eurem "insecure=true" bei CKV_PROXMOX_2.

        return CheckResult.PASSED, self.entity_conf
        # Letzte Ziffer ist "sicher" (0,1,4,5) -> Check besteht. Bei eurem
        # echten Task 7 mit "mode: '0644'" landet die Prüfung genau hier:
        # last_digit = 4 -> nicht in (2,3,6,7) -> PASSED.


check = CopyModeNotWorldWritable()
# GENAU diese Zeile ist es, die den Check überhaupt "scharf schaltet" - ohne
# sie bliebe die Klassendefinition oben nur toter Code, den niemand aufruft.
# Checkov durchsucht beim Start mit "--external-checks-dir" jede .py-Datei
# im angegebenen Ordner nach genau so einer Zuweisung (Variablenname "check"
# ist Konvention, nicht frei wählbar!) und registriert das Objekt dann in
# seiner internen Check-Registry. Ihr kennt dieses Prinzip schon 1:1 von
# CKV_PROXMOX_1-3 - dort stand exakt die gleiche Art Zeile am Dateiende.


from __future__ import annotations
from typing import Any

from checkov.ansible.checks.base_ansible_task_value_check import BaseAnsibleTaskValueCheck
from checkov.common.models.enums import CheckResult, CheckCategories


class CopyModeNotWorldWritable(BaseAnsibleTaskValueCheck):
    def __init__(self) -> None:
        name = "Ensure files deployed via copy/template are not world-writable"
        id = "CKV_ANSIBLE_CUSTOM_1"
        super().__init__(
            name=name,
            id=id,
            categories=(CheckCategories.GENERAL_SECURITY,),
            supported_modules=(
                "ansible.builtin.copy", "copy", # siehe hierzu im playbook da wird copy verwendet
                "ansible.builtin.template", "template",
            ),
            missing_block_result=CheckResult.PASSED,  # kein 'mode' gesetzt -> kein erzwungener Fehler unsererseits
        )

    # Von der Basisklasse verlangt, wird aber durch unser eigenes scan_conf() unten nicht genutzt
    def get_inspected_key(self) -> str:
        return "mode"

    def get_expected_value(self) -> Any:
        return None

    def scan_conf(self, conf: dict[str, Any]) -> tuple[CheckResult, dict[str, Any]]:
        mode = conf.get("mode")
        if not mode:
            return CheckResult.PASSED, self.entity_conf

        mode_value = str(mode).strip("'\"")
        try:
            last_digit = int(mode_value[-1])
        except (ValueError, IndexError):
            # Fail-closed (konsistent zu ProxmoxDiskMemorySet.py, CKV_PROXMOX_3):
            # Ein nicht als Oktalzahl parsbarer Wert (z.B. symbolische Notation
            # wie "u+rwx") kann nicht als sicher verifiziert werden -> als
            # FAILED werten statt UNKNOWN, statt stillschweigend durchzulassen.
            return CheckResult.FAILED, self.entity_conf

        if last_digit in (2, 3, 6, 7):
            return CheckResult.FAILED, self.entity_conf

        return CheckResult.PASSED, self.entity_conf


check = CopyModeNotWorldWritable()