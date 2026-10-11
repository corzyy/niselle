# Änderungs-Log

## 2026-10-11 – Menüleiste frei anordnen
- Einstellungen › Menu Bar: Neuer Editor (`BarLayoutEditor`) mit Vorschau in drei Zonen (links, Mitte, rechts) und Ablage „Hidden“. Element anklicken, dann per ◀ ▶ umsortieren, mit Klick auf eine Zone dorthin verschieben oder ausblenden; „Reset“ stellt die Standardanordnung her. Die Systempille (Quick-Settings) ist Pflicht und wird bei Bedarf rechts ergänzt.
- Die Leiste (`TopBar.qml`) baut ihre Zonen aus `SettingsService.barLayout` (Loader je Element) statt aus festen Reihen. Neu wählbar: Barrierefreiheit-Menü, Aufnahme-Anzeige und Tastaturlayout frei platzierbar.
- Neue Optionen: Uhr (Datum & Zeit / Zeit / Datum), Arbeitsflächen als Punkte oder Zahlen, aktive App mit/ohne Symbol und Name, Symbole der Systempille einzeln (Netzwerk, Bluetooth, Lautstärke, Akku-Prozent). `PrefGroup` hat dafür `boxed: false`.
- Neue Elemente: **Audio Visualizer** (Balken zum Spektrum des Systemtons; `bin/niselle-audio-bands` liest über `parec` den Monitor des Standard-Ausgangs und rechnet Goertzel-Bänder, 8/12/16 Balken; der Prozess läuft nur, solange ein Spieler spielt) und **Media Player** (Titel – Künstler in der Leiste, Klick öffnet ein großes Fenster mit Cover, Spulleiste, Zurück/Pause/Weiter; Mittelklick = Pause). Beide sind standardmäßig ausgeblendet.
- Neues Element **Updates** (`UpdateService`, `UpdateButton`): bleibt unsichtbar, bis `dnf5 repoquery --upgrades` Aktualisierungen findet (Prüfung ohne Rechte, 20 s nach dem Start und danach alle 1–24 h, einstellbar). Klick öffnet ein Fenster mit Paketliste; „Install“ startet `pkexec dnf5 upgrade -y`, die Anmeldung übernimmt Polkit über den Agenten der Shell. Fortschritt, Ergebnis und Fehler (letzte Ausgabezeilen) erscheinen im Fenster; ein abgebrochener Dialog (pkexec 126/127) setzt es still zurück. Ohne `dnf5` bleibt das Element aus.
- Neues Element **Vitals** (`VitalsService`, `VitalsButton`): CPU-Last, RAM, CPU-Temperatur und Netzwerkdurchsatz in der Leiste (einzeln wählbar); Klick zeigt Balken für CPU/Speicher/Swap/Temperatur, Durchsatz, Systemlast und Laufzeit. Gemessen wird nur, solange das Element platziert ist.
- Die Anordnung (`barLayout`) und alle Leisten-Optionen liegen in `settings.json` und bleiben über Neustarts erhalten.
- Entfernt: `showActiveWindow` und `showAccessibilityMenu` – ob ein Element sichtbar ist, bestimmt jetzt die Anordnung. Das Barrierefreiheit-Menü ist standardmäßig ausgeblendet (wie bisher); wer es an hatte, fügt es im Editor wieder hinzu.

