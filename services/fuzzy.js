.pragma library

// Unscharfe Suche für App- und Einstellungsnamen. Alle Funktionen erwarten bereits normalisierte Texte (norm()).

// Akzente und Groß-/Kleinschreibung ignorieren
function norm(s) {
    return (s || "").normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

// Zeichen, nach denen ein neues Wort beginnt
function isBoundary(ch) {
    return ch === " " || ch === "-" || ch === "_" || ch === "." || ch === "/";
}

// Teilfolgen-Treffer wie bei fzf: die Zeichen des Musters müssen in Reihenfolge im Text vorkommen.
// Bewertet werden zusammenhängende Läufe, Wortanfänge und der Textanfang; Lücken kosten Punkte.
// Rückgabe: Anteil 0..1 des erreichbaren Höchstwerts, 0 ohne Treffer.
function subsequence(pattern, text) {
    const n = pattern.length;
    if (n === 0 || n > text.length)
        return 0;
    const perChar = 16 + 24 + 20;
    let best = 0;
    for (let start = text.indexOf(pattern[0]); start >= 0; start = text.indexOf(pattern[0], start + 1)) {
        let score = 0;
        let pos = start - 1;
        let run = 0;
        let ok = true;
        for (let i = 0; i < n; i++) {
            const found = text.indexOf(pattern[i], pos + 1);
            if (found < 0) {
                ok = false;
                break;
            }
            let s = 16;
            if (found === pos + 1 && i > 0) {
                run++;
                s += Math.min(24, 8 * run);
            } else {
                run = 0;
                if (i > 0)
                    s -= Math.min(12, found - pos - 1);
            }
            if (found === 0)
                s += 20;
            else if (isBoundary(text[found - 1]))
                s += 14;
            score += s;
            pos = found;
        }
        if (ok && score > best)
            best = score;
    }
    return Math.max(0, best) / (n * perChar);
}

// Edit-Distanz mit Vertauschung (Damerau, eingeschränkt), bricht bei Überschreiten von `max` ab
function editDistance(a, b, max) {
    if (Math.abs(a.length - b.length) > max)
        return max + 1;
    const rows = [];
    for (let i = 0; i <= a.length; i++) {
        rows.push(new Array(b.length + 1).fill(0));
        rows[i][0] = i;
    }
    for (let j = 0; j <= b.length; j++)
        rows[0][j] = j;
    for (let i = 1; i <= a.length; i++) {
        let rowMin = max + 1;
        for (let j = 1; j <= b.length; j++) {
            const cost = a[i - 1] === b[j - 1] ? 0 : 1;
            let d = Math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost);
            if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1])
                d = Math.min(d, rows[i - 2][j - 2] + 1);
            rows[i][j] = d;
            rowMin = Math.min(rowMin, d);
        }
        if (rowMin > max)
            return max + 1;
    }
    return rows[a.length][b.length];
}

// Tippfehler: das Muster liegt höchstens `max` Änderungen neben einem Wortanfang des Textes
function typo(pattern, text) {
    if (pattern.length < 4)
        return 0;
    const max = pattern.length >= 7 ? 2 : 1;
    for (const word of text.split(/[\s\-_.]+/)) {
        if (word.length < 2)
            continue;
        const head = word.slice(0, pattern.length + max);
        let d = editDistance(pattern, head.slice(0, Math.min(head.length, pattern.length)), max);
        if (d > max)
            d = editDistance(pattern, head, max);
        if (d <= max)
            return 1 - d / (max + 1);
    }
    return 0;
}

// Unscharfer Wert 0..90 (liegt immer unter exakten Teilstring-Treffern), 0 ohne Treffer
function fuzzyScore(pattern, text) {
    if (pattern.length < 2 || text.length === 0)
        return 0;
    const sub = subsequence(pattern, text);
    if (sub >= 0.45)
        return 30 + 60 * sub;
    const t = typo(pattern, text);
    return t > 0 ? 20 + 40 * t : 0;
}
