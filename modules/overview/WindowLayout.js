.pragma library

// Anordnung der Fenstervorschauen: Port von UnalignedLayoutStrategy und WorkspaceLayout [workspace.js:26-385, 478-640].
// Rein rechnerisch, ohne UI. Alle Längen in Pixeln.
//
// Eingabe `windows`: [{ x, y, width, height }] – Fenstergröße samt Position auf dem Monitor (boundingBox)
// `opts`:
//   monitorHeight   Höhe des Monitors (für die Fenster-Skalierung)
//   workarea        {x, y, width, height}: Arbeitsfläche, nach der die Zeilenzahl gewählt wird
//   container       {x, y, width, height}: Fläche, in die die Vorschauen gelegt werden
//   spacing         Abstand zwischen den Vorschauen (.window-picker spacing)
//   oversize        größte Überhangbreite des Beiwerks (Icon, Schließen-Knopf, Hervorhebung)
//   bottomOverlap   Höhe des Titels samt Abstand unter der Vorschau
//   monitorBottomFree  freier Platz zwischen Containerunterkante und Monitorunterkante
//   maxScale, scaleWeight, spaceWeight
// Rückgabe: [{ x, y, width, height }] in der Reihenfolge von `windows`

function lerp(a, b, t) {
    return a + (b - a) * t;
}

function windowScale(win, monitorHeight) {
    // Höhe ist wichtiger als Breite, kleine Fenster werden bis 1.5-fach vergrößert [workspace.js:155-170]
    return lerp(1.5, 1, win.height / monitorHeight);
}

function computeLayout(windows, numRows, o) {
    const rows = [];
    let totalWidth = 0;
    for (const w of windows)
        totalWidth += w.width * windowScale(w, o.monitorHeight);
    const idealRowWidth = totalWidth / numRows;

    // Vertikal sortieren: bestimmt die Zeile [workspace.js:226-229]
    const sorted = windows.slice().sort((a, b) => (a.y + a.height / 2) - (b.y + b.height / 2));

    let idx = 0;
    for (let i = 0; i < numRows; i++) {
        const row = {
            x: 0, y: 0, width: 0, height: 0, fullWidth: 0, fullHeight: 0, additionalScale: 1, windows: []
        };
        rows.push(row);
        for (; idx < sorted.length; idx++) {
            const w = sorted[idx];
            const s = windowScale(w, o.monitorHeight);
            const width = w.width * s;
            const height = w.height * s;
            row.fullHeight = Math.max(row.fullHeight, height);
            if (keepSameRow(row, width, idealRowWidth) || i === numRows - 1) {
                row.windows.push(w);
                row.fullWidth += width;
            } else {
                break;
            }
        }
    }

    let gridHeight = 0;
    let maxRow = null;
    for (const row of rows) {
        // Horizontal sortieren: Reihenfolge in der Zeile [workspace.js:206-210]
        row.windows.sort((a, b) => (a.x + a.width / 2) - (b.x + b.width / 2));
        if (!maxRow || row.fullWidth > maxRow.fullWidth)
            maxRow = row;
        gridHeight += row.fullHeight;
    }

    return {
        numRows: numRows,
        rows: rows,
        maxColumns: maxRow.windows.length,
        gridWidth: maxRow.fullWidth,
        gridHeight: gridHeight,
        scale: 1
    };
}

function keepSameRow(row, width, idealRowWidth) {
    if (row.fullWidth + width <= idealRowWidth)
        return true;
    const oldRatio = row.fullWidth / idealRowWidth;
    const newRatio = (row.fullWidth + width) / idealRowWidth;
    return Math.abs(1 - newRatio) < Math.abs(1 - oldRatio);
}

function computeScaleAndSpace(layout, area, rowSpacing, colSpacing, maxScale) {
    const hspacing = (layout.maxColumns - 1) * colSpacing;
    const vspacing = (layout.numRows - 1) * rowSpacing;
    const horizontalScale = (area.width - hspacing) / layout.gridWidth;
    const verticalScale = (area.height - vspacing) / layout.gridHeight;
    const scale = Math.min(horizontalScale, verticalScale, maxScale);
    const space = ((layout.gridWidth * scale + hspacing) * (layout.gridHeight * scale + vspacing)) / (area.width * area.height);
    layout.scale = scale;
    return [scale, space];
}

