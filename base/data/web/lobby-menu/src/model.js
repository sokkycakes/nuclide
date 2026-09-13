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

export const MAPS = [
  { id: 'envtest', name: 'Env Test' }, { id: 'lean', name: 'Lean Test' },
  { id: 'arch_testbed', name: 'Arch Testbed' }, { id: 'arch_crux_test', name: 'Arch Crux Test' }
];
export const RULESETS = [
  { id: 'DUEL', name: 'Duel' }, { id: 'DEATHMATCH', name: 'Deathmatch' },
  { id: 'TEAMDM', name: 'Team Deathmatch' }, { id: 'DOMINATION', name: 'Domination' }
];
export function mapTitle(id) { const entry = MAPS.find(m => m.id === id); return entry ? entry.name : id || 'Waiting…'; }
