import { h } from 'preact';
import { useState } from 'preact/hooks';
import { Button } from './Button';
import { MAPS, RULESETS, localPlayer } from '../model';

export function SettingsDialog({ kind, snapshot: s, close, run, onReady }) {
  const [time, setTime] = useState(s.timelimit === '' ? 0 : s.timelimit);
  const [frags, setFrags] = useState(s.fraglimit === '' ? 0 : s.fraglimit);
  const title = { map: 'Choose map', ruleset: 'Choose ruleset', server: 'Server type', options: 'Lobby options' }[kind];
  const local = localPlayer(s);
  function choose(action) { if (run(action)) close(false); }
  const limitsValid = /^\d{1,3}$/.test(String(time)) && Number(time) <= 180 && /^\d{1,3}$/.test(String(frags));
  return <div id="view-settings" className="dialog-backdrop" role="dialog" aria-modal="true" aria-labelledby="SettingsTitle">
    <Button className="dismiss-overlay" aria-label="Back to lobby" onClick={close} tabIndex={-1}/>
    <section className="dialog-panel">
      <h2 id="SettingsTitle">{title}</h2>
      {(kind === 'map' || kind === 'ruleset') && <div className="choice-list" id={kind === 'map' ? 'MapChoices' : 'RulesetChoices'}>
        {(kind === 'map' ? MAPS : RULESETS).map(item => <Button key={item.id} className="choice" data-map={kind === 'map' ? item.id : undefined}
          disabled={!s.canConfigure} aria-pressed={(kind === 'map' ? s.map : s.ruleset) === item.id}
          onClick={() => choose((kind === 'map' ? 'setmap:' : 'setruleset:') + item.id)}>{item.name}</Button>)}
      </div>}
      {kind === 'server' && <div className="choice-list">
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
