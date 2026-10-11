# Niselle – Abhängigkeiten & empfohlene Anwendungen

Kuratierte Liste für Fedora (getestet auf Fedora 44, Hyprland/Wayland).
Paketnamen sind Fedora-`dnf`-Namen. „Erkennung“ = wie Niselle das Werkzeug nutzt:
zwingend (Start/Alltag), optional (Feature schaltet sich frei, wenn der Befehl
im `PATH` liegt), empfohlen (Companion, nicht Teil von Niselle).

## 1. Kern – zwingend

| Werkzeug | Paket | Wofür in Niselle |
|---|---|---|
| Quickshell (`qs`/`quickshell`) | `quickshell` | Laufzeit der Shell (`bin/niselle`, `shell.qml`) |
| Hyprland + `hyprctl` | `hyprland` | Compositor; Fenster, Monitore, Geräte, Cursorposition (`DisplayService`, `SwitcherService`, `ScreenshotService`, `OsdService`, `KeyboardService`) |
| Qt 6 | `qt6-qtbase`, `qt6-qtdeclarative`, `qt6-qtsvg`, `qt6-qtimageformats`, `qt6-qtwayland` | QML/Qt-Basis, SVG-Icons, Bildformate, Layer-Shell |
| bash | `bash` | Steuerskript `bin/niselle` |
| systemd | `systemd` | `busctl`, `systemd-inhibit` (Koffein), logind (Sperre/Standby), `timedatectl`, `hostnamectl`, `systemd-detect-virt` |
| glib2 | `glib2` | `gio mime` (Standard-Apps), `gsettings` (GTK-Sync) |
| glibc | `glibc` | `getent` (Benutzername in Lock/Polkit) |
| util-linux | `util-linux` | `lsblk` (Datenträger im „Info“-Panel) |
| pciutils | `pciutils` | `lspci` (GPU im „Info“-Panel) |
| fontconfig | `fontconfig` | `fc-list` (Schrift-Seite) |
| xdg-utils | `xdg-utils` | `xdg-open` (Suchergebnisse), `xdg-user-dir` |
| xdg-user-dirs | `xdg-user-dirs` | Bilderordner für Screenshots/Wallpaper |
| libnotify | `libnotify` | `notify-send` (Screenshots, Benachrichtigungen) |
| polkit | `polkit` | `PolkitDialog` für Systemanfragen |
| NetworkManager | `NetworkManager` | `nmcli` (Netzwerk-Service) |
| PipeWire + WirePlumber | `pipewire`, `wireplumber` | `wpctl` (Lautstärke), `pw-cli` (Mikrofon-Sperre) |
| bluez | `bluez` | Bluetooth-Status im Quick-Settings/Schalter |
| upower | `upower` | Akku-/Energieanzeige |
| D-Bus | `dbus` (via `dbus-broker`/`dbus-daemon`) | `dbus-monitor` (Sperre/Standby), `busctl` |
| Adwaita-Icons | `adwaita-icon-theme` (+ `adwaita-icon-theme-legacy`) | Standard-Icon-Theme der Shell |
| Adwaita-Schriften | `adwaita-sans-fonts`, `adwaita-mono-fonts` | `Theme.fontFamily`/`fontFamilyMono` (Fallback Cantarell/Monospace) |
| Wayland-Session | — | läuft nur in einer Wayland-Sitzung (Hyprland) |

## 2. Optionale Integrationen

Diese Werkzeuge werden per `command -v` erkannt. Fehlen sie, bleibt das Feature
still aus; sind sie da, aktiviert es sich von selbst.

