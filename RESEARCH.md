# Recherche und Architekturentscheidung

Stand: 18. November 2026. Verwendet wurden die Dokumentation und Repositories
der jeweiligen Projekte; die Implementierung wurde zusätzlich praktisch mit
clangd 19.1.2 geprüft.

| Vorbild | Was es löst | Konsequenz für Clective |
| --- | --- | --- |
| [clangd: Compile commands](https://clangd.llvm.org/design/compile-commands) | Sprachmodus, Include-Pfade und Defines bestimmen gemeinsam, wie eine Datei verstanden wird. Für Header muss oft ein Quelltextkommando herangezogen werden. | Ein Profil enthält Sprache und SDK-Kontext zusammen; vorhandene Build-Kommandos bleiben bei der Projektvariante die Grundlage. |
| [cmake-tools.nvim](https://github.com/Civitasv/cmake-tools.nvim/blob/master/docs/howto.md) | Verbindet die aktive CMake-Build-Konfiguration mit einer für den Language Server erreichbaren Compilation Database, unter anderem durch Kopieren oder Verlinken. | Clective liest Build-Datenbanken und konfigurierbare Build-Verzeichnisse. Ein Projektprofil ergänzt die vorhandene CMake-Integration. |
| [clangd: Protocol extensions](https://clangd.llvm.org/extensions) | Dokumentiert die Übergabe dateibezogener Compile-Kommandos und den Source/Header-Wechsel. | Clective aktualisiert den bereits verbundenen clangd direkt und nutzt dessen Source/Header-Anfrage. Ein zweiter Language Server ist dafür unnötig. |
| [clangd: Configuration](https://clangd.llvm.org/config) | Unterstützt projektspezifische Regeln, zusätzliche Compilerflags und Einstellungen zur Indizierung. | Bestehende .clangd-Dateien bleiben erhalten. Ihre YAML-Regeln werden in dieser Version nicht zusätzlich von der Include-Completion ausgewertet. |
| [clangd_extensions.nvim](https://github.com/p00f/clangd_extensions.nvim) | Zusätzliche clangd-Funktionen wie AST-Ansichten und erweiterte Symbolinformationen. Das Repository verweist auf seinen aktuellen Hosting-Ort. | Solche Ansichten sind eine sinnvolle spätere Ergänzung, müssen aber nicht in Clective neu entwickelt werden. |
| [Oscar64](https://github.com/drmortalwombat/oscar64) | Eigener Compiler für 6502-Plattformen mit eigenen Plattform- und Spracherweiterungen. | SDK-Auswahl ist möglich; Gleichheit zwischen clangd und dem Oscar64-Compiler wird nicht behauptet. |

## Warum clangd bleibt

Clective kann Dateinamen finden und Include-Verzeichnisse verwalten. Für
semantische Symbolsuche, Referenzen, Definitionen, Typinformationen und
Umbenennen braucht es den Parser und Index eines Language Servers. Deshalb
bleibt clangd die Analysekomponente. Der tatsächliche Build kann weiterhin mit
GCC, einem Amiga-Crosscompiler oder Oscar64 laufen.

Ein passender Include-Pfad beseitigt fehlende Header. Er beseitigt nicht jede
Inkompatibilität eines anderen Compilers. Insbesondere werden Wortbreiten,
Calling Conventions, Registerdeklarationen und fremde Builtins nicht allein
durch einen Profilnamen korrekt. Die mitgelieferten Retroprofile verwenden
deshalb keine geratenen Architekturwerte.

## Bereits umgesetzt

Gemeinsame Sprach-/SDK-Profile; Projekt- und Datei-Auswahl; Kontext für .h;
Standardpfade aus einem ausdrücklich konfigurierten Compiler; Build-Datenbanken;
korrekte Include-Completion; Header-Picker; Statuszeile pro Buffer; Übergabe an
clangd; Projektindizierung; Source/Header-Wechsel; Info und Healthcheck.

## Sinnvolle nächste Ergänzungen

1. **Echte SDK-Prüfprofile für Amiga und Oscar64.** Mit deinen installierten SDKs
   repräsentative Dateien analysieren und gezielte Kompatibilitätsheader nur
   für clangd entwickeln. Das bringt mehr als pauschales Abschalten von Fehlern.
2. **CMake-Presets beziehungsweise Build-Konfigurationen direkt übernehmen.**
   Damit könnte der Profilwähler auch Debug/Release und den dazugehörigen
   Datenbankpfad gemeinsam umschalten.
3. **Vererbbare Profile.** Gemeinsame SDK-Pfade einmal definieren und etwa
   „Amiga NDK 3.5 + Projektbibliotheken“ daraus ableiten.
4. **Projektdatei mit deklarativen Profilen.** Eine eingecheckte JSON-Datei
   wäre für mehrere Rechner nützlich; maschinenspezifische SDK-Pfade sollten
   dabei über lokale Variablen getrennt bleiben.
5. **Herkunft einer Include-Entscheidung vergleichen.** Bei gleichnamigen
   Headern alle Kandidaten und die Suchreihenfolge anzeigen.

Diese Punkte sind Vorschläge, keine bereits implementierten Funktionen.
