// Pulling a function out of a QML file so it can be run on its own.
//
// The logic that has nothing to do with what is on screen — working
// out a sum, reading a bookmarks file, deciding whether a window
// belongs to an application — is plain JavaScript sitting inside a QML
// object. There is no need for a running shell to exercise it, and no
// need to keep a second copy of it here either: it is read out of the
// file that ships, so a test cannot quietly drift from the code.

const fs = require("fs");
const path = require("path");

const root = path.join(__dirname, "..");

function source(file) {
    return fs.readFileSync(path.join(root, file), "utf8");
}

// Everything from `function name(` to the brace that closes it.
//
// The braces have to be counted past everything that only looks like
// code. A `"}"` inside a string used to close the function early and
// hand the test half of it; a `/[{]/` left it looking unterminated;
// a `// }` in a comment did the same as the string. None of that
// broke anything on the day it was written, which is the problem:
// the first person to put a brace in a comment would have got a
// syntax error pointing at a line they never touched.
function body(text, name) {
    const start = text.indexOf("function " + name + "(");
    if (start < 0) throw new Error("no such function: " + name);

    let depth = 0, seen = false;
    for (let i = start; i < text.length; i++) {
        const skipped = skip(text, i);
        if (skipped >= 0) { i = skipped; continue; }

        const c = text[i];
        if (c === "{") { depth++; seen = true; }
        else if (c === "}") {
            depth--;
            if (seen && depth === 0) return text.slice(start, i + 1);
        }
    }
    throw new Error("unterminated function: " + name);
}

// Given a position, says whether what starts there is something to
// step over — a string, a comment, a regular expression — and where
// it ends. -1 means it is ordinary code and the caller should read it.
function skip(text, i) {
    const c = text[i], next = text[i + 1];

    if (c === "/" && next === "/") {
        const end = text.indexOf("\n", i);
        return end < 0 ? text.length : end;
    }
    if (c === "/" && next === "*") {
        const end = text.indexOf("*/", i + 2);
        if (end < 0) throw new Error("unterminated comment");
        return end + 1;
    }
    if (c === '"' || c === "'" || c === "`") return string(text, i);
    if (c === "/" && opensRegex(text, i)) return regex(text, i);
    return -1;
}

// Up to the closing quote. A backtick also has holes in it — `${...}`
// — and those hold code, which can hold strings of its own.
function string(text, i) {
    const quote = text[i];
    for (let j = i + 1; j < text.length; j++) {
        const c = text[j];
        if (c === "\\") { j++; continue; }
        if (c === quote) return j;
        if (quote === "`" && c === "$" && text[j + 1] === "{")
            j = hole(text, j + 1);
    }
    throw new Error("unterminated string");
}

// From the `{` of a template hole to the `}` that closes it.
function hole(text, i) {
    let depth = 0;
    for (let j = i; j < text.length; j++) {
        const skipped = skip(text, j);
        if (skipped >= 0) { j = skipped; continue; }
        if (text[j] === "{") depth++;
        else if (text[j] === "}" && --depth === 0) return j;
    }
    throw new Error("unterminated template hole");
}

// Up to the closing slash, and then its flags. A `/` inside brackets
// is a character and not the end: /[/]/ is a valid expression.
function regex(text, i) {
    let inClass = false;
    for (let j = i + 1; j < text.length; j++) {
        const c = text[j];
        if (c === "\\") { j++; continue; }
        if (c === "[") inClass = true;
        else if (c === "]") inClass = false;
        else if (c === "\n") break;
        else if (c === "/" && !inClass) {
            while (j + 1 < text.length && /[a-z]/.test(text[j + 1])) j++;
            return j;
        }
    }
    throw new Error("unterminated regular expression");
}

// Whether the slash at `i` starts a regular expression rather than
// dividing. After a value — a name, a number, a closing bracket — it
// divides; after an operator, a comma, a bracket or `return`, it opens
// an expression.
const OPENS = ["return", "typeof", "case", "in", "of", "new", "delete",
               "void", "instanceof", "do", "else", "yield", "await"];

function opensRegex(text, i) {
    let j = i - 1;
    while (j >= 0 && /\s/.test(text[j])) j--;
    if (j < 0) return true;

    const c = text[j];
    if (/[A-Za-z0-9_$]/.test(c)) {
        let k = j;
        while (k >= 0 && /[A-Za-z0-9_$]/.test(text[k])) k--;
        return OPENS.indexOf(text.slice(k + 1, j + 1)) !== -1;
    }
    return ")]".indexOf(c) === -1;
}

// The functions, plus whatever they lean on, in one scope. `refs` is
// what the QML around them would have provided: another singleton, a
// property, a constant. `root` is provided for free and ends up being
// the functions themselves, since that is how they call each other.
function load(file, names, refs) {
    const text = source(file);
    const parts = names.map(n => body(text, n));

    const self = {};
    const all = Object.assign({ root: self }, refs || {});
    const keys = Object.keys(all);

    const make = new Function(...keys,
        parts.join("\n") + "\nreturn {" + names.join(", ") + "};");
    const out = make(...keys.map(k => all[k]));
    Object.assign(self, out);
    return out;
}

module.exports = { source, body, load, root };
