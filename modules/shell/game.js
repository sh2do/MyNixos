.pragma library

// GameMode, pure (tests/game-test.js). Game.qml asks the session bus whether
// gamemoded is there and, only if it is, how many games it serves; this
// reads busctl's answer. Shared by both shells.

// The probe's output: "owner b true|false", then (only when owned)
// "clients i N". Returns {up, clients}; anything unclear is "no game".
function parse(text) {
    var up = false, clients = 0;
    var lines = String(text === null || text === undefined ? "" : text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var m = /^(\w+) ([a-z]) (.*)$/.exec(lines[i].trim());
        if (!m)
            continue;
        if (m[1] === "owner" && m[2] === "b")
            up = m[3] === "true";
        else if (m[1] === "clients" && m[2] === "i" && /^\d+$/.test(m[3]))
            clients = Number(m[3]);
    }
    return { up: up, clients: up ? clients : 0 };
}

// The chip's words: "" with no game, "game", "3 games".
function label(clients) {
    return clients > 1 ? clients + " games" : clients === 1 ? "game" : "";
}
