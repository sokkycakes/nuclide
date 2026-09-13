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