## 2026-10-11 – Übersicht: Arbeitsflächen nahtlos
- Fensterbereich: Jede Fläche des Karussells ist jetzt eine `WorkspacePage` mit demselben Fenster-Layout wie die aktive. Vorher zeigten die Nachbarn die Fenster in echter Monitorlage; beim Wechsel sprangen die Fenster der alten Fläche vom Layout in diese Lage und die Vorschauen der neuen Fläche entstanden neu (Logo-Blitz vor dem Standbild). Jetzt gleiten Seiten samt Fenstern unverändert, Klick wechselt dorthin, ein Fenster darauf ablegen verschiebt es (Hervorhebung beim Ziehen).
- Neues `WorkspaceModel`: Flächen werden über ihre ID geführt (nicht über ihre Position). Entsteht oder verschwindet eine Fläche, behalten alle anderen Seiten/Vorschauen ihr Delegate samt Aufnahmen; die neue wächst ein, die entfernte blendet aus und die übrigen rücken weich nach. Alle Bewegungen laufen auf derselben Kurve, die aktive Fläche springt dabei nie.
- Arbeitsflächen-Leiste: Vorschauen gleiten bei Umbau an ihren Platz (Größe und Zentrierung folgen der Anzahl), statt zu springen; der Rahmen der aktiven Fläche folgt derselben Position.
- Öffnen: Das App-Symbol auf der Fensterkachel blendet nach kurzer Haltezeit weich aus, sobald das Standbild da ist (stand vorher ~0,6 s über dem Fenster). Hinweis: Standbilder schon beim Öffnen anzufordern wurde ausprobiert und verworfen – die Screencopy-Einrichtung blockiert den Renderthread 100 ms und länger, die Öffnungsanimation startet dann sichtbar verzögert und läuft zum großen Teil unbemerkt ab; sie bleiben bei „nach der Animation“.
- Öffnen: Die Animation war kaum zu sehen. Gemessen: das Anlegen der Layer-Fläche beim Öffnen dauerte ~190 ms bis zum ersten Bild, dazu kam ein schwerer erster Frame von ~100 ms; die Uhr-Animation (260 ms) war danach fast durch und die Übersicht sprang auf. Jetzt (1) bleibt die Layer-Fläche leer eingebunden (`Overview.qml`, mit 1-px-Eingabebereich; nicht bei Vollbild auf dem Monitor und im Gamemode, damit Scanout möglich bleibt): erstes Bild nach ~3 ms; (2) läuft der Fortschritt bildgetrieben (`FrameAnimation` in `OverviewService`, höchstens 22 ms je Bild): ein Aussetzer verlängert die Animation, statt sie zu verschlucken.

## 2026-10-11 – Fehlersuche: Nachtlicht, Displays, Aufnahme, Start
- Nachtlicht: „Sonnenuntergang bis -aufgang“ wertete den Zeitplan nie aus und lief fest von 20 bis 6 Uhr; jetzt wird Auf-/Untergang am Wetterort berechnet (manueller Zeitplan unverändert).
- Start: die Leiste (und damit jedes `quicksettings.<Monitor>`/`datemenu.<Monitor>`-IPC-Ziel) entstand erst auf dem falschen Monitor und wurde nach dem Laden der Einstellungen neu gebaut; `OverviewService.primaryScreen` wartet jetzt auf DisplayService und Einstellungen (keine doppelten IpcHandler mehr).
- Displays: Ohne Lua-Konfiguration wurden Drehung, VRR und Spiegeln als ungültige `hyprctl keyword monitor`-Regeln gesendet (jetzt eine Regel). Das gespeicherte Layout wird nach Monitor-Hotplug und Neuladen der Hyprland-Konfiguration erneut angewendet. Schließt man die Einstellungen während der „Keep Changes?“-Rückfrage, wird zurückgesetzt statt die neue Konfiguration stehen zu lassen.
- Aufnahme: gpu-screen-recorder bekam bei Monitoren links/oberhalb des Ursprungs eine ungültige Region (`+-1920`); die Anzeige „Aufnahme läuft“ wartete im Leerlauf bis zu 5 s (jetzt Nachfrage 0,7 s nach Start/Stopp, sonst konnte man eine zweite Aufnahme starten).
- Bluetooth: ungekoppelte Geräte im Quick-Settings-Menü („Koppeln“) werden jetzt wirklich gekoppelt statt nur verbunden.
- Zwischenablage: „Verlauf löschen“ entfernt auch die zwischengespeicherten Bild-/Videovorschauen. Suche: Trefferüberschriften (Zwischenablage, Fenstertitel) werden als reiner Text angezeigt statt als HTML.

