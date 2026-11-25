// The only module that knows the engine request protocol.
export function query(request) {
  if (typeof window.fte_query !== 'function') return null;
  try { return window.fte_query(request); } catch (_) { return null; }
}

export function accepted(reply) {
  if (reply === 'ok') return true;
  try { return JSON.parse(reply).ok === true; } catch (_) { return false; }
}

export function readLobby() {
  const raw = query('getlobby');
  if (!raw) throw new Error('Waiting for the lobby connection…');
  try {
    const snapshot = JSON.parse(raw);
    if (snapshot.uiVersion) snapshot.chat = JSON.parse(query('getlobbychat') || '[]');
    return snapshot;
  } catch (_) { throw new Error('Unable to read the lobby.'); }
}

export function action(name) { return accepted(query('lobby_action:' + name)); }
// The engine's reason when it refuses an action ({"ok":false,"error":...}); '' when accepted.
export function actionError(name) {
  const reply = query('lobby_action:' + name);
  if (accepted(reply)) return '';
  try { return JSON.parse(reply).error || 'not allowed now'; } catch (_) { return 'not allowed now'; }
}
export function leave() {
  if (!action('close')) return false;
  if (!accepted(query('cbuf:menu_webcore_title'))) query('cbuf:menu_webcore');
  return true;
}
export function copyCode(code) { return accepted(query('clipboard_copy:' + code)); }

const MENU_SOUNDS = { navigate: 'misc/menu1', confirm: 'misc/menu2', back: 'misc/menu3' };
export function menuSound(kind) {
  if (MENU_SOUNDS[kind]) query('localsound:' + MENU_SOUNDS[kind]);
}

// UTF-8 hex keeps user text out of console syntax (quotes, semicolons, newlines).
export function encodeChat(text) {
  const bytes = unescape(encodeURIComponent(text));
  if (bytes.length > 240) throw new Error('Message is too long (240 UTF-8 bytes maximum).');
  return Array.from(bytes).map(ch => ('0' + ch.charCodeAt(0).toString(16)).slice(-2)).join('');
}

export function sendChat(text) { return action('chat:' + encodeChat(text)); }

// Server names and passwords travel as UTF-8 hex too (empty text is '').
export function encodeHex(text) {
  return Array.from(unescape(encodeURIComponent(text))).map(ch => ('0' + ch.charCodeAt(0).toString(16)).slice(-2)).join('');
}
// setserver:<listen|dedicated>:<max>:<bots|fill>:<public 0|1>:<name hex>:<password hex>
export function setServer(d) {
  return actionError('setserver:' + (d.dedicated ? 'dedicated' : 'listen') + ':' + Number(d.max) + ':' +
    (d.fill ? 'fill' : Number(d.bots)) + ':' + (d.listed ? 1 : 0) + ':' + encodeHex(d.name.trim()) + ':' + encodeHex(d.password));
}
// A guest the host asked for a password joins again with it.
export function joinWithPassword(text) { return actionError('joinpass:' + encodeHex(text)); }
