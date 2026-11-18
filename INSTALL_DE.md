# Clective: Installation in deiner Neovim-Konfiguration

Das Update bleibt lokal unter `~/.config/nvim/scripts/clective`.
Es wurde nichts zu GitHub gepusht.

## Einbauen

Neovim vorher schließen. Das ZIP in einen neuen Ordner entpacken und dort:

```sh
cd clective.nvim
python3 install.py --config "$HOME/.config/nvim"
```

Zum vorherigen Anzeigen der betroffenen Dateien:

```sh
python3 install.py --config "$HOME/.config/nvim" --dry-run
```

Der Installer prüft zuerst die vier Einbaupunkte. Danach sichert er alle
ersetzten Dateien in einem benachbarten Ordner namens
`nvim-clective-backup-DATUM-UHRZEIT` und installiert das Update.
Der genaue Sicherungspfad wird ausgegeben. Bei einem abweichenden, nicht
erkannten Aufbau der Lualine-/LSP-Konfiguration bricht er vor dem Schreiben ab.
Eine zweite Ausführung mit denselben Dateien ist wirkungslos.

Er aktualisiert:

| Datei | Änderung |
| --- | --- |
| `scripts/clective/lua/`, `scripts/clective/plugin/`, `scripts/clective/doc/` | Neues Plugin und Hilfe. |
| `lua/plugins/clective.lua` | Vollständige lokale Lazy-Spezifikation mit Profilen und Shortcuts. |
| `lua/modules/lookup_includes.lua` | Bestehendes `Space f i` benutzt den aktuellen Profilkontext. |
| `lua/plugins/lualine.lua` | Nur die Funktion zur Anzeige des Clective-Zustands wird ersetzt. |
| `lua/plugins/lspconfig.lua` | Im clangd-Block entfällt der erzwungene Datenbankpfad `.`; die Root-Marker werden ergänzt und `.clang` zu `.clangd` korrigiert. |

`init.lua`, `keymaps.lua`, deine Docpair-Konfiguration und andere LSP-Server
werden nicht ersetzt. Vorhandene `.git`-Verzeichnisse bleiben erhalten.
Die alte `scripts/clective/state.json` darf liegen bleiben; sie wird nicht mehr
verwendet. Wähle nach dem Update das gewünschte Profil einmal neu.

Die Sicherung enthält die vorherigen Dateiversionen und eine Liste
`NEW_FILES.txt` der neu hinzugekommenen Dateien. Zum Zurücksetzen die gesicherten
Dateien an dieselben relativen Orte zurückkopieren und die neu hinzugekommenen
Dateien anhand dieser Liste entfernen.

## Erster Start

1. Neovim neu starten und eine C-/C++-Datei deines Projekts öffnen.
2. **Space, großes K, c** drücken. K bedeutet `Shift+k`.
3. Zum Beispiel **Amiga C** wählen und mit Enter bestätigen.
4. Die Statuszeile sollte beispielsweise `C · Amiga C` zeigen.
5. **Space K i** öffnet die tatsächlich verwendeten Pfade und zeigt fehlende
   Verzeichnisse. Mit `q` schließen.
6. `:checkhealth clective` prüft den grundlegenden Aufbau.

Der Standard ist „Project build settings“. Bei bestehenden CMake-/Make-Projekten
mit Compilation Database ist das meist der passende Ausgangspunkt. Für native
Dateien ohne vollständige Build-Einstellungen wählst du „Linux C (GCC)“ oder
„Linux C++ (G++)“, damit auch die Compiler-Standardheader im Picker erscheinen.

Die mitgelieferten Profile:

| Profil im Menü | Sprache / Grundlage |
| --- | --- |
| Project build settings | Vorhandene Build-Kommandos; Headerkontext wird daraus abgeleitet. |
| Linux C (GCC) | C; Standardpfade des installierten GCC werden abgefragt. |
| Linux C++ (G++) | C++; Standardpfade des installierten G++ werden abgefragt. |
| Amiga C | C; dein vorhandener Amiga-Include-Ordner. |
| Amiga NDK 3.5 · C | C; dein vorhandenes NDK-3.5-Verzeichnis. |
| C64 · Oscar64 C | C; dein vorhandenes Oscar64-Include-Verzeichnis. |

Die drei Retroprofile verwenden ihre eigenen SDK-Pfade und ignorieren die
Build-Flags des Wirtsprojekts. Implizite Linux-Standardheader werden dabei
ausgeschaltet. Passe bei Bedarf zusätzliche Projektpfade, Defines und den
Standard in `lua/plugins/clective.lua` an.

## Tasten

Alle folgenden Leader-Kombinationen gelten im Normalmodus.

