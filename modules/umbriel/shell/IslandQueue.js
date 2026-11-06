.pragma library

// What the island shows, as a pure state machine (tests/island-queue-test.js).
//
// state: {view: "clock"|"music"|"notify"|"osd", until: ms, item, pending: [...]}
//   view    what is showing; `item` is its payload (the clock has none)
//   until   when it gives way (Infinity for the clock and critical notices)
//   pending what is waiting, as {view, item, hold}: hold is the time it gets
//           once shown (a view cut short keeps whatever it had left)
// event: {type: "notify"|"osd"|"music"|"dismiss"|"tick", payload}
//   notify payload {id, critical, ...}; dismiss payload {id}; tick has none.
//
// Priority: osd > critical notify > notify > music > clock. A higher view cuts
// in, and the one it interrupted comes back first; a lower one waits its turn.
// Notices queue in arrival order, osd and music only keep their newest.
// Plain loops only: Qt's JS engine lacks some newer array methods.

var HOLD = { osd: 1500, notify: 5000, music: 4000 };
var RANK = { clock: 0, music: 1, notify: 2, osd: 3 };

function initial() {
    return { view: "clock", until: Infinity, item: null, pending: [] };
}

function show(view, item, hold, now, pending) {
    return { view: view, until: now + hold, item: item, pending: pending };
}

function rank(view, item) {
    return RANK[view] + (view === "notify" && item.critical ? 0.5 : 0);
}

function holdFor(view, item) {
    return view === "notify" && item.critical ? Infinity : HOLD[view];
}

// The highest-ranked waiting entry (the earliest among equals), or -1.
function best(pending) {
    var at = -1;
    for (var i = 0; i < pending.length; i++)
        if (at < 0 || rank(pending[i].view, pending[i].item) > rank(pending[at].view, pending[at].item))
            at = i;
    return at;
}

// Show the best waiting entry, or the clock.
function advance(pending, now) {
    var at = best(pending);
    if (at < 0)
        return { view: "clock", until: Infinity, item: null, pending: pending };
    var rest = pending.slice(0, at).concat(pending.slice(at + 1));
    return show(pending[at].view, pending[at].item, pending[at].hold, now, rest);
}

// osd and music replace a waiting one of their kind; notices queue. An
// interrupted view goes to the front.
function enqueue(pending, entry, front) {
    var out = [];
    for (var i = 0; i < pending.length; i++)
        if (entry.view === "notify" || pending[i].view !== entry.view)
            out.push(pending[i]);
    return front ? [entry].concat(out) : out.concat([entry]);
}

function arrive(state, view, item, now) {
    var hold = holdFor(view, item);
    var cur = state.view;
    // A notice sent again with the same id (replaces_id) takes the old one's
    // place, with a fresh hold if it is showing.
    if (view === "notify") {
        if (cur === "notify" && state.item.id === item.id)
            return show(view, item, hold, now, state.pending);
        for (var i = 0; i < state.pending.length; i++) {
            if (state.pending[i].view === "notify" && state.pending[i].item.id === item.id) {
                var replaced = state.pending.slice();
                replaced[i] = { view: view, item: item, hold: hold };
                return { view: cur, until: state.until, item: state.item, pending: replaced };
            }
        }
    }
    // Same kind refreshes in place, except a notice, which queues behind.
    if (cur === view && view !== "notify")
        return show(view, item, hold, now, state.pending);
    if (rank(view, item) > rank(cur, state.item)) {
        var pending = state.pending;
        if (cur !== "clock")
            pending = enqueue(pending, { view: cur, item: state.item, hold: state.until - now }, true);
        return show(view, item, hold, now, pending);
    }
    return {
        view: cur,
        until: state.until,
        item: state.item,
        pending: enqueue(state.pending, { view: view, item: item, hold: hold }, false)
    };
}

function dismiss(state, id, now) {
    var pending = [];
    for (var i = 0; i < state.pending.length; i++)
        if (!(state.pending[i].view === "notify" && state.pending[i].item.id === id))
            pending.push(state.pending[i]);
    if (state.view === "notify" && state.item.id === id)
        return advance(pending, now);
    return { view: state.view, until: state.until, item: state.item, pending: pending };
}

function next(state, event, now) {
    switch (event.type) {
    case "osd":
    case "notify":
    case "music":
        return arrive(state, event.type, event.payload || {}, now);
    case "dismiss":
        return dismiss(state, event.payload.id, now);
    case "tick":
        if (state.view !== "clock" && now >= state.until)
            return advance(state.pending, now);
        return state;
    }
    return state;
}

// Whether a notice is still showing or waiting.
function holds(state, id) {
    if (state.view === "notify" && state.item.id === id)
        return true;
    for (var i = 0; i < state.pending.length; i++)
        if (state.pending[i].view === "notify" && state.pending[i].item.id === id)
            return true;
    return false;
}
