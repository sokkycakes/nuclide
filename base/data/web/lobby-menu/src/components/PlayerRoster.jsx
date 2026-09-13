import { h } from 'preact';
import { Button } from './Button';

export function PlayerRoster({ snapshot: s, onCopy, onReady }) {
  return <section className="roster" aria-label="Lobby players" data-figma-node="72:245">
    <header className="roster-info">
      <Button id="BtnCopyRoomCode" className={'room-code ' + (s.room.length > 4 ? 'room-code-long' : '')}
        disabled={!s.room} onClick={onCopy} aria-label={s.room ? 'Copy room code ' + s.room : 'No room code'} title={s.room ? 'Copy room code' : 'This lobby has no room code'}>
        <span className="room-label">room<br/>code</span><span id="RoomCodeValue">{s.room || '—'}</span>
      </Button>
      <div className="player-count" aria-label={s.players.length + ' of ' + s.max + ' players'}>
        <span>{s.players.length}</span><span className="count-slash">/</span><span className="count-max">{s.max}</span>
      </div>
    </header>
    <div id="PlayersList" className="player-list" role="list" data-figma-node="72:167">
      {s.players.map(p => <div className="player-slot" role="listitem" key={p.seat}>
        <Button className={'nameplate ' + (p.ready ? 'is-ready' : '')} disabled={p.seat !== s.localSeat || !s.canReady}
          onClick={onReady} aria-label={p.name + (p.host ? ', host' : '') + (p.ready ? ', ready' : '') + (p.seat === s.localSeat ? ', toggle ready' : '')}>
          <span className="slot-name">{p.name || 'Player'}</span>
          <span className="slot-meta">{p.ready ? 'READY' : p.connected === false ? '…' : ''}</span>
        </Button>
      </div>)}
    </div>
  </section>;
}
