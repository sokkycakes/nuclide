# feat: Serverless Lobby Transport

## Summary

Replace `map_background` in all lobby backends (LAN, ICE/online, offline) with ICE/P2P transport so the lobby phase runs with **no game server, no map loaded, no `sv.active`**. The engine's existing ICE infrastructure (`net_ice.c`) handles peer-to-peer connections for both LAN and online. The game server is only created when the host fires `Lobby_StartGame()`.

## Problem Frame

Both `lobby_backend_lan.c` and `lobby_backend_ice.c` (via delegation) call `map_background` during lobby creation. This starts a full QuakeWorld server — loaded map, running progs, allocated client slots — just to provide a network endpoint for lobby connections. This contradicts the desired architecture (Q2Kex/L4D/Halo model) where the lobby is a pre-game session with no server.

The engine already has the infrastructure for a serverless lobby:
- `lobby_session.c` — state machine, player management, event system
- `net_ice.c` — 5944-line ICE/STUN/TURN/WebRTC implementation for P2P connectivity
- `net_ice_broker` — signaling server endpoint (part of fte master infrastructure)
- `Lobby_StartGame()` — already handles `!sv.active` case with `RESTRICT_LOCAL`

The missing piece is removing `map_background` and wiring the lobby backends to use ICE directly, without requiring `sv.active`.

## Requirements

- **R1.** No lobby backend calls `map_background` or starts a game server during the lobby phase.
- **R2.** All three backends (offline, LAN, ICE/online) follow the same pattern: P2P transport for lobby state, server created only at `Lobby_StartGame()`.
- **R3.** Clients can connect to a LAN lobby host via direct IP or LAN discovery without the host running a server.
- **R4.** Clients can connect to an online lobby host via room code and ICE broker without the host running a server.
- **R5.** When `Lobby_StartGame()` fires, the host starts the game server (`map <mapname>`), and all connected clients transition from the P2P lobby channel to normal Quake protocol against the now-running server.
- **R6.** Lobby state (player list, ready state, settings, chat) flows correctly without `sv.active` or `svs.info`.
- **R7.** The Slint lobby UI (`m_slint_lobby.c`) and QC VGUI lobby (`ui_lobby.qc`) continue to work without changes — they consume `Lobby_*()` API and cvars, not `sv.active`.

## Scope Boundaries

- **In scope:** LAN backend, ICE/online backend, lobby_session.c transition code, ICE connection management for lobby hosts.
- **Not in scope:** Changes to the QC `map_background` handler itself (still used for menu background maps). Changes to `lobby.qc` / `dm_lobby.qc` game-progs lobby. Slint or VGUI UI changes. New external infrastructure.
- **Deferred:** LAN broadcast-based lobby discovery (use direct IP:port join for first pass). TURN relay support for symmetric NATs.

## High-Level Technical Design

### Transport Architecture

```
                    Lobby Phase (no server)
Host:                                                  Client:
  Lobby_Create(net)                                      lobby_join(addr|room)
    → ICE listen endpoint (islisten=true)                  → ICE connect to host
    → register with broker (online)                        → establish P2P data channel
      or direct ICE (LAN)                                  ← lobby state via ICE →
    → NO sv.active                                       ← player list, ready, settings →
    → NO map loaded                                      ← chat →
    → poll via Lobby_RunFrame()

                    Game Start Transition

Host: Lobby_StartGame()
    → send "game_starting" + server IP:port over ICE
    → Cbuf_AddText(va("map %s\n", mapname), RESTRICT_LOCAL)
      → NOW sv.active, server running
    → Lobby_EventSink fires LOBBY_EVT_GAME_STARTING

Client:
    ← receive server IP:port from ICE channel
    → disconnect ICE
    → Cbuf_AddText(va("connect %s\n", server_ip_port), RESTRICT_LOCAL)
    → normal Quake protocol against running server
```

### State flow during lobby (no sv.active)

```
lobby_session.c (struct lobby) ──→ Lobby_SyncCvars() ──→ lobby_* cvars
                                       │                     │
                                  Lobby_Emit()           ui_lobby.qc reads
                                       │                     │
                              Lobby_EventSink ─────→ m_slint_lobby.c reads
```

### ICE connection for the host (new code in lobby_backend)

The host creates a `ftenet_ice_connection_t` with `islisten=true`, registers with the broker (online) or uses direct STUN (LAN), and polls for incoming client connections in `Lobby_RunFrame()`. The existing `FTENET_ICE_EstablishConnection` handles the broker registration; the lobby backend creates the appropriate connection struct and manages its lifecycle.


## Key Technical Decisions

### KTD1. ICE for all backends

All lobby backends use ICE/P2P transport. LAN and online share the same connection code; only discovery differs (online uses broker registration, LAN uses direct STUN with optional broadcast). This avoids maintaining two transport implementations and ensures consistent behavior.

### KTD2. Lobby ICE connection managed by lobby_session infrastructure