| Tasten | Funktion |
| --- | --- |
| **Space K c** | Sprache und SDK gemeinsam für das Projekt auswählen. |
| **Space K b** | Abweichendes Profil nur für die aktuelle Datei auswählen. |
| **Space K i** | Aktiven Profilkontext einschließlich clangd-Kommando ansehen. |
| **Space K s** | Mit clangd zwischen passender Source- und Headerdatei wechseln. |
| **Space K r** | Pfade, Build-Daten und Compilerabfrage aktualisieren. |
| **Space K p** | Quelldateien des Projekts für clangd zur Indizierung anmelden. |
| **Space K w** | Projektsymbole mit Telescope suchen. |
| **Space K o** | Symbole der aktuellen Datei mit Telescope suchen. |
| **Space f i** | Header des aktuellen Profilkontexts durchsuchen. |
| **gf** auf einem Include | Den aufgelösten Header öffnen, sofern kein anderes Mapping `gf` belegt. |
| **gd** | Deine vorhandene Definitionensuche. |
| **gR** | Deine vorhandene Referenzsuche. |

Das **große K** ist bewusst gewählt. Dein kleines `Space k` und das einzelne
`K` haben bereits andere Aufgaben. Die neuen großen-K-Kombinationen wurden
mit den Belegungen der hochgeladenen Konfiguration abgeglichen.

Im Insertmodus innerhalb eines Includes bleiben deine Completion-Tasten:

- `Ctrl-J` / `Ctrl-K`: Vorschlag auswählen.
- `Enter`: ausgewählten Vorschlag übernehmen.
- `Ctrl-Space`: Vorschläge ausdrücklich anfordern.
- `Ctrl-E`: Vorschlagsliste schließen.

Bei `#include <exec/li>` wird daraus zum Beispiel
`#include <exec/libraries.h>`. Das Verzeichnis `exec/` bleibt erhalten.
Außerhalb von Includes stehen wieder deine normalen Completion-Quellen bereit.

## Beispiel ohne Amiga-Installation ausprobieren

Im ZIP liegt ein kleines C-Projekt mit zwei künstlichen SDKs. Es braucht keine
externen Bibliotheken. Die SDKs liefern absichtlich unterschiedliche Header.

In Neovim:

```vim
:luafile /ABSOLUTER/PFAD/clective.nvim/examples/demo/profile-setup.lua
```

Das öffnet `main.c` und aktiviert „Demo SDK A“ nur für das Demo-Projekt.
Die zusätzlich definierten Demo-Profile gelten für diese Neovim-Sitzung;
nach einem Neustart das Skript erneut laden.

1. Gehe auf `platform_value` in `main.c` und drücke `gd`.
   Die Definition liegt in `sdk-a/platform.h` und liefert `1`.
2. Kehre zu `main.c` zurück, wähle mit `Space K c` „Demo SDK B“
   und wiederhole `gd`. Jetzt liegt die Definition in `sdk-b/platform.h`
   und liefert `2`. clangd kann nach einem Profilwechsel einen Moment benötigen.
3. Tippe einen Include mit `exec/` und übernimm `exec/libraries.h`.
   Öffne ihn anschließend mit `gf`.
4. Öffne `shared.h`. Wähle **für diese Datei** mit `Space K b` „Demo C++“.
   `:set filetype?` zeigt `cpp`; die C++-Variante enthält die Klasse
   `demo::Example`. Mit `:ClectiveReset!` kehrst du zum Projektprofil zurück.
5. Zurück in `main.c`: `Space K p` drücken, kurz indizieren lassen,
   dann `Space K w` und nach `demo_unopened_symbol` suchen.
   Die Funktion liegt in `helper.c`, auch wenn du diese Datei noch nicht
   geöffnet hattest.
6. `Space K o` listet die Symbole der geöffneten Datei.
7. Optional `Space p p` für deine Docpair-Ansicht verwenden.

## Was clangd dabei leistet

Ja, wir behalten **clangd** als Language Server. Clective liefert ihm den
passenden Sprach- und Include-Kontext; clangd liefert Definitionen,
Referenzen, Typinformationen und Symbole. Dein realer Compiler bleibt
GCC, Amiga-Crosscompiler oder Oscar64.

Die Original-SDKs liegen nur auf deinem Rechner. Hier wurden die Pfadlogik und
Profilwechsel mit Test-SDKs und echtem clangd geprüft. Ob ein konkreter
Amiga-/Oscar64-Header wegen fremder Compilererweiterungen zusätzliche
Kompatibilitätsdefinitionen braucht, muss am tatsächlichen SDK geprüft werden.

Bei Problemen zuerst `Space K i`: Stimmen Projekt, Profil und Include-Pfade?
Steht dort mindestens ein verbundener clangd-Client? Werden Verzeichnisse als
fehlend gemeldet? Die Ansicht zeigt das konkrete Kommando, das Clective an
clangd übergibt. Bestehende `.clangd`-Regeln können dieses innerhalb von clangd
noch verändern.

Für große Projekte bleibt eine echte `compile_commands.json` die beste
Grundlage. `Space K p` ergänzt vor allem kleine Projekte ohne Build-Datenbank.

## Lokale Git-Historie

Das ZIP enthält zusätzlich `history/clective-history.bundle` mit dem
ursprünglichen Plugin und den Entwicklungscommits dieses Updates. Wenn du
daraus später ein eigenes Repository beginnen willst, kannst du im entpackten
Ordner separat klonen:

```sh
git clone history/clective-history.bundle ../clective-history
```

Für die Installation ist das nicht erforderlich. Kopiere dafür kein fremdes
`.git`-Verzeichnis in deine vorhandene Neovim-Konfiguration.
