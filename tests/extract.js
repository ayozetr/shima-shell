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
function body(text, name) {
    const start = text.indexOf("function " + name + "(");
    if (start < 0) throw new Error("no such function: " + name);

    let depth = 0, seen = false;
    for (let i = start; i < text.length; i++) {
        const c = text[i];
        if (c === "{") { depth++; seen = true; }
        else if (c === "}") {
            depth--;
            if (seen && depth === 0) return text.slice(start, i + 1);
        }
    }
    throw new Error("unterminated function: " + name);
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