| Befehl | Paket | Aktiviert |
|---|---|---|
| `awww` | `awww` | Hintergrundbild (`WallpaperService`, Wallhaven, Appearance) |
| `matugen` | `matugen` | Material-You-Farbpalette aus dem Wallpaper (`MatugenService`) |
| `cliphist` | `cliphist` | Verlauf (`ClipboardService`, Zwischenablage-Fenster Super+V) |
| `wl-copy` / `wl-paste` | `wl-clipboard` | Kopieren/Einfügen + Verlaufs-Hook |
| `grim` | `grim` | Bildschirmfotos (`ScreenshotService`) |
| `wf-recorder` | `wf-recorder` | Bildschirmaufnahme (erste Wahl) |
| `wl-screenrec` | `wl-screenrec` | Bildschirmaufnahme (Alternative) |
| `gpu-screen-recorder` | `gpu-screen-recorder` | Bildschirmaufnahme (GPU) |
| `parec` + `python3` | `pulseaudio-utils`, `python3` | Audio-Visualizer in der Menüleiste (`bin/niselle-audio-bands`) |
| `ffmpeg` | `ffmpeg-free` | Video-Standbilder in der Zwischenablage |
| `brightnessctl` | `brightnessctl` | Helligkeit (intern, Tastatur-LEDs) |
| `ddcutil` | `ddcutil` | Helligkeit externer Monitore (DDC/CI) |
| `rfkill` | `rfkill` | Funkschalter (WLAN/Bluetooth-Sperre) |
| `khal` | `khal` | Kalendertermine im Datum-Menü (`EventsService`) |
| `orca` | `orca` | Bildschirmleser (`AccessibilityService`) |
| `hyprsunset` | `hyprsunset` | Nachtlicht (bevorzugt) |
| `wlsunset` | `wlsunset` | Nachtlicht (Fallback, wenn hyprsunset fehlt) |
| `boltctl` | `bolt` | Thunderbolt-Geräteschutz (`PrivacyService`) |
| `tinysparql` | `tinysparql` (+ `localsearch`) | Dateisuche in der Übersicht |
| `playerctl` | `playerctl` | MPRIS-Steuerung per CLI (Niselle nutzt sonst D-Bus direkt) |
| `curl` | `curl` | Wetter (Open-Meteo) + Wallhaven |
| `tuned` / `tuned-ppd` | `tuned`, `tuned-ppd` | Energiemodi (sonst `power-profiles-daemon`) |
| `xdg-terminal-exec` | `xdg-terminal-exec` | „Im Terminal öffnen“ (sonst `$TERMINAL`, dann Kitty/foot/…) |
| `pavucontrol` | `pavucontrol` | Audio-Einrichtung aus den Schnelleinstellungen |
| `gsettings` | `glib2` | GTK-Theme/Schriften/Icons synchronisieren |

Fehlende Aufnahme-Tools vs. Foto: Fotos brauchen nur `grim`; für Video reicht
**eines** von `wf-recorder` / `wl-screenrec` / `gpu-screen-recorder`.

## 3. Empfohlene Anwendungen (Companions)

Nicht Teil von Niselle, aber passend zu den Standard-App-Kategorien
(`DefaultAppsService`: Web, Mail, Kalender, Dateien, Text, Dokumente, Musik,
Video, Fotos).

### Bilder, Video, Dokumente
| Zweck | Paket | Hinweis |
|---|---|---|
| Bildbetrachter | `imv` | bereits als Standard für jpg/png/webp/gif registriert |
| Bildbetrachter (GTK) | `loupe` | GNOME-Alternative |
| Bildbetrachter (Keyboard) | `swayimg` | leicht, skriptbar |
| Videoplayer | `mpv` | Standard für Video-MIME-Typen |
| mpv + Media-Tasten | `mpv-mpris` | lässt mpv in Quick-Settings/MPRIS erscheinen |
| Video-Download | `yt-dlp` | mit mpv kombinierbar |
| Video (GTK) | `celluloid` | GTK-Frontend für mpv |
| PDF | `zathura`, `zathura-pdf-poppler` | Dokumente-Kategorie |
| PDF/Dokumente (GNOME) | `papers` | moderne Alternative zu Evince |
| Musik | `amberol` oder `lollypop` | Musik-Kategorie |

