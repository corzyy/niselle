# Niselle

Quickshell-Konfiguration (GNOME-Shell-Klon, QML / Qt 6 / Wayland layer-shell) für Hyprland.
Gesteuert über das Skript `bin/niselle` (Symlink: `~/.local/bin/niselle`), das Quickshell-IPC nutzt.

## Struktur
| Pfad | Inhalt |
|---|---|
| `shell.qml` | Einstieg (`ShellRoot`): Bindings, Variants je Monitor, LazyLoader |
| `Theme.qml` | Singleton: Farben, Maße, Bewegung (Quellen: `docs/sources/`) |
| `services/` | Singletons (Logik/Systemanbindung: Netzwerk, Audio, Einstellungen, IPC …) |
| `modules/` | UI-Module (topbar, overview, dash, datemenu, lock, osd, notifications, settings, polkit, desktop) |
| `components/` | Wiederverwendbare Widgets (Button, Slider, PopupMenu …) |
| `dev/` | Entwicklungshilfen (Gallery, ServiceDebug) |
| `assets/` | Icons, Matugen-Farbvorlage |
| `docs/sources/` | Referenzquellen aus gnome-shell/libadwaita (nur Lesematerial, siehe dortige README) |
| `bin/niselle` | CLI: start/stop/restart/status/overview/apps/screenshot/settings/theme/config/ipc/log/doctor |

## Betrieb
- Autostart: `hyprland` ruft `niselle start` (`~/.config/hypr/configs/autostart.lua`).
- Start-Log: `~/.local/state/niselle/start.log` (`niselle log`), Diagnose: `niselle doctor`.
- Umgebung: `NISELLE_CONFIG` (Konfigpfad), `NISELLE_QS` (quickshell-Binary), `QT_FONT_DPI` (Default 96).

## Neues Modul/Service ergänzen
1. QML-Datei in `modules/<name>/` bzw. `services/` anlegen (Services als `pragma Singleton`).
2. Modul in `shell.qml` importieren und instanziieren (`Variants` je Monitor oder `LazyLoader`).
3. `niselle restart` und `niselle log` prüfen.

## Backup / Restore
Git-Historie in diesem Verzeichnis; Baseline-Commit „Baseline vor Aufräumen“.
Zusätzlich Tarball: `~/shell-backup-20261011/kyro-20261011.tar.gz` (Anleitung: `RESTORE.txt` dort).

    git checkout <commit> -- .          # einzelne/alle Dateien zurückholen
    niselle stop; tar xzf ~/shell-backup-20261011/kyro-20261011.tar.gz -C ~/.config/ownqs; niselle start

Siehe `CHANGELOG.md`.
