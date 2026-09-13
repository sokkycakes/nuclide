import { h } from 'preact';
import { useRef, useState } from 'preact/hooks';
import { Button, SettingRow } from './Button';
import { localPlayer, mapTitle, countdown } from '../model';
import { GuestLock } from './GuestLock';
import { menuSound } from '../bridge';

const ROW_HEIGHT = 24;
const START_TOP = 129.568; // Keep Start/Ready at its original design position.
const BAR_HEIGHT = 24;
const barTop = index => index < 4
  ? index * ROW_HEIGHT + (ROW_HEIGHT - BAR_HEIGHT) / 2
  : START_TOP + (47.172 - BAR_HEIGHT) / 2;

export function LobbyMenu({ snapshot: s, openSettings, run, onReady }) {
  const nav = useRef(null);
  const selectedRef = useRef(-1);
  const [selected, setSelected] = useState(0);
  function select(index) {
    if (selectedRef.current === index) return;
    if (selectedRef.current >= 0) menuSound('navigate');
    selectedRef.current = index;
    setSelected(index);
  }
  function activate(action) { menuSound('confirm'); action(); }
  function row(index, action, baseClass = 'setting-row') {
    return {
      className: baseClass + ((guestLocked ? 4 : selected) === index ? ' is-selected' : ''),
      'data-lobby-index': index,
      onFocus: () => select(index),
      onMouseEnter: e => { if (!e.currentTarget.disabled) e.currentTarget.focus(); },
      onClick: () => activate(action)
    };
  }
  function wheel(e) {
    const items = Array.from(nav.current.querySelectorAll('[data-lobby-index]:not(:disabled)'));
    if (!items.length || !e.deltaY) return;
    const current = items.indexOf(document.activeElement);
    items[(current + (e.deltaY > 0 ? 1 : -1) + items.length) % items.length].focus();
    e.preventDefault();
  }
  const local = localPlayer(s);
  const counting = countdown(s);
  const guestLocked = s.active && !s.isHost;
  return <nav ref={nav} className="lobby-menu" aria-label="Lobby options" data-figma-node="72:210" onWheel={wheel}>
    {s.active && <div id="LobbyFocusBar" className="lobby-focus-bar" style={{ top: barTop(guestLocked ? 4 : selected) + 'px' }} aria-hidden="true"/>}
    <SettingRow id="BtnLobbyOptions" label="Lobby options" disabled={!s.active || !s.isHost} {...row(0, () => openSettings('options'))} />
    <SettingRow id="BtnChangeRuleset" label="Ruleset:" value={s.ruleset || '—'} disabled={!s.canConfigure || !s.uiVersion} {...row(1, () => openSettings('ruleset'))} />
    <SettingRow id="BtnChangeMap" label="Map:" value={mapTitle(s.map)} disabled={!s.canConfigure} {...row(2, () => openSettings('map'))} />
    <SettingRow id="BtnServerType" label="Server type:" value={s.serverType} disabled={!s.active || !s.isHost} {...row(3, () => openSettings('server'))} />
    {guestLocked && <GuestLock/>}
    <div className="start-row">
      {s.isHost ? <Button id={s.canCancel ? 'BtnCancel' : 'BtnStartGame'} className="start-button"
        disabled={!s.canCancel && !s.canStart} {...row(4, () => run(s.canCancel ? 'cancel' : 'start'), 'start-button')}>
        {s.canCancel ? (counting || 'Ready check') + ' · Cancel' : s.phase === 'STARTING' ? 'Starting…' : 'Start game'}
      </Button> : <Button id="BtnReady" className="start-button" disabled={!s.canReady} {...row(4, onReady, 'start-button')}>
        {counting || (local && local.ready ? 'Unready' : 'Ready')}
      </Button>}
    </div>
  </nav>;
}