The lobby creates and manages its own ICE connection - not tied to cls.net_con or svs.relay. The lobby backend holds a reference to the ICE connection and polls it in Lobby_RunFrame(). This keeps the lobby independent of the game server lifecycle.

### KTD3. Game-start transition uses ICE data channel for signaling

When Lobby_StartGame() fires, the host sends a structured message over the ICE data channel containing the game server IP and port. Clients receive this, close the ICE connection, and issue connect <ip:port>. The host simultaneously starts map <mapname> via RESTRICT_LOCAL.

### KTD4. No QC changes needed

The QC lobby (lobby.qc, dm_lobby.qc) runs inside game progs and only activates after map is called. The engine-side lobby session manages the pre-game phase entirely in C, exposing state via cvars for the VGUI UI and via event sinks for the Slint UI.

## Implementation Units

### U1. Refactor lobby_backend_lan.c - ICE transport for LAN

**Goal:** Replace map_background in the LAN backend with an ICE listen endpoint. The host creates an ICE connection with islisten=true, no server, no map.

**Requirements:** R1, R2, R3

**Dependencies:** None

**Files:**
- Modify: workspace/fteqw/engine/common/lobby_backend_lan.c
- May modify: workspace/fteqw/engine/common/lobby_session.h (add ICE connection pointer to lobby struct)

**Approach:**
- Replace the map_background Cbuf_AddText call with code that creates an ICE listen endpoint
- The backend holds a ftenet_ice_connection_t* that it creates in the create() callback
- For LAN discovery: host can broadcast presence via UDP heartbeat or clients connect by direct IP
- Poll the ICE connection for inbound player connections in the poll() callback
- On destroy(): close the ICE connection

**Patterns:**
- FTENET_ICE_EstablishConnection in net_ice.c for creating ICE connections
- The existing lobby_backend_lan.c structure

**Test scenarios:**
1. Host creates a LAN lobby - no server starts, no map loads, sv.active is false
2. Client connects to LAN lobby host via lobby_join <ip:port> - P2P channel established
3. Lobby state (player join, ready, settings) syncs correctly over ICE channel
4. Destroy/close cleans up ICE connection

**Verification:** Start LAN lobby, verify sv.active is false and no map is loaded. Client connects and appears in player list.

### U2. Refactor lobby_backend_ice.c - remove LAN delegate

**Goal:** Stop delegating to lobby_backend_lan.create() for the host. The ICE backend independently creates an ICE listen endpoint and registers with the broker.

**Requirements:** R1, R2, R4

**Dependencies:** U1 (ICE connection management patterns established)

**Files:**
- Modify: workspace/fteqw/engine/common/lobby_backend_ice.c
- May modify: workspace/fteqw/engine/common/lobby_session.c (if ICE registration needs broker integration)

**Approach:**
- Remove the lobby_backend_lan.create() delegation in LobbyBackend_Ice_Create
- Instead, directly create an ICE listen endpoint that registers with the broker
- The broker registration uses the existing net_ice_broker connection path
- The room code is returned from the broker and stored in lobby.room_code
- Poll ICE connections for inbound players

**Patterns:**
- The existing client-side connect rtc://broker/gamename flow in net_ice.c as reference
- lobby_backend_lan.c after U1 for ICE creation patterns

**Test scenarios:**
1. Host creates online lobby - registers with broker, gets room code, no server starts
2. Client joins via lobby_join <roomcode> - establishes ICE channel via broker
3. Multiple clients connect concurrently
4. Broker disconnect/reconnect handling

**Verification:** Start online lobby, verify broker registration succeeds, client joins via room code, no server running.

### U3. Fix Lobby_StartGame() transition

**Goal:** Ensure the host-to-client transition from lobby P2P to game server works correctly. Clients receive the server connection info and reconnect.

**Requirements:** R5

**Dependencies:** U1, U2

**Files:**
- Modify: workspace/fteqw/engine/common/lobby_session.c
- Modify: workspace/fteqw/engine/common/lobby_session.h (add game_start callback or message type)
- Modify: workspace/fteqw/engine/common/lobby_backend_lan.c
- Modify: workspace/fteqw/engine/common/lobby_backend_ice.c

**Approach:**
- When Lobby_StartGame() fires, the backends send a structured notification over the ICE data channel: { "cmd": "game_starting", "address": "<host_ip:port>", "map": "<mapname>" }
- The host simultaneously starts the game server: Cbuf_AddText(va("map %s\n", mapname), RESTRICT_LOCAL)
- Client-side: when the ICE data channel delivers the game_starting message, the client calls Lobby_Leave() then Cbuf_AddText(va("connect %s\n", address), RESTRICT_LOCAL)
- For LAN, the host IP is already known from the ICE connection. For online, the host sends its public address.
- The existing lobby event system fires LOBBY_EVT_GAME_STARTING which UIs can use to show status.

**Test scenarios:**
1. Host fires Lobby_StartGame() - server starts with correct map, clients receive notification
2. Client receives game_starting message - disconnects from lobby, connects to game server
3. Client joins game server after host - game is in progress, client connects normally
4. Client still in lobby when host starts game - notification arrives, client transitions

