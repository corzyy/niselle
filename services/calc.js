.pragma library


const constants = {
    "pi": Math.PI,
    "π": Math.PI,
    "tau": 2 * Math.PI,
    "e": Math.E
};

const functions = {
    "sqrt": Math.sqrt,
    "√": Math.sqrt,
    "cbrt": Math.cbrt,
    "abs": Math.abs,
    "sin": Math.sin,
    "cos": Math.cos,
    "tan": Math.tan,
    "asin": Math.asin,
    "acos": Math.acos,
    "atan": Math.atan,
    "ln": Math.log,
    "log": Math.log10,
    "lg": Math.log10,
    "log2": Math.log2,
    "exp": Math.exp,
    "floor": Math.floor,
    "ceil": Math.ceil,
    "round": Math.round
};

function tokenize(text) {
    const tokens = [];
    const src = text.replace(/\s+/g, "");
    let i = 0;
    while (i < src.length) {
        const ch = src[i];
        let m = /^(\d+([.,]\d+)?|[.,]\d+)/.exec(src.slice(i));
        if (m) {
            tokens.push({
                "t": "num",
                "v": parseFloat(m[0].replace(",", "."))
            });
            i += m[0].length;
            continue;
        }
        m = /^[a-zπ√][a-z0-9π]*/i.exec(src.slice(i));
        if (m) {
            const word = m[0].toLowerCase();
            tokens.push({
                "t": "id",
                "v": word
            });
            i += m[0].length;
            continue;
        }
        if (src.slice(i, i + 2) === "**") {
            tokens.push({
                "t": "op",
                "v": "^"
            });
            i += 2;
            continue;
        }
        if ("+-*/^%()!".indexOf(ch) >= 0) {
            tokens.push({
                "t": "op",
                "v": ch
            });
            i++;
            continue;
        }
        if (ch === "×" || ch === "·") {
            tokens.push({
                "t": "op",
                "v": "*"
            });
            i++;
            continue;
        }
        if (ch === "÷" || ch === ":") {
            tokens.push({
                "t": "op",
                "v": "/"
            });
            i++;
            continue;
        }
        if (ch === "−" || ch === "–") {
            tokens.push({
                "t": "op",
                "v": "-"
            });
            i++;
            continue;
        }
        return null;
    }
    return tokens;
}

function factorial(n) {
    if (n < 0 || n !== Math.floor(n) || n > 170)
        return NaN;
    let r = 1;
    for (let k = 2; k <= n; k++)
        r *= k;
    return r;
}

function evaluate(text) {
    const tokens = tokenize(text);
    if (!tokens || tokens.length === 0)
        return null;
    let pos = 0;
    let operators = 0;
    const peek = () => tokens[pos];
    const isOp = v => peek() && peek().t === "op" && peek().v === v;

    function fail() {
        throw new Error("syntax");
    }

    function startsOperand(tok) {
        return !!tok && (tok.t === "num" || tok.t === "id" || (tok.t === "op" && tok.v === "("));
    }

    function parseExpr() {
        let v = parseTerm();
        while (isOp("+") || isOp("-")) {
            const op = tokens[pos++].v;
            operators++;
            const r = parseTerm();
            v = op === "+" ? v + r : v - r;
        }
        return v;
    }

    function parseTerm() {
        let v = parsePower();
        for (;;) {
            if (isOp("*") || isOp("/")) {
                const op = tokens[pos++].v;
                operators++;
                const r = parsePower();
                v = op === "*" ? v * r : v / r;
            } else if (isOp("%") && startsOperand(tokens[pos + 1])) {
                pos++;
                operators++;
                v = v % parsePower();
            } else if (startsOperand(peek())) {
                operators++;
                v = v * parsePower();
            } else {
                return v;
            }
        }
    }

    function parsePower() {
        const base = parseUnary();
        if (isOp("^")) {
            pos++;
            operators++;
            return Math.pow(base, parsePower());
        }
        return base;
    }

    function parseUnary() {
        if (isOp("-")) {
            pos++;
            operators++;
            return -parseUnary();
        }
        if (isOp("+")) {
            pos++;
            return parseUnary();
        }
        return parsePostfix();
    }

    function parsePostfix() {
        let v = parsePrimary();
        for (;;) {
            if (isOp("!")) {
                pos++;
                operators++;
                v = factorial(v);
            } else if (isOp("%") && !startsOperand(tokens[pos + 1])) {
                pos++;
                operators++;
                v = v / 100;
            } else {
                return v;
            }
        }
    }

    function parsePrimary() {
        const tok = tokens[pos++];
        if (!tok)
            fail();
        if (tok.t === "num")
            return tok.v;
        if (tok.t === "op" && tok.v === "(") {
            const v = parseExpr();
            if (!isOp(")"))
                fail();
            pos++;
            return v;
        }
        if (tok.t === "id") {
            if (functions[tok.v]) {
                operators++;
                if (isOp("(")) {
                    pos++;
                    const v = parseExpr();
                    if (!isOp(")"))
                        fail();
                    pos++;
                    return functions[tok.v](v);
                }
                return functions[tok.v](parseUnary());
            }
            if (constants[tok.v] !== undefined)
                return constants[tok.v];
        }
        return fail();
    }

    try {
        const value = parseExpr();
        if (pos < tokens.length || operators === 0 || !isFinite(value))
            return null;
        return value;
    } catch (e) {
        return null;
    }
}

function format(value, decimalPoint) {
    let s = Math.abs(value) >= 1e15 || (Math.abs(value) < 1e-9 && value !== 0) ? value.toExponential(9) : String(parseFloat(value.toPrecision(12)));
    if (s.indexOf("e") >= 0)
        s = s.replace(/\.?0+e/, "e");
    return decimalPoint && decimalPoint !== "." ? s.replace(".", decimalPoint) : s;
}
