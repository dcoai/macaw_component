// macaw_component's shared client module (spec/02 §8): the announcer and the client bus,
// each found, not created per component, so every adopter's hooks share one of each on a
// page. One ES module from 'self', no build step, no dependencies. A host serves it with
//
//     plug Plug.Static, at: "/", from: {:macaw_component, "priv/static"}, only: ~w(macaw_component)
//
// and a hook imports it as
//
//     import { announce, bus } from "/macaw_component/client.js";
//
// The names below are Macaw.Component.Client's; the module holds no source of a
// component's names: what a component declares reaches it as the data attributes
// Macaw.Component.Client.attributes/1 renders on the component's element.

const ANNOUNCER_IDS = Object.freeze({
  polite: 'mw-announcer-polite',
  assertive: 'mw-announcer-assertive'
});
const ANNOUNCE_EVENT = 'macaw:announce';
const BUS_NAME = 'MacawBus';
const ANNOUNCES_ATTRIBUTE = 'data-mw-announces';
const LOCAL_ATTRIBUTE = 'data-mw-local';

// At most one announcement per region in this many milliseconds; requests arriving
// meanwhile wait in the region's queue.
const INTERVAL_MS = 500;

export const names = Object.freeze({
  announcerIds: ANNOUNCER_IDS,
  announceEvent: ANNOUNCE_EVENT,
  busName: BUS_NAME,
  announcesAttribute: ANNOUNCES_ATTRIBUTE,
  localAttribute: LOCAL_ATTRIBUTE,
  intervalMs: INTERVAL_MS
});

// The names a component declares under an attribute: the JSON list on the nearest element,
// the given one or an ancestor, that carries the attribute; [] when none does. A malformed
// list throws: Client.attributes/1 renders it, so a bad one is a bug to surface.
function declared(el, attribute) {
  const holder = el instanceof Element ? el.closest('[' + attribute + ']') : null;
  if (holder === null) return [];
  const list = JSON.parse(holder.getAttribute(attribute));
  if (!Array.isArray(list)) throw new TypeError(attribute + ' is not a JSON list: ' + holder.getAttribute(attribute));
  return list;
}

// ---------------------------------------------------------------------------------------
// The announcer (core spec/10 §4): one polite and one assertive live region per page.

const queues = { polite: [], assertive: [] };
const timers = { polite: null, assertive: null };
const written = { polite: null, assertive: null };

function regions() {
  const polite = document.getElementById(ANNOUNCER_IDS.polite);
  const assertive = document.getElementById(ANNOUNCER_IDS.assertive);
  return polite && assertive ? { polite, assertive } : null;
}

function region(politeness) {
  const el = document.createElement('div');
  el.id = ANNOUNCER_IDS[politeness];
  el.setAttribute('aria-live', politeness);
  el.setAttribute('aria-atomic', 'true');
  el.className = 'mw-announcer';
  // Visually hidden, through the CSSOM: no style attribute in markup (spec/02 §5).
  Object.assign(el.style, {
    position: 'absolute', width: '1px', height: '1px', margin: '-1px', padding: '0',
    border: '0', overflow: 'hidden', clip: 'rect(0 0 0 0)', clipPath: 'inset(50%)',
    whiteSpace: 'nowrap'
  });
  return el;
}

// The page's announcer, found by its fixed ids. On a page without it (no macaw_live, no
// earlier hook), the first call creates the two regions at the end of the body and becomes
// their announcer: it alone listens for the announce event, so a page has one queue however
// many hooks or copies of this module it holds. Where the regions were found, their
// creator (macaw_live, or the hook that made them) announces.
export function findAnnouncer() {
  const found = regions();
  if (found !== null) return found;
  document.body.append(region('polite'), region('assertive'));
  document.addEventListener(ANNOUNCE_EVENT, onAnnounce);
  return regions();
}

// A hook's request: the announce event, dispatched on its element, bubbling to the document.
export function announce(el, request) {
  findAnnouncer();
  el.dispatchEvent(new CustomEvent(ANNOUNCE_EVENT, { detail: request, bubbles: true }));
}

function onAnnounce(event) {
  const request = accepted(event.target, event.detail);
  if (request !== null) enqueue(request);
}

// The request, or null to drop it: a name the component didn't declare in announces, empty
// text, or a politeness other than the two (polite when absent), as
// Macaw.Component.Announcement.new/2 refuses on the server.
function accepted(el, detail) {
  if (detail === null || typeof detail !== 'object') return null;
  const politeness = detail.politeness === undefined ? 'polite' : detail.politeness;
  if (!Object.hasOwn(ANNOUNCER_IDS, politeness)) return null;
  if (typeof detail.text !== 'string' || detail.text.trim() === '') return null;
  if (typeof detail.name !== 'string' || !declared(el, ANNOUNCES_ATTRIBUTE).includes(detail.name)) return null;
  return { name: detail.name, text: detail.text, politeness };
}

// A request whose name is already waiting in its region's queue merges into it: the newer
// text replaces the older, in the older's place. Otherwise it joins the end of the queue.
function enqueue(request) {
  const queue = queues[request.politeness];
  const waiting = queue.find((r) => r.name === request.name);
  if (waiting) waiting.text = request.text;
  else queue.push({ name: request.name, text: request.text });
  pump(request.politeness);
}

// Writes the next request at once when the region is idle, then holds it for INTERVAL_MS.
function pump(politeness) {
  if (timers[politeness] !== null) return;
  const next = queues[politeness].shift();
  if (next === undefined) return;
  write(politeness, next.text);
  timers[politeness] = setTimeout(() => {
    timers[politeness] = null;
    pump(politeness);
  }, INTERVAL_MS);
}

// The same words twice in a row differ by a trailing no-break space, so a screen reader
// reads the repeat as a change.
function write(politeness, text) {
  const last = written[politeness];
  const content = last !== null && last.text === text && !last.padded ? text + '\u00a0' : text;
  written[politeness] = { text, padded: content !== text };
  findAnnouncer()[politeness].textContent = content;
}

// ---------------------------------------------------------------------------------------
// The client bus (core spec/10 §6): the :local scope between components of one page.

// The page's bus, window.MacawBus: found when macaw_live or an earlier hook made it,
// created by the first call otherwise.
export function bus() {
  if (window[BUS_NAME] === undefined) window[BUS_NAME] = createBus();
  return window[BUS_NAME];
}

// publish(el, key, value) hands value, as given, to every subscriber of key, the
// publisher's own included, as callback(value, el): the source lets a hook skip its own
// echo. subscribe(el, key, callback) answers the function that unsubscribes. Each refuses a
// key that el's component doesn't declare in local, by throwing; nothing is delivered then.
// Values are never inspected: a local type's client encoding is its component's adapter.
function createBus() {
  const subscribers = new Map();

  return Object.freeze({
    publish(el, key, value) {
      refuseUndeclared(el, key);
      for (const entry of [...(subscribers.get(key) ?? [])]) entry.callback(value, el);
    },

    subscribe(el, key, callback) {
      refuseUndeclared(el, key);
      if (typeof callback !== 'function') throw new TypeError(BUS_NAME + ': a subscriber is a function');
      if (!subscribers.has(key)) subscribers.set(key, new Set());
      const entry = { el, callback };
      subscribers.get(key).add(entry);
      return () => subscribers.get(key).delete(entry);
    }
  });
}

function refuseUndeclared(el, key) {
  if (typeof key !== 'string' || !declared(el, LOCAL_ATTRIBUTE).includes(key)) {
    throw new Error(BUS_NAME + ': the key ' + JSON.stringify(key) + ' is not declared in local by this component');
  }
}