### Screenshots & Aufnahme
| Zweck | Paket |
|---|---|
| Screenshot (Basis) | `grim` (Teil von Niselle) |
| Screenshot annotieren | `satty` oder `swappy` |
| Aufnahme | `wf-recorder` / `wl-screenrec` / `gpu-screen-recorder` |
| Verlauf/Clipboard | `cliphist`, `wl-clipboard` |

### Dateien, System, Hardware
| Zweck | Paket |
|---|---|
| Dateimanager | `nautilus` (eingestellt) |
| Vorschaubilder | `ffmpegthumbnailer` (Nautilus), `ffmpeg-free` |
| Archive | `file-roller` |
| Datenträger | `gnome-disk-utility` |
| Systemmonitor (GUI) | `mission-center` |
| Systemmonitor (TUI) | `btop` (Config vorhanden), `nvtop` |
| Sensoren | `lm_sensors` |

### Audio, Bluetooth, Energie
| Zweck | Paket |
|---|---|
| Lautstärke-Mixer | `pavucontrol`, `pwvucontrol` |
| Effekte | `easyeffects` |
| Patchbay | `helvum` oder `qpwgraph` |
| Bluetooth | `blueman` |
| Energieprofile | `tuned`, `tuned-ppd` oder `power-profiles-daemon` |

### Hyprland-Ökosystem & Launcher
| Zweck | Paket |
|---|---|
| Farbpicker | `hyprpicker` |
| Screenshot/Session | `grim`, `slurp` (Legacy), `wlogout` |
| Launcher | `fuzzel`, `wofi`, `rofi` |
| Sperre/Idle | `hyprlock`, `hypridle` (Niselle-eigene Sperre ist in `modules/lock`) |
| Wallpaper | `awww` (+ `matugen`) |

### Terminal / Kommandozeile
| Zweck | Paket | Befehl |
|---|---|---|
| Terminal | `kitty` (eingestellt) | `kitty` |
| JSON | `jq`, `yq` | `jq`, `yq` |
| Suchen | `ripgrep`, `fd-find` | `rg`, `fd` |
| Anzeigen | `eza`, `bat` | `eza`, `bat` |
| Fuzzy | `fzf` | `fzf` |
| Navigation | `zoxide`, `atuin` | `z`, `atuin` |
| Prompt | `starship` | — |
| Umgebung | `direnv` | — |
| Editor | `neovim`, `git` | — |

## 4. Installation (Fedora)

```bash
# Kern
sudo dnf install quickshell hyprland qt6-qtbase qt6-qtdeclarative qt6-qtsvg \
  qt6-qtimageformats qt6-qtwayland glib2 glibc util-linux pciutils fontconfig \
  xdg-utils xdg-user-dirs libnotify polkit NetworkManager pipewire wireplumber \
  bluez upower adwaita-icon-theme adwaita-sans-fonts adwaita-mono-fonts

# Optionale Integrationen
sudo dnf install awww matugen cliphist wl-clipboard grim wf-recorder \
  gpu-screen-recorder ffmpeg-free brightnessctl ddcutil rfkill khal orca \
  hyprsunset bolt tinysparql localsearch playerctl curl tuned tuned-ppd \
  xdg-terminal-exec pavucontrol

# Empfohlene Companions
sudo dnf install imv mpv mpv-mpris yt-dlp zathura zathura-pdf-poppler papers \
  amberol satty ffmpegthumbnailer file-roller gnome-disk-utility mission-center \
  btop nvtop lm_sensors pavucontrol easyeffects helvum blueman hyprpicker \
  fuzzel wofi kitty
```

## 5. Diagnose

```bash
niselle doctor      # Quickshell, Wayland, Konfigpfad, Hyprland
niselle log         # Start-Log ~/.local/state/niselle/start.log
```