**Verification:** Full lobby-to-game flow: create lobby, client joins, host starts, both end up on the same game server playing.

### U4. Fix lobby state sync without sv.active

**Goal:** Lobby state (player list, ready state, settings, room code) propagates correctly when there's no server running. Lobby_SyncServerInfo and Lobby_ClientSyncFromServerInfo are no-ops without sv.active, but the state still needs to reach clients.

**Requirements:** R6

**Dependencies:** U1, U2

**Files:**
- Modify: workspace/fteqw/engine/common/lobby_session.c
- Modify: workspace/fteqw/engine/common/lobby_backend_lan.c
- Modify: workspace/fteqw/engine/common/lobby_backend_ice.c

**Approach:**
- Lobby_SyncCvars() already works independently of sv.active - it writes lobby_* cvars from the struct lobby state
- The ICE backends send player/state updates over the P2P data channel on every state change
- On the client side, received state updates populate the local lobby struct directly - no need for serverinfo
- For clients, the lobby struct fields are populated from received ICE messages, and Lobby_SyncCvars() runs to update QC-visible cvars

**Test scenarios:**
1. Player joins/leaves lobby - all clients see updated player list (via ICE)
2. Player toggles ready - all clients see ready state change
3. Host changes settings (map, ruleset) - all clients receive updated settings
4. Chat messages sent - all clients receive chat
5. Lobby state survives host migration (deferred)

**Verification:** Create lobby, client joins, both see same player list and ready state. Settings changes propagate.

### U5. Fix lobby_join for LAN without server

**Goal:** lobby_join <ip:port> for LAN works without requiring a running Quake server on the target address. Currently Lobby_Join falls through to connect <ip> which expects sv.active.

**Requirements:** R3

**Dependencies:** U1, U3

**Files:**
- Modify: workspace/fteqw/engine/common/lobby_session.c (Lobby_Join for LAN path)

**Approach:**
- When lobby_join receives an IP:port (LAN mode detected by dots/colons in the address), it establishes an ICE connection to the host instead of issuing a Quake connect
- The ICE layer already handles direct connections - use FTENET_ICE_EstablishConnection with the target IP:port
- The host ICE endpoint accepts the connection and adds the player to the lobby
- When game starts, the game_starting message includes the server IP:port for the Quake connect

**Test scenarios:**
1. lobby_join 192.168.1.100:27500 - establishes ICE connection to host, no Quake connect
2. Host starts game - client receives server info and connects via Quake protocol
3. Invalid address - graceful failure

**Verification:** Full join flow on LAN without server.

## Risks and Dependencies

| Risk | Mitigation |
|------|------------|
| ICE listen endpoint requires net_ice.c infrastructure that may assume sv.active (server-side ICE connections are created as part of svs.relay) | Audit FTENET_ICE_Establish and the ICE polling path for sv.active assumptions. Create test ICE listen endpoint outside server context to verify. |
| Broker registration fails or broker is unavailable (online mode) | Fall back to LAN mode. Report connection status to user via lobby state. |
| ICE connection lifecycle management conflicts with existing server ICE connections | Keep lobby ICE connections in a separate struct managed by the backend, not in svs.relay. |
| Game-start transition race: client connects to server before it is ready | Client retries connect with a short delay. Server is ready quickly since map load is fast without client downloads. |
| Symmetric NAT on LAN prevents direct STUN connection | Deferred: TURN relay support. Initial implementation works for open/cone NAT and direct LAN. |

## Open Questions

- **Deferred to implementation:** Whether the lobby ICE connection should use a standalone ftenet_connections_t or integrate into the existing one. The former is cleaner but may duplicate initialization; the latter may have unintended side effects.
- **Deferred to implementation:** Wire format for ICE data channel messages during lobby phase - JSON or simple key-value. The existing Lobby_Kex_OnRule/OnPlayer pattern suggests structured key-value.
- **Deferred to implementation:** LAN discovery - broadcast heartbeat or require manual IP:port. Manual IP:port for initial implementation; broadcast deferred.
- **Deferred to implementation:** Port selection for LAN lobby (fixed port vs dynamic with registration).

## System-Wide Impact

- **Lobby_session.c:** No structural changes. Lobby_SyncCvars() continues to work. Lobby_StartGame() path split (sv.active vs !sv.active) is already handled.
- **Net_ice.c:** No changes needed. The ICE layer already supports standalone connections.
- **Client networking:** The lobby-to-game transition introduces a brief disconnect-reconnect sequence visible to the player as a loading screen when the game starts.
- **QC progs (lobby.qc):** Unchanged - these activate after map is called, which only happens at Lobby_StartGame().
- **Menu UI (ui_lobby.qc):** Unchanged - reads lobby_* cvars which continue to be populated by Lobby_SyncCvars().
- **Slint UI (m_slint_lobby.c):** Unchanged - uses Lobby_*() API and event sinks.
- **Build:** No new source files added. Only modifications to existing lobby_backend_*.c and lobby_session.c files in workspace/fteqw/engine/common/.
