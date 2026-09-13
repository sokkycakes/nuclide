import { h } from 'preact';
import { useEffect, useRef, useState } from 'preact/hooks';
import { Button } from './Button';

export function ChatPanel({ snapshot: s, onSend }) {
  const [draft, setDraft] = useState('');
  const log = useRef();
  const stick = useRef(true);
  const last = s.chat.length ? s.chat[s.chat.length - 1].id : 0;
  useEffect(() => { if (log.current && stick.current) log.current.scrollTop = log.current.scrollHeight; }, [last]);
  useEffect(() => { setDraft(''); stick.current = true; }, [s.sessionId]);
  function submit(e) {
    e.preventDefault();
    const text = draft.trim();
    if (text && s.canChat && onSend(text)) { setDraft(''); stick.current = true; }
  }
  return <section className="chat" aria-label="Lobby chat" data-figma-node="72:244">
    <div id="ChatMessages" className="chat-messages" role="log" aria-live="polite" ref={log}
      onScroll={() => { const el = log.current; stick.current = el.scrollHeight - el.scrollTop - el.clientHeight < 24; }}>
      {s.chat.map(m => <div className="chat-message" key={m.id}><strong>{m.name || 'Player'}: </strong>{m.text}</div>)}
    </div>
    <form className="chat-compose" onSubmit={submit}>
      <input id="ChatInput" aria-label="Chat message" autoComplete="off" spellCheck={false} maxLength={240}
        disabled={!s.canChat} value={draft} onInput={e => setDraft(e.currentTarget.value)}
        onKeyDown={e => { if (e.key === 'Enter' && !e.isComposing) submit(e); }} />
      <Button id="BtnSendChat" type="submit" className="chat-send" disabled={!s.canChat || !draft.trim()}>send</Button>
    </form>
  </section>;
}
