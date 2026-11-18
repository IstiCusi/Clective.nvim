# Testbericht: lokales Clective-Update

Geprüft am 18. November 2026 unter Linux.

| Prüfung | Umgebung | Ergebnis |
| --- | --- | --- |
| Plugin-Regressionssuite | Neovim 0.11.5, clangd 19.1.2, echtes nvim-cmp | 28 bestanden, keine Fehler, keine übersprungenen Tests |
| Plugin-Regressionssuite | Neovim 0.12.6, clangd 19.1.2, echtes nvim-cmp | 28 bestanden, keine Fehler, keine übersprungenen Tests |
| Integration in die hochgeladene Neovim-Konfiguration | Neovim 0.11.5 | 8 Abläufe bestanden |
| Integration in die hochgeladene Neovim-Konfiguration | Neovim 0.12.6 | 8 Abläufe bestanden |
| Echte Terminalbedienung mit HotZig/Docpair | Neovim 0.11.5 | 10 Abläufe bestanden |
| Echte Terminalbedienung mit HotZig/Docpair | Neovim 0.12.6 | 10 Abläufe bestanden |
| Installer | Python, temporäre Konfigurationen | 3 Tests bestanden |

Die maschinenlesbaren Neovim-Ergebnisse stehen unter `tests/results/`.
Die eigenständig ausführbaren Tests sind `tests/run.py` und
`tests/install_test.py`.

## Inhalt der Plugin-Prüfungen

- Zwei getrennte Projekte mit unterschiedlichen Profilen in einer Sitzung.
- Aktualisieren bereits geladener Buffer nach einem Projektprofilwechsel.
- Dateispezifische Auswahl und Rücksetzen; Persistenz außerhalb des Plugins.
- C-/C++-Dateiendungen, .h-Kontext und geerbte Datei-Ausnahmen.
- Verschachtelte Includes, leere Präfixe und Header ohne Dateiendung.
- Keine doppelten identischen Vorschläge; korrekte Pfadnormalisierung.
- Unterschiedliche Suchreihenfolge für Anführungszeichen und spitze Klammern.
- Kein Include-Treffer in einer mit // auskommentierten Direktive.
- Header außerhalb des Projektordners behalten den Quelltextkontext.
- Keine falsche rekursive Auflösung von libraries.h auf exec/libraries.h.
- Wiederholtes setup erzeugt keine doppelten Autocommands.
- Build-Flags und Compilation Database, relative Pfade und Leerzeichen.
- Shell-Quoting wird gelesen, ohne einen Build-Befehl auszuführen.
- Geänderte Build-Dateien werden nach Refresh berücksichtigt.
- Native Standard-Includes werden über den konfigurierten Compiler gefunden.
- Profilwechsel verändern den Quelltext nicht.
- Diagnoseansicht und Healthcheck.
- Mit echtem clangd: SDK A/B führt zu unterschiedlichen Definitionszielen.
- Mit echtem clangd: Dokumentsymbole und Source/Header-Wechsel.
- Mit echtem clangd: Projektsymbole aus einer noch nie geöffneten Quelldatei.
- Mit echtem nvim-cmp: Übernahme eines verschachtelten Include-Pfads.
- Wiederherstellung normaler Completion-Quellen und zusätzlicher Bufferoptionen.
- Leere Includes erhalten Vorschläge ohne erzwungenen manuellen Completion-Aufruf.
- Das mitgelieferte Demo-Skript lädt; eine .h-Datei im C++-Profil liefert das
  C++-Namespace-Symbol über clangd und lässt sich wieder auf C zurücksetzen.

## Integration und Bedienung

Die Tests luden die vorhandene Lazy-Konfiguration mit ihren bereitgestellten
Plugins. Geprüft wurden das tatsächliche Profil-Auswahlfenster, Enter zur
Auswahl, Ctrl-J/Enter zur Completion-Übernahme, gf, der Telescope-Headerpicker,
die Infoansicht, die echte Lualine-Komponente und Docpair.

Die Terminalprüfung verwendete das HotZig-Beispiel und kontrollierte:
Space-Menü im linken Quelltextfenster nach verzögertem LSP-Start, verschachtelte
Leader-Menüs, Serverneustart, Fensterwechsel, Cursorbewegung, Bufferwechsel und
Tabwechsel. Ein Testserver erzeugte dabei die LSP-Attach/Detach-Ereignisse;
dieser Terminaltest behauptet keine Prüfung des Zig-Language-Servers.

## Testumgebung und Grenzen

Die vollständige Konfiguration lief in einer isolierten Kopie, nicht auf dem
Benutzerrechner. Lokale Pluginpfade wurden auf diese Kopie umgesetzt.
Plugin-/Mason-/Parser-Downloads waren abgeschaltet. Der nicht mehr abrufbare,
ursprünglich gesperrte Leap-Commit wurde im Test deaktiviert; bereits benötigte
Lua-Abhängigkeiten wurden aus dem Testbestand eingebunden.

Die vorhandene Konfiguration meldete im Testsystem das fehlende externe
`clang-tidy`; unter der eingebetteten UI meldete image.nvim teils eine nicht
abfragbare Terminalgröße. Diese Umgebungsbefunde sind in den Ergebnisdateien
erhalten. Es gab keine Clective-Konfigurationsfehler.

Die echten Amiga-/NDK-/Oscar64-SDKs stehen in dieser Umgebung nicht zur
Verfügung. Ihre bisherigen Verzeichnisse sind in die Lazy-Konfiguration
übernommen. Für die Funktionsprüfungen wurden künstliche SDKs und native
Compilerheader verwendet. Kompatibilität mit fremden Compilererweiterungen
und einer konkreten Retro-ABI ist damit nicht nachgewiesen.

## Installer-Prüfungen

Getestet wurden Sicherung der alten Dateien, wiederholte Installation,
Verzeichnisse mit Leerzeichen, Erhalt fremder LSP-/Statuskonfiguration und
vorhandener .git-Metadaten. Eine Trockenprobe schreibt nichts. Bei einem nicht
erkannten Konfigurationsaufbau erfolgt der Abbruch, bevor Dateien verändert
werden.

## Noch nicht Gegenstand dieser Version

Windows/MSVC, beliebige .clangd-YAML-Regeln in der Dateinamen-Completion,
Antwortdateien für deren Pfadermittlung, große Monorepos und die genaue
Spracherweiterung jedes Retrocompilers sind nicht umfassend getestet.
Die laufende Version und die bekannten Grenzen sind im README beschrieben.
