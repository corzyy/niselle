# Quellen für Theme.qml

Abgerufen am 2026-10-09. Zeilenangaben in `Theme.qml` und `components/*.qml` beziehen sich auf diese Dateien.

- `_*.scss`: gnome-shell `data/theme/gnome-shell-sass` (main, letzter Theme-Commit 90f34071cd7a vom 2026-09-21)
- `_dash.scss`, `_app-grid.scss`: gnome-shell `data/theme/gnome-shell-sass/widgets` (main); `appMenu.js`, `iconGrid.js`: `js/ui`
- `*.js`: gnome-shell `js/ui` (main), `st-*.c`: gnome-shell `src/st` (main)
- `libadwaita-1.9.4-gtk.css`: aus `/usr/lib64/libadwaita-1.so.0` extrahiert
  (`gresource extract … /org/gnome/Adwaita/styles/gtk.css`)