function isBetter(oldScale, oldSpace, scale, space, scaleWeight, spaceWeight) {
    const spacePower = (space - oldSpace) * spaceWeight;
    const scalePower = (scale - oldScale) * scaleWeight;
    if (scale > oldScale && space > oldSpace)
        return true;
    if (scale > oldScale && space <= oldSpace)
        return scalePower > spacePower;
    if (scale <= oldScale && space > oldSpace)
        return spacePower > scalePower;
    return false;
}

function computeSlots(layout, area, rowSpacing, colSpacing, o) {
    const rows = layout.rows;
    const scale = layout.scale;
    for (const row of rows) {
        row.width = row.fullWidth * scale + (row.windows.length - 1) * colSpacing;
        row.height = row.fullHeight * scale;
    }

    let heightWithoutSpacing = 0;
    for (const row of rows)
        heightWithoutSpacing += row.height;

    const verticalSpacing = (rows.length - 1) * rowSpacing;
    const additionalVerticalScale = Math.min(1, (area.height - verticalSpacing) / heightWithoutSpacing);

    let compensation = 0;
    let y = 0;
    for (const row of rows) {
        const horizontalSpacing = (row.windows.length - 1) * colSpacing;
        const widthWithoutSpacing = row.width - horizontalSpacing;
        const additionalHorizontalScale = Math.min(1, (area.width - horizontalSpacing) / widthWithoutSpacing);

        if (additionalHorizontalScale < additionalVerticalScale) {
            row.additionalScale = additionalHorizontalScale;
            compensation += (additionalVerticalScale - additionalHorizontalScale) * row.height;
        } else {
            row.additionalScale = additionalVerticalScale;
        }

        row.x = area.x + Math.max(area.width - (widthWithoutSpacing * row.additionalScale + horizontalSpacing), 0) / 2;
        row.y = area.y + Math.max(area.height - (heightWithoutSpacing + verticalSpacing), 0) / 2 + y;
        y += row.height * row.additionalScale + rowSpacing;
    }
    compensation /= 2;

    const slots = new Array(o.count);
    for (const row of rows) {
        const rowY = row.y + compensation;
        const rowHeight = row.height * row.additionalScale;
        let x = row.x;
        for (const w of row.windows) {
            let s = scale * windowScale(w, o.monitorHeight) * row.additionalScale;
            const cellWidth = w.width * s;
            const cellHeight = w.height * s;

            s = Math.min(s, o.maxScale);
            const cloneWidth = w.width * s;
            const cloneHeight = w.height * s;

            const cloneX = x + (cellWidth - cloneWidth) / 2;
            // Eine Zeile: mittig, sonst unten bündig [workspace.js:362-367]
            const cloneY = rows.length === 1 ? rowY + (rowHeight - cloneHeight) / 2 : rowY + rowHeight - cellHeight;

            slots[w.index] = {
                x: Math.floor(cloneX),
                y: Math.floor(cloneY),
                width: cloneWidth,
                height: cloneHeight
            };
            x += cellWidth + colSpacing;
        }
    }
    return slots;
}

function compute(windows, o) {
    if (windows.length === 0)
        return [];
    const wins = windows.map((w, i) => ({
                x: w.x,
                y: w.y,
                width: w.width,
                height: w.height,
                index: i
            }));

    const rowSpacing = o.spacing + o.oversize;
    const colSpacing = o.spacing + o.oversize;

    let last = null;
    let lastColumns = -1;
    let lastScale = 0;
    let lastSpace = 0;
    for (let numRows = 1; ; numRows++) {
        const numColumns = Math.ceil(wins.length / numRows);
        if (numColumns === lastColumns)
            break;
        const layout = computeLayout(wins, numRows, o);
        const [scale, space] = computeScaleAndSpace(layout, o.workarea, rowSpacing, colSpacing, o.maxScale);
        if (last && !isBetter(lastScale, lastSpace, scale, space, o.scaleWeight, o.spaceWeight))
            break;
        last = layout;
        lastColumns = numColumns;
        lastScale = scale;
        lastSpace = space;
    }

    // Unterkante des Containers kürzen, wenn Titel und Icon über den Monitor ragen [workspace.js:496-505]
    const c = o.container;
    let height = c.height;
    if (o.bottomOverlap + o.oversize > o.monitorBottomFree)
        height -= (o.bottomOverlap + o.oversize) - o.monitorBottomFree;
    const area = {
        x: Math.trunc(c.x),
        y: Math.trunc(c.y),
        width: Math.trunc(c.width),
        height: Math.trunc(height)
    };
    return computeSlots(last, area, rowSpacing, colSpacing, {
        count: wins.length,
        monitorHeight: o.monitorHeight,
        maxScale: o.maxScale
    });
}