## 2026-10-11 – Fehler- und Politur-Durchgang (Abstände, Animationen, Logik)
- Quick-Settings: der zweite Modus „Benachrichtigungen aufklappen“ ist entfernt (samt `expandT`/Übergang, runder Schalterreihe, `NotificationPreview.qml` und IPC `quicksettings.<Monitor> notifications`). Die Hauptseite zeigt unter den Kacheln direkt die volle Liste (`MessageList`, eingebettet): Medienkarten, Gruppen auf-/zuklappen, einzeln verwerfen, „Leeren“. Die Höhe der Liste füllt den Rest bis zum Bildschirmrand (`Theme.quickSettingsMin/MaxListHeight`); ohne Inhalt fehlt der Abschnitt.
- Benachrichtigungen: `Array.sort()` ist in der QML-Engine nicht stabil und mischte die Reihenfolge gleichrangiger Meldungen/Gruppen (oben stand eine alte statt der neuesten). Gruppen (`NotificationGroup`, `MessageList`) und Banner-Warteschlange (`NotificationService`) ordnen jetzt stabil per `filter`/`concat`.
- Übersicht: Such-Overlay folgt dem Ziel (`searchActive`) statt `searchProgress > 0` – beim Schließen blendete das Panel vorher nicht aus, sondern verschwand abrupt; Überschwingen nur beim Öffnen. `AppGrid.dragOverlay` bezog sich auf sich selbst (Binding-Schleife) und fiel auf die lokale Ziehebene zurück; jetzt über `Overview.dragOverlayItem`.
- App-Grid: dieselbe Ordner-ID doppelt in einer Seite (Altlast aus dem Ordner-Anlegen) erzeugte zwei gleiche Ordner-Kacheln; `_buildLayout`/`pages` prüfen jetzt nacheinander statt mit `filter` + `forEach`. Weg-fliegendes Icon beachtet „Weniger Bewegung“.
- Einstellungen: Seiten **Notifications** (Nicht stören, Alle löschen) und **Privacy & Security** (Datenschutz-Anzeigen, Sperre, Zwischenablage) – die Seitenleisten-Einträge öffneten vorher eine leere Seite. Font: Suchfeld füllte nur die halbe Breite. Mouse: „Primary Button“ ist ein `SegmentedRow` (die Auswahl wirkte vertauscht). Lockscreen-Vorschau rechnet mit der echten Auflösung des Hauptbildschirms; die Uhr war oben abgeschnitten.
- Suche: Anbieter-Symbole (Rechner, Befehle, Dateien, Einstellungen) sind jetzt symbolisch – das nicht-symbolische Papirus-Symbol wurde als weißes Quadrat eingefärbt.
- `MediaService`: Binding-Schleife an `player` (Qt.callLater) und „Unable to assign [undefined] to QString“ beseitigt.
- Suche: lange Treffer (z. B. Zwischenablage) werden mit „…“ gekürzt statt am Panelrand hart abgeschnitten; das Such-Panel passt seine Höhe den Treffern an (die Mindesthöhe gilt nur noch für „Keine Ergebnisse“, vorher blieb unter einem Rechner-Ergebnis leere Fläche).
- Einstellungen › Displays: die Anordnungsvorschau baute beim Ziehen alle Monitor-Kacheln neu (Repeater-Modell aus Objekten) und brach den Zug nach dem ersten Schritt ab; das Modell besteht jetzt nur aus den Namen.
- `NetworkService.setScanning(on, owner)`: WLAN-Suche je Anforderer (Quick-Settings-Menü, Netzwerk-Einstellungen), damit sich beide nicht gegenseitig abschalten. Quick-Settings: ohne Benachrichtigungen entfällt unter der Medienkarte die leere Steuerzeile; die reservierte Fensterhöhe bleibt innerhalb des Bildschirms.

