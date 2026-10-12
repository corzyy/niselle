import QtQuick

// Fensteraufnahmen eines Overview-Fensters, nach Hyprland-Adresse. Jede Fenstervorschau (WindowPreview) besitzt die
// einzige Aufnahme ihres Fensters und meldet sie hier an; die Arbeitsflächen-Leiste zeigt dieselbe Aufnahme per
// ShaderEffectSource, statt das Fenster ein zweites Mal aufzunehmen.
QtObject {
    id: root

    // { address: ScreencopyView }
    property var items: ({})
    property int revision: 0

    function itemFor(address) {
        void root.revision;
        return root.items[address] ?? null;
    }
    function register(address, item) {
        if (!address || root.items[address] === item)
            return;
        const next = Object.assign({}, root.items);
        next[address] = item;
        root.items = next;
        root.revision++;
    }
    function unregister(address, item) {
        if (!address || root.items[address] !== item)
            return;
        const next = Object.assign({}, root.items);
        delete next[address];
        root.items = next;
        root.revision++;
    }
}
