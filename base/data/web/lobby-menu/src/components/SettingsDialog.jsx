import { h } from 'preact';
import { useState } from 'preact/hooks';
import { Button } from './Button';
import { mapList, rulesetList, localPlayer, rulesetTitle, seatBots, canDedicated, serverDraftError } from '../model';
import { setServer } from '../bridge';

// The Server type row: listen or dedicated, name, seats, password, bots, listing.
function ServerSettings({ snapshot: s, close, setNotice }) {
  const [d, setD] = useState({ dedicated: s.dedicated, name: s.hostname, max: s.maxplayers, password: s.passwordText,
    bots: s.botsDefault ? '' : s.bots < 0 ? 0 : s.bots, fill: s.bots < 0, listed: s.listed });
  const on = s.canConfigure;
  const set = patch => setD({ ...d, ...patch });
  const err = serverDraftError(d, s);
  let note = err || (d.dedicated
    ? 'Starts the dedicated server program on this computer and joins it. It keeps running after you leave.'
    : 'Your game hosts the match: it ends when you leave.');
  if (!err && d.listed) note += ' Public: listed on the master servers (sv_public 1).';
  const nobots = !d.fill && String(d.bots) === '';
  if (!err && seatBots(s)) note += ' ' + rulesetTitle(s.ruleset, s) + ' seats its own bots' + (nobots ? '.' : ' (0 turns them off, empty leaves them on).');
  else if (!err && nobots) note += ' Bots: empty leaves them to the game (no bots of the lobby’s own).';
  else if (!err && d.fill) note += ' Bots fill every free player slot.';
  function apply() {
    const why = setServer(d);
    if (why) { setNotice('Server settings: ' + why); return; }
    close(false);
  }
  return <div className="options-content server-settings">
    <div className="limit-row">Server type
      <Button className="toggle push" id="BtnListenServer" aria-pressed={!d.dedicated} disabled={!on} onClick={() => set({ dedicated: false })}>Listen</Button>
      <Button className="toggle" id="BtnDedicatedServer" aria-pressed={d.dedicated} disabled={!on || !canDedicated(s)} onClick={() => set({ dedicated: true })}>Dedicated</Button>
    </div>
    <label className="limit-row">Server name <input id="HostName" className="wide" maxLength="63" value={d.name} disabled={!on} onInput={e => set({ name: e.currentTarget.value })}/></label>
    <label className="limit-row">Max players <input id="MaxPlayers" type="number" min="1" max={(s.hosting && s.hosting.maxSeats) || 16} value={d.max} disabled={!on} onInput={e => set({ max: e.currentTarget.value })}/><span>1 – {(s.hosting && s.hosting.maxSeats) || 16}</span></label>
    <label className="limit-row">Password <input id="ServerPassword" className="wide" maxLength="63" value={d.password} disabled={!on} onInput={e => set({ password: e.currentTarget.value })}/></label>
    <div className="limit-row">Bots
      <input id="BotCount" type="number" min="0" max="15" placeholder="Game" value={d.bots} disabled={!on || d.fill} onInput={e => set({ bots: e.currentTarget.value })} aria-label="Bots"/>
      <Button className="toggle" id="BtnBotFill" aria-pressed={d.fill} disabled={!on} onClick={() => set({ fill: !d.fill })}>Fill</Button>
    </div>
    <div className="limit-row">Public listing
      <Button className="toggle push" id="BtnPublic" aria-pressed={d.listed} disabled={!on} onClick={() => set({ listed: !d.listed })}>{d.listed ? 'On' : 'Off'}</Button>
    </div>
    <p id="ServerNote" className={err ? 'error' : ''}>{note}</p>
    <Button className="choice" id="BtnApplyServer" disabled={!on || !!err} onClick={apply}>Apply</Button>
  </div>;
}

export function SettingsDialog({ kind, snapshot: s, close, run, onReady, setNotice }) {
  const [time, setTime] = useState(s.timelimit === '' ? 0 : s.timelimit);
  const [frags, setFrags] = useState(s.fraglimit === '' ? 0 : s.fraglimit);
  const title = { map: 'Choose map', ruleset: 'Choose ruleset', server: s.hosting ? 'Server settings' : 'Server type', options: 'Lobby options' }[kind];
  const local = localPlayer(s);
  function choose(action) { if (run(action)) close(false); }
  const limitsValid = /^\d{1,3}$/.test(String(time)) && Number(time) <= 180 && /^\d{1,3}$/.test(String(frags));
  return <div id="view-settings" className="dialog-backdrop" role="dialog" aria-modal="true" aria-labelledby="SettingsTitle">
    <Button className="dismiss-overlay" aria-label="Back to lobby" onClick={close} tabIndex={-1}/>
    <section className="dialog-panel">
      <h2 id="SettingsTitle">{title}</h2>
      {(kind === 'map' || kind === 'ruleset') && <div className="choice-list" id={kind === 'map' ? 'MapChoices' : 'RulesetChoices'}>
        {(kind === 'map' ? mapList(s) : rulesetList(s)).map(item => <Button key={item.id} className="choice" data-map={kind === 'map' ? item.id : undefined}
          disabled={!s.canConfigure || item.available === false} aria-pressed={(kind === 'map' ? s.map : s.ruleset) === item.id}
          onClick={() => choose((kind === 'map' ? 'setmap:' : 'setruleset:') + item.id)}>{item.available === false ? item.name + ' (not in this build)' : item.name}</Button>)}
      </div>}
      {kind === 'server' && s.hosting && <ServerSettings snapshot={s} close={close} setNotice={setNotice}/>}
      {kind === 'server' && !s.hosting && <div className="choice-list">
        <Button className="choice" aria-pressed="true" onClick={close}>Listen server</Button>
        <Button className="choice" disabled>Dedicated server</Button>
        <p>A player hosts this match. Dedicated server hosting is not available in this lobby.</p>
      </div>}
      {kind === 'options' && <div className="options-content">
        <div className="session-details">{s.network || 'Local'} lobby · {s.players.length} / {s.max} players</div>
        <Button className="choice" id="BtnOptionsReady" disabled={!s.canReady} onClick={onReady}>{local && local.ready ? 'Unready' : 'Ready'}</Button>
        <label className="limit-row">Time limit <input id="TimeLimit" type="number" min="0" max="180" value={time} disabled={!s.canConfigure || !s.uiVersion} onInput={e => setTime(e.currentTarget.value)}/><span>minutes</span></label>
        <label className="limit-row">Frag limit <input id="FragLimit" type="number" min="0" max="999" value={frags} disabled={!s.canConfigure || !s.uiVersion} onInput={e => setFrags(e.currentTarget.value)}/></label>
        <p>Set a limit to 0 for unlimited.</p>
        {s.isHost && <Button className="choice" disabled={!s.canConfigure || !s.uiVersion || !limitsValid}
          onClick={() => { if (run('setlimits:' + Number(time) + ':' + Number(frags))) close(false); }}>Apply limits</Button>}
      </div>}
      <Button id="BtnSettingsBack" className="dialog-back" onClick={close}>Back</Button>
    </section>
  </div>;
}