## 2026-10-11 – Aufnahme als runder Knopf in der Quick-Settings-Kopfzeile
- Quick-Settings: die Kachel „Aufnahme“ aus dem Raster entfernt; Bildschirmfoto/Aufnahme sitzt jetzt als runder Knopf (`IconButton`, `ScreenshotItem` aus dem GNOME-Mockup) in der Kopfzeile neben Bearbeiten/Einstellungen. Ein Klick öffnet die gemeinsame Oberfläche; läuft eine Aufnahme, zeigt der Knopf das Aufnahmesymbol und der Klick beendet sie.
- `SettingsService.defaultQuickToggles` ohne `screenshot`; die Kachel-ID entfällt.

## 2026-10-11 – Live-Fenstervorschauen in der Übersicht
- Übersicht: Fenster-Kacheln (`WindowPreview`) und Arbeitsflächen-Miniaturen (`WorkspaceThumbnail`) zeigen die Fenster jetzt live (`ScreencopyView` mit `live: true`) statt eines einzelnen Standbilds. Der Stream läuft nur, solange die Übersicht sichtbar ist (`OverviewService.captureArmed`).
- Neue Einstellung `overviewLiveWindows` (Standard an) unter Einstellungen › Erscheinungsbild › Übersicht; abschaltbar, um CPU/GPU zu sparen (`niselle config set overviewLiveWindows false`).

## 2026-10-11 – Bildschirmfoto- und Bildschirmaufnahme-Kachel zusammengeführt
- Quick-Settings: die getrennten Kacheln „Bildschirmfoto“ und „Bildschirmaufnahme“ sind jetzt eine Kachel „Aufnahme“. Ein Klick öffnet die gemeinsame Oberfläche (Foto/Aufnahme dort umschaltbar); läuft eine Aufnahme, zeigt die Kachel Dauer und Aufnahmesymbol, und der Klick beendet sie. Kachel-ID `screenRecording` entfällt.

## 2026-10-11 – Zurück-Knopf bei Monitor-Unterseiten; „nicht implementiert“-Seite entfernt
- `SettingsWindow`: `parentPanelFor()` löst die übergeordnete Seite auf – „displays/monitor/<name>“ führt jetzt zurück zu „displays“ statt zur nicht existierenden Zwischenseite „displays/monitor“.
- Die Fallback-Seite „This panel has not been implemented yet“ (`StatusPage`) samt Datei entfernt.
- Neu: „Make Primary“-Knopf – auf der Displays-Seite für die ausgewählte Anzeige und auf jeder Monitor-Unterseite.

## 2026-10-11 – Anzeigen-Seite (Displays) wie GNOME Settings
- Neu: `services/DisplayService.qml` – liest die Monitore (`hyprctl -j monitors all`: Auflösungen, Bildwiederholraten, Skalierung, Drehung, Position, VRR, Farbmodus), hält einen Entwurf und wendet ihn per Lua-`hl.monitor` (Hyprland ≥ 0.55) bzw. klassischem `keyword monitor` an. Unterstützte Skalierungen nach dem Mutter-Algorithmus.
- `modules/settings/pages/DisplaysPage.qml` neu: „Multiple Displays“ (Erweitern/Spiegeln, `SegmentedRow`), ziehbare Anordnungsvorschau (`components/DisplayArrangement.qml` mit Einrasten), „Primary Display“, Monitorliste mit Nummern-Kennzeichen und Unterseite je Monitor sowie Einstieg ins Nachtlicht. „Abbrechen/Übernehmen“-Leiste über `SettingsWindow` bei ausstehenden Änderungen; nach dem Übernehmen „Keep Changes?“-Dialog mit 20 s Countdown und Zurücksetzen.
- `modules/settings/DisplaySettingsList.qml` (CcDisplaySettings): Drehung, Auflösung, Bildwiederholrate, variable Bildwiederholrate, HDR und Skalierung – direkt auf der Seite (ein Monitor/Spiegeln) oder auf der Monitor-Unterseite (`pages/MonitorSettingsPage.qml`).
- Neu: `modules/settings/pages/NightLightPage.qml` – Schalter, Zeitplan (Sonnenunter-/-aufgang oder manuell), Zeiten von/bis und Farbtemperatur (1.700–4.700 K). `SettingsService`: neue Schlüssel `primaryDisplay`, `displays`, `nightLightSchedule`, `nightLightFrom`, `nightLightTo`; Nachtlicht läuft nur im Zeitfenster (`nightLightActive`).
- `Theme.primaryScreenName` ist jetzt schreibbar und in `shell.qml` an `DisplayService.primaryName` gebunden (Leiste/Dash folgen der gewählten Primäranzeige). `ActionRow` um ein Nummern-Kennzeichen (`badge`) erweitert, `Button` um `primary` (suggested-action). `settings open displays/nightlight`, `displays/monitor/<name>`.

