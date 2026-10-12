// Preload-Shim für Qt: QScreen::refreshRate() meldet mindestens NISELLE_ANIM_HZ.
//
// Warum: Sind mehrere Fenster sichtbar (Leiste auf jedem Monitor, Übersicht …), treibt Qt Quick die Animationen
// mit einem Timer im Takt des *primären* QScreen (QSGThreadedRenderLoop::startOrStopAnimationTimer, Intervall
// = 1000 / primaryScreen()->refreshRate()). Unter Wayland ist das der erste wl_output – hier ein 60-Hz-Monitor –,
// also liefen Übersicht & Co. auch auf dem 144-Hz-Monitor nur mit 60 Bildern/s. Die „basic“-Renderschleife (Qt-Standard
// mit NVIDIA) hat dafür sogar fest 16 ms; bin/niselle schaltet deshalb zusätzlich auf die „threaded“-Schleife um.
//
// bin/niselle setzt NISELLE_ANIM_HZ auf die höchste Bildrate aller Monitore und lädt diese Bibliothek vor.
// Quickshell merkt sich die Umgebung beim Start und gibt sie an jedes gestartete Programm weiter; damit Apps weder den
// Shim noch QSG_RENDER_LOOP erben, filtert execve() diese Variablen heraus.
//
// Ohne Qt-Header: das Symbol ist `qreal QScreen::refreshRate() const` (Itanium-ABI, qreal = double).
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdlib.h>
#include <string.h>
#include <sys/syscall.h>
#include <unistd.h>

typedef double (*refresh_fn)(const void *);

static int scrub_children;
static int scrub_render_loop;

double _ZNK7QScreen11refreshRateEv(const void *self)
{
    static refresh_fn real;
    static double floor_hz = -1;
    // Erste Abfrage kommt aus dem Konstruktor der Renderschleife, also aus der Shell selbst (nicht aus
    // setsid & Co., die den Shim beim Start ebenfalls laden)
    if (floor_hz < 0) {
        real = (refresh_fn)dlsym(RTLD_NEXT, "_ZNK7QScreen11refreshRateEv");
        const char *env = getenv("NISELLE_ANIM_HZ");
        floor_hz = env ? atof(env) : 0;
        scrub_render_loop = getenv("NISELLE_CLEAR_RENDER_LOOP") != NULL;
        scrub_children = 1;
    }
    double hz = real ? real(self) : 60.0;
    return hz < floor_hz ? floor_hz : hz;
}

static int drop(const char *kv)
{
    if (!strncmp(kv, "NISELLE_ANIM_HZ=", 16) || !strncmp(kv, "NISELLE_CLEAR_RENDER_LOOP=", 26))
        return 1;
    if (!strncmp(kv, "LD_PRELOAD=", 11))
        return strstr(kv, "anim-refresh.so") && !strchr(kv + 11, ':') && !strchr(kv + 11, ' ');
    return scrub_render_loop && !strncmp(kv, "QSG_RENDER_LOOP=", 16);
}

// Läuft auch im vfork-Kind von QProcess: kein malloc, kein dlsym, nur Stack und Syscall
int execve(const char *path, char *const argv[], char *const envp[])
{
    if (!scrub_children || !envp)
        return syscall(SYS_execve, path, argv, envp);
    size_t n = 0;
    while (envp[n])
        n++;
    char *filtered[n + 1];
    size_t k = 0;
    for (size_t i = 0; i < n; i++)
        if (!drop(envp[i]))
            filtered[k++] = envp[i];
    filtered[k] = NULL;
    return syscall(SYS_execve, path, argv, filtered);
}
