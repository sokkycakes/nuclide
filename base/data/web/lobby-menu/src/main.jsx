import { h, render } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import * as bridge from './bridge';
import { normalize, EMPTY, localPlayer } from './model';
import { Button } from './components/Button';
import { MapPreview } from './components/MapPreview';
import { PlayerRoster } from './components/PlayerRoster';
import { ChatPanel } from './components/ChatPanel';
import { LobbyMenu } from './components/LobbyMenu';
import { SettingsDialog } from './components/SettingsDialog';
import { installNavigation, focusFirst } from './navigation';
import escapeKey from '../assets/key-esc.png';

function LobbyApp() {
  const [snapshot, setSnapshot] = useState(EMPTY);
  const [notice, setNotice] = useState('');
  const [connectionError, setConnectionError] = useState('');
  const [dialog, setDialog] = useState('');
  const [bounds, setBounds] = useState({ left: 0, top: 0, scale: 1 });
  const root = useRef();
  const caller = useRef();
  const revision = useRef('');
  const currentDialog = useRef('');
  const lastPoll = useRef('');
  const failedSince = useRef(0);
  currentDialog.current = dialog;

  function refresh() {
    try {
      const raw = bridge.readLobby();
      failedSince.current = 0;
      setConnectionError('');
      const token = (raw.sessionId || '') + ':' + raw.revision;
      if (revision.current !== token) { revision.current = token; setNotice(''); }
      // Ignore serverTime churn outside countdown; no full UI work on idle polls.
      const key = JSON.stringify({ ...raw, serverTime: raw.phase === 'COUNTDOWN' ? Math.floor(raw.serverTime) : 0 });
      if (lastPoll.current !== key) { lastPoll.current = key; setSnapshot(normalize(raw)); }
    } catch (e) {
      // Engine queries may briefly be unavailable between updates. Keep the last
      // good state and report sustained failures separately from action notices.
      if (!failedSince.current) failedSince.current = Date.now();
      if (Date.now() - failedSince.current >= 2000) setConnectionError(e.message);
    }
  }
  function run(action) {
    if (!bridge.action(action)) { setNotice('That lobby action is unavailable.'); return false; }
    setNotice('Updating lobby…');
    setTimeout(refresh, 50);
    return true;
  }
  function toggleReady() { const p = localPlayer(snapshot); return run(p && p.ready ? 'unready' : 'ready'); }
  function openDialog(kind) {
    if (kind !== 'leave' && !snapshot.isHost) return;
    caller.current = document.activeElement; setDialog(kind);
  }
  function closeDialog(playBack = true) {
    if (playBack) bridge.menuSound('back');
    setDialog(''); setTimeout(() => { if (caller.current && !caller.current.disabled) caller.current.focus(); }, 0);
  }

  useEffect(() => {
    function resize() {
      const width = document.documentElement.clientWidth || window.innerWidth;
      const height = document.documentElement.clientHeight || window.innerHeight;
      const scale = Math.min(width / 960, height / 720);
      setBounds({ left: (width - 960 * scale) / 2, top: (height - 720 * scale) / 2, scale });
    }
    resize(); window.addEventListener('resize', resize);
    refresh(); const timer = setInterval(refresh, 250);
    const uninstall = installNavigation(root.current, () => {
      if (currentDialog.current) closeDialog(); else openDialog('leave');
    });
    return () => { clearInterval(timer); uninstall(); window.removeEventListener('resize', resize); };
  }, []);
  useEffect(() => {
    if (!snapshot.isHost && currentDialog.current && currentDialog.current !== 'leave') setDialog('');
    if (snapshot.active && (!root.current.contains(document.activeElement) || document.activeElement.disabled)) {
      const first = document.getElementById(snapshot.isHost ? 'BtnLobbyOptions' : 'BtnReady');
      if (first && !first.disabled) first.focus();
    }
  }, [snapshot.active, snapshot.isHost, snapshot.canChangeMap, snapshot.canReady, snapshot.canStart, snapshot.canCancel]);
  useEffect(() => {
    const timer = setTimeout(() => {
      if (dialog === 'leave') document.getElementById('BtnCancelLeave').focus();
      else if (dialog) focusFirst(root.current.querySelector('[aria-modal="true"]'));
    }, 0);
    return () => clearTimeout(timer);
  }, [dialog]);

  return <main id="LobbyStage" ref={root} style={{ left: bounds.left, top: bounds.top, transform: 'scale(' + bounds.scale + ')' }}>
    <section id="view-gamelobby" aria-label="Game lobby" aria-hidden={dialog ? 'true' : 'false'}>
      <div id="BgPanel" className="bg-panel" data-figma-node="109:18" aria-hidden="true"/>
      <MapPreview snapshot={snapshot}/>
      <LobbyMenu snapshot={snapshot} openSettings={openDialog} run={run} onReady={toggleReady}/>
      <PlayerRoster snapshot={snapshot} onReady={toggleReady} onCopy={() => {
        setNotice(bridge.copyCode(snapshot.room) ? 'Room code copied.' : 'Unable to copy the room code.');
      }}/>
      <ChatPanel snapshot={snapshot} onSend={text => {
        try {
          if (!bridge.sendChat(text)) { setNotice('Unable to send your message.'); return false; }
          setTimeout(refresh, 50); return true;
        } catch (e) { setNotice(e.message); return false; }
      }}/>
      <footer className="footer-hint" data-figma-node="72:281">
        <Button id="BtnLeaveLobby" className="leave-hint" disabled={!snapshot.canLeave} onClick={() => openDialog('leave')}>
          <img src={escapeKey} width="44" height="44" alt="Esc"/><span>Leave</span>
        </Button>
      </footer>
    </section>
    <div id="StatusLine" role="status" className={'status-line ' + (snapshot.error ? 'error' : '')}>{snapshot.error || connectionError || notice || (snapshot.phase === 'JOINING' || snapshot.phase === 'CLOSING' ? snapshot.status : '')}</div>
    {dialog && dialog !== 'leave' && snapshot.isHost && <SettingsDialog key={dialog} kind={dialog} snapshot={snapshot} close={closeDialog} run={run} onReady={toggleReady}/>}
    {dialog === 'leave' && <div id="LeaveConfirm" className="dialog-backdrop" role="dialog" aria-modal="true" aria-labelledby="LeaveConfirmTitle">
      <Button className="dismiss-overlay" aria-label="Stay in lobby" onClick={closeDialog} tabIndex={-1}/>
      <section className="dialog-panel leave-dialog">
        <h2 id="LeaveConfirmTitle">Leave lobby?</h2><p>{snapshot.isHost ? 'Leaving closes your lobby for everyone.' : 'You will return to the title menu.'}</p>
        <Button id="BtnConfirmLeave" className="choice" onClick={() => { if (!bridge.leave()) setNotice('Unable to leave the lobby.'); }}>Leave lobby</Button>
        <Button id="BtnCancelLeave" className="choice" onClick={closeDialog}>Stay</Button>
      </section>
    </div>}
  </main>;
}

render(<LobbyApp/>, document.getElementById('app'));