## 2026-10-11 – Auswahlfelder in den Einstellungen als Libadwaita-Dropdown
- `modules/settings/ChoiceRow.qml`: Die Segment-Auswahl am Zeilenende ist jetzt ein Dropdown im Stil von `AdwComboRow`/`GtkDropDown` – rechts ein Knopf mit dem aktuellen Wert und Pfeil, ein Klick öffnet ein Popover mit allen Werten (Häkchen am gewählten). Betrifft Power, Dock, Font und Calendar.

## 2026-10-11 – Zwischenablage als Fenster am Mauszeiger, Bilder und Medien
- Neu: `modules/clipboard/ClipboardPopup.qml` – Verlauf als eigenes Fenster am Mauszeiger (`niselle clipboard`, Super+V; Position per `hyprctl cursorpos`, weicht an den Rand aus). Tippen filtert, Pfeile wählen, Enter kopiert, Entf/✕ löscht, Esc/Klick daneben schließt.
- `ClipboardService`: Eintragsarten text, image (Vorschau aus `cliphist decode`) und files (kopierte Dateien: Bilder zeigen sich selbst, Videos ein Standbild per ffmpeg). Vorschauen im Cache `Quickshell.cachePath("clipboard")`, veraltete werden aufgeräumt. Zurückkopieren setzt den MIME-Typ (image/*, text/uri-list).

## 2026-10-11 – Alt+Tab, Koffein, Leerlauf-Sperre/-Standby, Such-Anbieter, Zwischenablage
- Neu: `services/SwitcherService.qml` + `modules/switcher/Switcher.qml` – Alt+Tab-Umschalter (Apps, zuletzt benutzte zuerst; Alt+` = Fenster der App). Loslassen der Modifikatortaste aktiviert, Esc bricht ab. Fensterliste aus `hyprctl clients`. `niselle switcher next|prev|window|close`.
- Neu: `services/IdleService.qml` – Sperren/Standby nach Leerlauf (`IdleMonitor`), Koffein (`niselle caffeine on|off|toggle`, Quick-Settings-Kachel, `systemd-inhibit --what=idle`), Sperren vor dem Standby (`SessionService.suspend`, logind `PrepareForSleep`). Standard: Sperren nach 5 min an, Standby aus.
- Neu: Einstellungen › Power (`PowerPage`: Energiemodus, Sperren/Standby, Koffein) und Search (`SearchPage`: Anbieter ein-/ausschalten, Zwischenablage).
- Suche: neue Anbieter `windows` (offene Fenster), `actions` (Sperren, Standby, Abmelden, Koffein, Nicht stören, …) und `clipboard` (nur mit Vorsatz „clip“/„cb“). `niselle clipboard`, `niselle search <text>`, `niselle suspend`.
- Neu: `services/ClipboardService.qml` – `wl-paste --watch cliphist store` (Text, Bilder), Verlauf per `cliphist list`.
- Hyprland: `ALT+Tab`, `ALT+SHIFT+Tab`, `ALT+grave`, `SUPER+V` (Verlauf), `SUPER+L` (Sperren) in `binds.lua`; auch in `KeybindService` änderbar.

## 2026-10-11 – Icon-Seite (Appearance › Icons)
- Neu: `modules/settings/pages/IconPage.qml` – listet installierte Icon-Themes (`index.theme` in /usr/share/icons, ~/.local/share/icons, ~/.icons). Auswahl wird nach `~/.local/state/niselle/icon-theme` geschrieben, per `gsettings` an GTK gegeben und die Shell neu gestartet (Quickshell liest das Theme nur beim Start).
- `bin/niselle start` setzt `QS_ICON_THEME` aus dieser Datei; Eintrag in `AppearancePage`, Panel `appearance/icons` und Suchtreffer in `SettingsPanelsService`.

## 2026-10-11 – Schrift-Seite (Appearance › Font)
- Neu: `modules/settings/pages/FontPage.qml` – alle installierten Familien (`fc-list`) nach Sans-serif/Serif/Monospace/Symbols, mit Suche und Vorschau. Auswahl gilt für alles, nur die Oberfläche oder nur Monospace; „Reset“ stellt Adwaita Sans/Mono wieder her.
- `SettingsService`: neue Schlüssel `fontFamily`, `fontFamilyMono`; `Theme.fontOverride`/`fontMonoOverride` (in `shell.qml` gebunden) überschreiben `Theme.fontFamily`/`fontFamilyMono`.
- Gibt die Auswahl best effort per `gsettings` (font-name, document-font-name, monospace-font-name) an GTK weiter.
- Eintrag in `AppearancePage` unter „Colours“, Panel `appearance/font` und Suchtreffer in `SettingsPanelsService`.

## 2026-10-11 – Bildschirmfoto-/Aufnahme-Oberfläche wie GNOME
- Neu: `services/ScreenshotService.qml` (Zustand, Fensterliste per `hyprctl`, Aufnahme mit `grim`, IPC-Ziel `screenshot`) und `modules/screenshot/` (Overlay je Monitor, Bedienfeld, Fenstervorschau). Maße und Farben aus `gnome-shell-dark.css`, Icons aus `gnome-shell-icons.gresource` (`assets/icons/screenshot-ui-*`).
- Modi: Bereich (Eckgriffe, verschieben/skalieren), Bildschirm (Klick wählt Monitor), Fenster (Vorschauen per ScreencopyView, Klick wählt). Foto/Aufnahme-Schalter, Mauszeiger-Schalter, Auslöser; Esc schließt, Enter/Leertaste löst aus.
- Foto: `grim -g`, Datei im XDG-Bilderordner (`xdg-user-dir PICTURES`), Videos im XDG-Videoordner, jeweils ohne Unterordner, Zwischenablage (`wl-copy`) und Benachrichtigung (`notify-send`). `slurp` wird nicht mehr gebraucht; Aufnahme übergibt den Bereich direkt an `wf-recorder`/`wl-screenrec`.
- `bin/niselle`: neuer Befehl `niselle screenshot [record|close]`. Quick-Settings-Kachel und `SessionService.screenshot()` öffnen die Oberfläche. `KeybindService`: `Print` → `niselle screenshot`, neu `CTRL+SHIFT+ALT+R` → `niselle screenshot record`.

## 2026-10-11 – Audit/Aufräumen
- Backup: `~/shell-backup-20261011/` (Tarball + RESTORE.txt) und git-Repo mit Baseline-Commit.
- `bin/niselle`: `usage()` um `lock` ergänzt, `apps`-Beschreibung angeglichen an Kopfkommentar. Rückgängig: `git revert`.
- Neu: `README.md`, `CHANGELOG.md`, `.gitignore`.
- Gelöscht: `modules/topbar/ScreenCorners.qml` (nirgends instanziiert; `Theme.screenCornerRadius` bleibt).
- `services/DdcDisplay.qml`: `Item` -> `Scope` (Parent ist ein Singleton, kein Item) – behebt „not placed in the graphics scene“.
- `modules/topbar/QuickSettingsButton.qml:77`: `!!NetworkService.available` – behebt „Unable to assign [undefined] to bool“.
- `bin/niselle`: shellcheck SC2155 behoben (export getrennt von Zuweisung); shellcheck sauber.
- Offen: `../kyro.bak` und `../karu` (Entscheidung steht aus).

Rückgängig: `git revert <commit>` oder Baseline `57fb51b`.
