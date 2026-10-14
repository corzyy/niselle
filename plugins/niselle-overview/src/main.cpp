
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/devices/IPointer.hpp>
#include <hyprland/src/ipc/s2/S2.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#include <hyprland/src/helpers/memory/Memory.hpp>
#include <hyprland/src/SharedDefs.hpp>
#include <hyprland/src/version.h>

#include <string>


static HANDLE PHANDLE = nullptr;

static bool g_overviewOpen = false;

static SP<Config::Values::CBoolValue> g_enabled;
static SP<Config::Values::CBoolValue> g_consumeSwipe;

static CHyprSignalListener g_swipeBegin;
static CHyprSignalListener g_swipeUpdate;
static CHyprSignalListener g_swipeEnd;


static bool enabled() {
    return !g_enabled || g_enabled->value();
}

static bool consuming() {
    return g_consumeSwipe && g_consumeSwipe->value();
}

static void post(const std::string& payload) {
    IPC::Socket2::sock()->postEvent({"custom", payload});
}

static void setOverviewOpen(bool open) {
    if (g_overviewOpen == open)
        return;
    g_overviewOpen = open;
    post(open ? "niselle-overview,open" : "niselle-overview,close");
}


static void onSwipeBegin(IPointer::SSwipeBeginEvent e, Event::SCallbackInfo& info) {
    if (!enabled() || !g_overviewOpen)
        return;
    post("niselle-overview-swipe,begin," + std::to_string(e.fingers) + ",0,0");
    if (consuming())
        info.cancelled = true;
}

static void onSwipeUpdate(IPointer::SSwipeUpdateEvent e, Event::SCallbackInfo& info) {
    if (!enabled() || !g_overviewOpen)
        return;
    post("niselle-overview-swipe,update," + std::to_string(e.fingers) + "," + std::to_string(e.delta.x) + "," + std::to_string(e.delta.y));
    if (consuming())
        info.cancelled = true;
}

static void onSwipeEnd(IPointer::SSwipeEndEvent e, Event::SCallbackInfo& info) {
    if (!enabled() || !g_overviewOpen)
        return;
    post("niselle-overview-swipe,end," + std::string(e.cancelled ? "1" : "0") + ",0,0");
    if (consuming())
        info.cancelled = true;
}


static SDispatchResult dispatchOverview(std::string arg) {
    SDispatchResult result;
    if (arg == "open") {
        setOverviewOpen(true);
    } else if (arg == "close") {
        setOverviewOpen(false);
    } else if (arg == "toggle") {
        setOverviewOpen(!g_overviewOpen);
    } else {
        result.success = false;
        result.error   = "Nutzung: niselle:overview <open|close|toggle>";
    }
    return result;
}


APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    PHANDLE = handle;

    const std::string HASH = __hyprland_api_get_hash();
    if (HASH != __hyprland_api_get_client_hash()) {
        HyprlandAPI::addNotification(PHANDLE, "[niselle-overview] Header/Hyprland-Version passt nicht – Plugin nicht geladen.", CHyprColor(1.F, 0.25F, 0.25F, 1.F), 5000);
        return {"niselle-overview", "Versionskonflikt", "jakob", "0.1.0"};
    }

    g_enabled = makeShared<Config::Values::CBoolValue>("plugin:niselle_overview:enabled", "Wischgesten an die Niselle-Übersicht weiterreichen", true);
    HyprlandAPI::addConfigValueV2(PHANDLE, g_enabled);

    g_consumeSwipe = makeShared<Config::Values::CBoolValue>("plugin:niselle_overview:consume_swipe", "Wischgesten übernehmen, solange die Übersicht offen ist (Hyprland schaltet dann nicht selbst um)", false);
    HyprlandAPI::addConfigValueV2(PHANDLE, g_consumeSwipe);

    HyprlandAPI::addDispatcherV2(PHANDLE, "niselle:overview", dispatchOverview);

    g_swipeBegin  = Event::bus()->m_events.gesture.swipe.begin.listen(onSwipeBegin);
    g_swipeUpdate = Event::bus()->m_events.gesture.swipe.update.listen(onSwipeUpdate);
    g_swipeEnd    = Event::bus()->m_events.gesture.swipe.end.listen(onSwipeEnd);

    return {"niselle-overview", "Wischgesten für die Niselle-Übersicht", "jakob", "0.1.0"};
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_swipeBegin.reset();
    g_swipeUpdate.reset();
    g_swipeEnd.reset();

    if (PHANDLE)
        HyprlandAPI::removeDispatcher(PHANDLE, "niselle:overview");

    g_overviewOpen = false;
    g_enabled.reset();
    g_consumeSwipe.reset();
}
