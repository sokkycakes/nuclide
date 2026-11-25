// Normalize both the old name-array snapshot and the current session snapshot.
export function normalize(data) {
  if (!data || typeof data !== 'object') throw new Error('Invalid lobby state.');
  const players = (Array.isArray(data.players) ? data.players : []).filter(Boolean).map((p, i) => {
    if (typeof p === 'object') return p;
    const ready = p.indexOf('[READY]') === 0;
    const name = ready ? p.slice(7).trim() : p;
    return { seat: i, name, ready, connected: true, host: name === data.host };
  });
  const settings = data.settings || {};
  return {
    ...data, players, phase: String(data.phase || '').toUpperCase(),
    sessionId: data.sessionId || '', room: data.roomCode || data.room || '',
    localSeat: data.localSeat == null ? -1 : data.localSeat,
    max: data.max || 16, map: data.map || '',
    ruleset: settings.ruleset || data.ruleset || '',
    serverType: settings.servertype || data.serverType || 'LISTEN SERVER',
    timelimit: settings.timelimit == null ? '' : settings.timelimit,
    fraglimit: settings.fraglimit == null ? '' : settings.fraglimit,
    canLeave: data.canLeave !== false,
    canConfigure: !!(data.active && data.isHost && data.canChangeMap),
    canChat: !!data.canChat,
    chat: Array.isArray(data.chat) ? data.chat : [],
    network: data.network || data.transport || '',
    receivedAt: Date.now()
  };
}

export const EMPTY = normalize({ active: false, players: [] });
export function localPlayer(s) { return s.players.find(p => p.seat === s.localSeat); }
export function countdown(s) {
  if (s.phase !== 'COUNTDOWN') return '';
  const now = (s.serverTime || 0) + (Date.now() - s.receivedAt) / 1000;
  const seconds = Math.max(0, Math.ceil((s.countdownEnd || 0) - now));
  return seconds ? 'Starting in ' + seconds + '…' : 'Starting…';
}

// Fallback lists for engines whose getlobby doesn't send "maps"/"rulesets".
// Keep in step with base/scripts/lobby.txt (Bulwark reads that file and sends
// only the maps that are shipped). Every map here must exist as base/maps/<id>.bsp.
export const MAPS = [
  { id: 'duel_alley', name: 'Duel Alley' }, { id: 'arch_testbed', name: 'Arch Testbed' },
  { id: 'arch_crux_test', name: 'Arch Crux Test' }, { id: 'envtest', name: 'Env Test' },
  { id: 'lean', name: 'Lean Test' }
];
export const RULESETS = [
  { id: 'DUEL', name: 'Duel' }, { id: 'DEATHMATCH', name: 'Deathmatch' },
  { id: 'TEAMDM', name: 'Team Deathmatch' }, { id: 'DOMINATION', name: 'Domination' },
  { id: 'FREEZETAG', name: 'Freeze Tag' }, { id: 'ARCHSTILETTO', name: 'Archstiletto' }
];
function choices(list, fallback) {
  const valid = (Array.isArray(list) ? list : []).filter(e => e && typeof e.id === 'string' && e.id)
    .map(e => ({ id: e.id, name: typeof e.name === 'string' && e.name ? e.name : e.id, available: e.available !== false }));
  return valid.length ? valid : fallback;
}
export function mapList(s) { return choices(s && s.maps, MAPS); }
export function rulesetList(s) { return choices(s && s.rulesets, RULESETS); }
export function mapTitle(id, s) { const entry = mapList(s).find(m => m.id === id); return entry ? entry.name : id || 'Waiting…'; }
export function rulesetTitle(id, s) { const entry = rulesetList(s).find(r => r.id === id); return entry ? entry.name : id; }
