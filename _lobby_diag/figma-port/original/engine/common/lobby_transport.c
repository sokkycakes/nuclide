/*
 * lobby_transport.c — reliable lobby carrier (included into lobby_session.c)
 *
 * Schema: U join, A accept, X reject, P player, K rule, R ready, D leave,
 *   G game_starting (map|connect_target), H heartbeat, ! reliable wrap, = ack
 * Protocol version LOBBY_PROTO_VER in join/accept.
 */

#define LOBBY_PROTO_VER			1
#define LOBBY_REL_SLOTS			48
#define LOBBY_REL_TRIES			16
#define LOBBY_REL_INTERVAL		0.22
#define LOBBY_PEER_TIMEOUT		10.0
#define LOBBY_HB_INTERVAL		1.5
#define LOBBY_SYNC_INTERVAL		2.0
#define LOBBY_SEEN_RING			64

/* Q_snprintfz returns truncation (qboolean), NOT byte length. */
static int Lobby_FmtMsg(char *buf, size_t bufsz, const char *fmt, ...)
{
	va_list argptr;
	int n;
	va_start(argptr, fmt);
#ifdef _WIN32
	n = _vsnprintf(buf, bufsz, fmt, argptr);
	if (n < 0 || (size_t)n >= bufsz) { buf[bufsz - 1] = 0; n = (int)strlen(buf); }
#else
	n = vsnprintf(buf, bufsz, fmt, argptr);
	if (n < 0) n = 0;
	if ((size_t)n >= bufsz) n = (int)bufsz - 1;
#endif
	va_end(argptr);
	return n;
}


static struct ftenet_connections_s *lobby_tport_col;
static qboolean lobby_tport_external;
static netadr_t lobby_peer_addrs[LOBBY_MAX_PLAYERS];
static int lobby_peer_seats[LOBBY_MAX_PLAYERS];
static double lobby_peer_last[LOBBY_MAX_PLAYERS];
static int lobby_num_peers;
static unsigned lobby_msg_seq;

static qboolean lobby_join_pending;
static float lobby_join_next_retry;
static int lobby_join_attempts;
static char lobby_join_name[64];

static double lobby_next_hb;
static double lobby_next_sync;
static double lobby_host_last;

typedef struct
{
	unsigned	seq;
	double		next_send;
	int			tries;
	netadr_t	to;
	qboolean	has_adr;
	int			to_seat;	/* >=0: reseat lookup each send; -1 + has_adr: fixed */
	char		msg[640];
	int			len;
} lobby_rel_t;

static lobby_rel_t lobby_rel[LOBBY_REL_SLOTS];
static unsigned lobby_out_seq;
static unsigned lobby_seen_seq[LOBBY_SEEN_RING];
static int lobby_seen_n;

static cvar_t lobby_port = CVARD("lobby_port", "27501", "UDP port for pre-game lobby transport.");

unsigned short Lobby_Transport_GetPort(void)
{
	unsigned short port = (unsigned short)lobby_port.ival;
	return port ? port : 27501;
}

void Lobby_Transport_RegisterCvars(void)
{
	Cvar_Register(&lobby_port, "Lobby");
}

static int Lobby_Transport_FindPeer(int seat)
{
	int i;
	for (i = 0; i < lobby_num_peers; i++)
		if (lobby_peer_seats[i] == seat)
			return i;
	return -1;
}

static void Lobby_Transport_AddPeer(int seat, netadr_t *addr)
{
	int idx = Lobby_Transport_FindPeer(seat);
	extern double realtime;
	if (idx >= 0)
	{
		lobby_peer_addrs[idx] = *addr;
		lobby_peer_last[idx] = realtime;
		return;
	}
	if (lobby_num_peers >= LOBBY_MAX_PLAYERS)
		return;
	lobby_peer_seats[lobby_num_peers] = seat;
	lobby_peer_addrs[lobby_num_peers] = *addr;
	lobby_peer_last[lobby_num_peers] = realtime;
	lobby_num_peers++;
}

static void Lobby_Transport_RemovePeer(int seat)
{
	int idx = Lobby_Transport_FindPeer(seat);
	if (idx < 0)
		return;
	lobby_num_peers--;
	lobby_peer_seats[idx] = lobby_peer_seats[lobby_num_peers];
	lobby_peer_addrs[idx] = lobby_peer_addrs[lobby_num_peers];
	lobby_peer_last[idx] = lobby_peer_last[lobby_num_peers];
}

static qboolean Lobby_Transport_PeerOwnsAdr(int seat, netadr_t *adr)
{
	int idx = Lobby_Transport_FindPeer(seat);
	if (idx < 0 || !adr)
		return false;
	return NET_CompareAdr(&lobby_peer_addrs[idx], adr);
}

/* ponytail: join retries re-send U:; reuse seat for same endpoint instead of allocating ghosts. */
static int Lobby_Transport_FindSeatByAdr(netadr_t *adr)
{
	int i;
	if (!adr)
		return -1;
	for (i = 0; i < lobby_num_peers; i++)
		if (NET_CompareAdr(&lobby_peer_addrs[i], adr))
			return lobby_peer_seats[i];
	return -1;
}

static qboolean Lobby_Transport_SeenSeq(unsigned seq)
{
	int i;
	for (i = 0; i < lobby_seen_n && i < LOBBY_SEEN_RING; i++)
		if (lobby_seen_seq[i] == seq)
			return true;
	return false;
}

static void Lobby_Transport_RememberSeq(unsigned seq)
{
	if (lobby_seen_n < LOBBY_SEEN_RING)
		lobby_seen_seq[lobby_seen_n++] = seq;
	else
	{
		memmove(lobby_seen_seq, lobby_seen_seq + 1, (LOBBY_SEEN_RING - 1) * sizeof(lobby_seen_seq[0]));
		lobby_seen_seq[LOBBY_SEEN_RING - 1] = seq;
	}
}

static qboolean Lobby_Transport_ParseUdpAdr(const char *addrstr, netadr_t *adr)
{
	char buf[256];

	if (!addrstr || !*addrstr || !adr)
		return false;

	if (!Q_strncasecmp(addrstr, "udp://", 6) ||
		!Q_strncasecmp(addrstr, "udp4://", 7) ||
		!Q_strncasecmp(addrstr, "udp6://", 7))
		Q_strncpyz(buf, addrstr, sizeof(buf));
	else
		Q_snprintfz(buf, sizeof(buf), "udp://%s", addrstr);

	memset(adr, 0, sizeof(*adr));
	if (!NET_StringToAdr(buf, Lobby_Transport_GetPort(), adr))
		return false;
	if (adr->type != NA_IP && adr->type != NA_IPV6)
		return false;

	adr->prot = NP_DGRAM;
	adr->connum = 0;
	return true;
}

static qboolean Lobby_Transport_SendAdr(netadr_t *to, const void *data, size_t len)
{
	char adr[64];
	neterr_t err;

	if (!lobby_tport_col || !to || !data || !len)
		return false;

	err = NET_SendPacket(lobby_tport_col, (int)len, data, to);
	if (err != NETERR_SENT)
	{
		Con_Printf("Lobby: send to %s failed (%i)\n",
			NET_AdrToString(adr, sizeof(adr), to), (int)err);
		return false;
	}
	return true;
}

static void Lobby_Transport_SendAck(netadr_t *to, unsigned seq)
{
	char ack[32];
	int n = Lobby_FmtMsg(ack, sizeof(ack), "=:%u", seq);
	if (n > 0)
		Lobby_Transport_SendAdr(to, ack, (size_t)n);
}

static qboolean Lobby_Transport_QueueReliable(netadr_t *to, int to_seat, const void *data, size_t len)
{
	int i, slot = -1;
	lobby_rel_t *r;
	char wrapped[700];
	int n;
	extern double realtime;

	if (!data || !len || len >= 600)
		return false;

	lobby_out_seq++;
	if (!lobby_out_seq)
		lobby_out_seq = 1;
	n = Lobby_FmtMsg(wrapped, sizeof(wrapped), "!:%u:", lobby_out_seq);
	if (n <= 0 || n + (int)len >= (int)sizeof(wrapped))
		return false;
	memcpy(wrapped + n, data, len);
	n += (int)len;

	for (i = 0; i < LOBBY_REL_SLOTS; i++)
	{
		if (!lobby_rel[i].len)
		{
			slot = i;
			break;
		}
	}
	if (slot < 0)
		slot = (int)(lobby_out_seq % LOBBY_REL_SLOTS);

	r = &lobby_rel[slot];
	memset(r, 0, sizeof(*r));
	r->seq = lobby_out_seq;
	r->tries = 0;
	r->next_send = 0;
	r->to_seat = to_seat;
	r->has_adr = to != NULL;
	if (to)
		r->to = *to;
	r->len = n;
	memcpy(r->msg, wrapped, (size_t)n);
	/* Immediate first send; TickReliable handles retries. */
	{
		netadr_t *dest = to;
		int idx;
		if (!dest && to_seat >= 0)
		{
			idx = Lobby_Transport_FindPeer(to_seat);
			if (idx >= 0)
				dest = &lobby_peer_addrs[idx];
		}
		if (dest)
		{
			r->tries = 1;
			Lobby_Transport_SendAdr(dest, r->msg, (size_t)r->len);
			r->next_send = realtime + LOBBY_REL_INTERVAL;
			return true;
		}
		/* Queued until peer address appears. */
		r->next_send = realtime;
		return false;
	}
}

static qboolean Lobby_Transport_SendReliableAdr(netadr_t *to, const void *data, size_t len)
{
	return Lobby_Transport_QueueReliable(to, -1, data, len);
}

static qboolean Lobby_Transport_SendReliableSeat(int seat, const void *data, size_t len)
{
	return Lobby_Transport_QueueReliable(NULL, seat, data, len);
}

static void Lobby_Transport_AckSeq(unsigned seq)
{
	int i;
	for (i = 0; i < LOBBY_REL_SLOTS; i++)
	{
		if (lobby_rel[i].len && lobby_rel[i].seq == seq)
		{
			lobby_rel[i].len = 0;
			return;
		}
	}
}

static void Lobby_Transport_TickReliable(void)
{
	int i;
	extern double realtime;

	for (i = 0; i < LOBBY_REL_SLOTS; i++)
	{
		lobby_rel_t *r = &lobby_rel[i];
		netadr_t *to;
		int idx;

		if (!r->len)
			continue;
		if (realtime < r->next_send)
			continue;

		to = NULL;
		if (r->to_seat >= 0)
		{
			idx = Lobby_Transport_FindPeer(r->to_seat);
			if (idx >= 0)
				to = &lobby_peer_addrs[idx];
		}
		else if (r->has_adr)
			to = &r->to;

		if (!to)
		{
			r->len = 0;
			continue;
		}

		r->tries++;
		if (r->tries > LOBBY_REL_TRIES)
		{
			Con_DPrintf("Lobby: reliable seq %u gave up\n", r->seq);
			r->len = 0;
			continue;
		}
		Lobby_Transport_SendAdr(to, r->msg, (size_t)r->len);
		r->next_send = realtime + LOBBY_REL_INTERVAL;
	}
}

static void Lobby_Transport_SendReject(netadr_t *to, const char *reason)
{
	char msg[128];
	int n = Lobby_FmtMsg(msg, sizeof(msg), "X:-1:%s", reason ? reason : "rejected");
	if (n > 0)
		Lobby_Transport_SendReliableAdr(to, msg, (size_t)n);
}

static void Lobby_Transport_ReplyInfo(qboolean fullstatus)
{
	char response[1024];
	char info[768];
	const char *mapname;
	const char *room;
	int n;

	if (!lobby_tport_col || !Lobby_IsHost())
		return;

	mapname = Lobby_GetMap();
	if (!mapname || !*mapname)
		mapname = "lobby";
	room = Lobby_GetRoomCode();

	Q_snprintfz(info, sizeof(info),
		"\\hostname\\%s\\map\\%s\\mapname\\%s\\clients\\%i\\maxclients\\%i\\sv_maxclients\\%i\\lobby\\1\\lobby_proto\\%i\\room\\%s\\gamedir\\lobby",
		Lobby_GetHostName(),
		mapname, mapname,
		Lobby_GetPlayerCount(),
		Lobby_GetMaxPlayers(),
		Lobby_GetMaxPlayers(),
		LOBBY_PROTO_VER,
		room && *room ? room : "");

	n = Lobby_FmtMsg(response, sizeof(response), "\xff\xff\xff\xff%s\n%s",
		fullstatus ? "statusResponse" : "infoResponse", info);
	if (n > 0 && n + 1 < (int)sizeof(response))
		n++;
	if (n > 0)
	{
		char adr[64];
		NET_SendPacket(lobby_tport_col, n, response, &net_from);
		Con_DPrintf("Lobby: answered %s from %s\n",
			fullstatus ? "getstatus" : "getinfo",
			NET_AdrToString(adr, sizeof(adr), &net_from));
	}
}

static void Lobby_Transport_SendPlayerSnapshotAdr(netadr_t *to, int player_seat)
{
	lobby_player_t *p;
	char msg[2048], infostr[1024];
	int n;

	p = Lobby_FindPlayerBySeat(player_seat);
	if (!p || !to)
		return;

	Q_snprintfz(infostr, sizeof(infostr),
		"\\name\\%s\\ready\\%s\\host\\%s",
		p->name,
		p->ready ? "1" : "0",
		p->is_host ? "1" : "0");
	n = Lobby_FmtMsg(msg, sizeof(msg), "P:%d:%s", player_seat, infostr);
	if (n > 0)
		Lobby_Transport_SendReliableAdr(to, msg, (size_t)n);
}

static void Lobby_Transport_PushRosterAdr(netadr_t *to)
{
	int s;
	const char *map;
	char rule[512];
	int n;

	for (s = 0; s < LOBBY_MAX_PLAYERS; s++)
	{
		if (Lobby_FindPlayerBySeat(s))
			Lobby_Transport_SendPlayerSnapshotAdr(to, s);
	}
	map = Lobby_GetMap();
	if (map && *map)
	{
		n = Lobby_FmtMsg(rule, sizeof(rule), "K:-1:map=%s", map);
		if (n > 0)
			Lobby_Transport_SendReliableAdr(to, rule, (size_t)n);
	}
	if (Lobby_GetRoomCode()[0])
	{
		n = Lobby_FmtMsg(rule, sizeof(rule), "K:-1:room=%s", Lobby_GetRoomCode());
		if (n > 0)
			Lobby_Transport_SendReliableAdr(to, rule, (size_t)n);
	}
}

void Lobby_Transport_PushFullSync(void)
{
	int i, s;
	if (!lobby_tport_col || !Lobby_IsHost())
		return;
	for (i = 0; i < lobby_num_peers; i++)
	{
		for (s = 0; s < LOBBY_MAX_PLAYERS; s++)
		{
			if (Lobby_FindPlayerBySeat(s))
				Lobby_Transport_SendPlayerSnapshotAdr(&lobby_peer_addrs[i], s);
		}
	}
	{
		const char *map = Lobby_GetMap();
		if (map && *map)
			Lobby_Transport_BroadcastRule("map", map);
	}
}

void Lobby_Transport_BroadcastRule(const char *key, const char *value)
{
	char msg[512];
	int n;
	if (!key || !value)
		return;
	n = Lobby_FmtMsg(msg, sizeof(msg), "K:-1:%s=%s", key, value);
	if (n > 0)
	{
		int i;
		for (i = 0; i < lobby_num_peers; i++)
			Lobby_Transport_SendReliableAdr(&lobby_peer_addrs[i], msg, (size_t)n);
	}
}

void Lobby_Transport_BroadcastGameStarting(const char *mapname, const char *connect_target)
{
	char msg[512];
	int n, i;
	lobby_msg_seq++;
	/* Sole start encoding: G:-1:map|connect_target — never S:+net_from */
	n = Lobby_FmtMsg(msg, sizeof(msg), "G:-1:%s|%s",
		mapname ? mapname : "start",
		connect_target ? connect_target : "127.0.0.1:27500");
	if (n <= 0)
		return;
	for (i = 0; i < lobby_num_peers; i++)
		Lobby_Transport_SendReliableAdr(&lobby_peer_addrs[i], msg, (size_t)n);
}

/* Per-peer start commit (LAN loopback vs LAN IP vs online rtc). */
void Lobby_Transport_SendGameStartingToPeers(const char *mapname,
	const char *(*target_for_peer)(int seat, void *ctx), void *ctx)
{
	int i;
	char msg[512];
	int n;
	const char *target;
	lobby_msg_seq++;
	for (i = 0; i < lobby_num_peers; i++)
	{
		target = target_for_peer ? target_for_peer(lobby_peer_seats[i], ctx) : NULL;
		if (!target || !*target)
			target = "127.0.0.1:27500";
		n = Lobby_FmtMsg(msg, sizeof(msg), "G:-1:%s|%s",
			mapname ? mapname : "start", target);
		if (n > 0)
			Lobby_Transport_SendReliableAdr(&lobby_peer_addrs[i], msg, (size_t)n);
	}
}

static void Lobby_Transport_Relay(int exclude_seat, const void *data, size_t len)
{
	int i;
	if (!lobby_tport_col)
		return;
	for (i = 0; i < lobby_num_peers; i++)
	{
		if (exclude_seat >= 0 && lobby_peer_seats[i] == exclude_seat)
			continue;
		Lobby_Transport_SendReliableAdr(&lobby_peer_addrs[i], data, len);
	}
}

static void Lobby_Transport_SendJoinRequest(void)
{
	char msg[256];
	int n;

	n = Lobby_FmtMsg(msg, sizeof(msg), "U:-1:v%i|%s", LOBBY_PROTO_VER, lobby_join_name);
	if (n <= 0)
		return;
	/* Always fire-and-forget first so join works before reliable peer tables settle. */
	if (!Lobby_Transport_SendTo(0, msg, (size_t)n))
	{
		/* No route yet (typical for ICE before peer-up) — retry without burning status. */
		Con_DPrintf("Lobby: join waiting for host route (attempt %i)\n", lobby_join_attempts);
		return;
	}
	Lobby_Transport_SendReliableSeat(0, msg, (size_t)n);
	Con_Printf("Lobby: join request -> %s (attempt %i)\n",
		Lobby_Transport_GetPeerAddress(0)[0]
			? Lobby_Transport_GetPeerAddress(0)
			: "?",
		lobby_join_attempts);
}

void Lobby_Transport_NoteIcePeer(netadr_t *adr)
{
	if (!adr || adr->type == NA_INVALID)
		return;
	/* Joiner: host is seat 0. Host peers are bound on accept (U:). */
	if (!Lobby_IsHost() && Lobby_GetLocalSeat() < 0)
	{
		Lobby_Transport_AddPeer(0, adr);
		Con_Printf("Lobby: ICE route to host ready\n");
	}
}

void Lobby_Transport_BeginJoin(const char *playername)
{
	Q_strncpyz(lobby_join_name, (playername && *playername) ? playername : "Player",
		sizeof(lobby_join_name));
	lobby_join_pending = true;
	lobby_join_attempts = 0;
	lobby_join_next_retry = 0;
}

void Lobby_Transport_CancelJoin(void)
{
	lobby_join_pending = false;
	lobby_join_attempts = 0;
	lobby_join_name[0] = 0;
}

static void Lobby_Transport_TickJoin(void)
{
	extern double realtime;

	if (!lobby_join_pending || !Lobby_IsActive() || Lobby_IsHost())
		return;
	if (Lobby_GetLocalSeat() >= 0)
	{
		lobby_join_pending = false;
		return;
	}
	if (lobby_join_attempts >= 60)
	{
		Con_Printf(CON_ERROR "Lobby: host did not answer join after %i attempts.\n",
			lobby_join_attempts);
		Q_strncpyz(lobby.status, "Join failed - host not responding.", sizeof(lobby.status));
		Lobby_SyncCvars();
		lobby_join_pending = false;
		return;
	}
	if (realtime < lobby_join_next_retry)
		return;

	lobby_join_attempts++;
	Lobby_Transport_SendJoinRequest();
	/* ICE may need longer before a send route exists. */
	lobby_join_next_retry = realtime + ((Lobby_Transport_FindPeer(0) < 0) ? 1.0 : 0.5);
}

static void Lobby_Transport_ReadPacket_cb(void)
{
	Lobby_Transport_HandleInbound();
}

void Lobby_Transport_HandleInbound(void)
{
	char msg[1024];
	char *raw;
	int len, seat;
	char *p, *val;
	char adrbuf[64];
	unsigned rel_seq = 0;
	qboolean was_reliable = false;
	extern double realtime;

	if (!Lobby_IsActive())
		return;

	/* ICE joiner: learn host route from first inbound datagram. */
	if (!Lobby_IsHost() && Lobby_GetLocalSeat() < 0 && net_from.type != NA_INVALID
		&& Lobby_Transport_FindPeer(0) < 0)
		Lobby_Transport_AddPeer(0, &net_from);

	len = net_message.cursize;
	if (len < 2 || len >= (int)sizeof(msg))
		return;
	memcpy(msg, net_message.data, len);
	msg[len] = 0;
	raw = msg;

	if (len >= 8 &&
		(unsigned char)msg[0] == 0xff && (unsigned char)msg[1] == 0xff &&
		(unsigned char)msg[2] == 0xff && (unsigned char)msg[3] == 0xff)
	{
		if (!strncmp(msg + 4, "getinfo", 7))
		{
			Lobby_Transport_ReplyInfo(false);
			return;
		}
		if (!strncmp(msg + 4, "getstatus", 9))
		{
			Lobby_Transport_ReplyInfo(true);
			return;
		}
	}

	/* Ack: =:seq */
	if (msg[0] == '=' && msg[1] == ':')
	{
		Lobby_Transport_AckSeq((unsigned)atoi(msg + 2));
		return;
	}

	/* Reliable wrap: !:seq:payload */
	if (msg[0] == '!' && msg[1] == ':')
	{
		char *sp = strchr(msg + 2, ':');
		if (!sp)
			return;
		rel_seq = (unsigned)atoi(msg + 2);
		Lobby_Transport_SendAck(&net_from, rel_seq);
		if (Lobby_Transport_SeenSeq(rel_seq))
			return;
		Lobby_Transport_RememberSeq(rel_seq);
		raw = sp + 1;
		len = (int)strlen(raw);
		was_reliable = true;
	}

	p = strchr(raw, ':');
	if (!p)
		return;
	seat = atoi(p + 1);
	p = strchr(p + 1, ':');
	val = p ? p + 1 : NULL;

	switch (raw[0])
	{
	case 'H':
		/* Heartbeat — touch peer last-seen. */
		if (Lobby_IsHost() && seat >= 0)
		{
			int idx = Lobby_Transport_FindPeer(seat);
			if (idx >= 0 && Lobby_Transport_PeerOwnsAdr(seat, &net_from))
				lobby_peer_last[idx] = realtime;
		}
		else if (!Lobby_IsHost())
			lobby_host_last = realtime;
		(void)was_reliable;
		break;
	case 'X':
		if (Lobby_IsHost() || !val)
			break;
		Q_snprintfz(lobby.status, sizeof(lobby.status), "Join rejected: %s", val);
		Q_strncpyz(lobby.error, val, sizeof(lobby.error));
		Lobby_SyncCvars();
		Con_Printf(CON_ERROR "Lobby: join rejected (%s)\n", val);
		lobby_join_pending = false;
		break;
	case 'U':
		if (!Lobby_IsHost() || !val)
			break;
		{
			const char *name = val;
			int ver = 0;
			if (!strncmp(val, "v", 1))
			{
				char *bar = strchr(val, '|');
				ver = atoi(val + 1);
				if (bar)
					name = bar + 1;
			}
			if (ver && ver != LOBBY_PROTO_VER)
			{
				Lobby_Transport_SendReject(&net_from, "version");
				break;
			}
			if (Lobby_RejectsJoins())
			{
				Lobby_Transport_SendReject(&net_from, "busy");
				break;
			}
			{
				int existing = Lobby_Transport_FindSeatByAdr(&net_from);
				qboolean rejoin = false;
				if (existing >= 0)
				{
					seat = existing;
					rejoin = true;
				}
				else if (seat < 0)
				{
					int s;
					seat = -1;
					for (s = 0; s < LOBBY_MAX_PLAYERS; s++)
					{
						if (!Lobby_FindPlayerBySeat(s))
						{
							seat = s;
							break;
						}
					}
					if (seat < 0)
					{
						Lobby_Transport_SendReject(&net_from, "full");
						break;
					}
				}
				Lobby_Transport_AddPeer(seat, &net_from);
				if (!rejoin)
				{
					Lobby_Kex_OnPlayer(seat, va("\\name\\%s\\ready\\0", name), false);
					Con_Printf("Lobby: accepted join from %s -> seat %d (%s)\n",
						NET_AdrToString(adrbuf, sizeof(adrbuf), &net_from), seat, name);
				}
				{
					char reply[256];
					int n = Lobby_FmtMsg(reply, sizeof(reply), "A:%d:v%i|%s", seat, LOBBY_PROTO_VER, name);
					if (n > 0)
						Lobby_Transport_SendReliableAdr(&net_from, reply, (size_t)n);
					Lobby_Transport_PushRosterAdr(&net_from);
				}
				if (!rejoin)
				{
					char announce[2048], infostr[1024];
					lobby_player_t *np = Lobby_FindPlayerBySeat(seat);
					int n;
					if (np)
					{
						Q_snprintfz(infostr, sizeof(infostr),
							"\\name\\%s\\ready\\%s\\host\\%s",
							np->name, np->ready ? "1" : "0", np->is_host ? "1" : "0");
						n = Lobby_FmtMsg(announce, sizeof(announce), "P:%d:%s", seat, infostr);
						if (n > 0)
							Lobby_Transport_Relay(seat, announce, (size_t)n);
					}
				}
			}
		}
		break;
	case 'A':
		if (Lobby_IsHost() || !val)
			break;
		{
			const char *name = val;
			if (!strncmp(val, "v", 1))
			{
				char *bar = strchr(val, '|');
				if (bar)
					name = bar + 1;
			}
			Lobby_Transport_AddPeer(0, &net_from);
			lobby.local_seat = seat;
			if (lobby.state == LOBBY_STATE_JOINING)
				Lobby_SetStateInternal(LOBBY_STATE_WAITING);
			lobby_join_pending = false;
			lobby_host_last = realtime;
			Lobby_Kex_OnPlayer(seat, va("\\name\\%s\\ready\\0", name), false);
			Q_strncpyz(lobby.status, "Joined lobby.", sizeof(lobby.status));
			lobby.error[0] = 0;
			Con_Printf("Lobby: seat assigned %d, host is %s\n", seat,
				NET_AdrToString(adrbuf, sizeof(adrbuf), &net_from));
			Lobby_SyncCvars();
		}
		break;
	case 'C':
		if (!val)
			break;
		Lobby_Kex_OnChat(seat, val);
		break;
	case 'K':
		if (!val)
			break;
		/* Clients may only send rules from host; host applies own. Spoofed seat ignored. */
		if (!Lobby_IsHost() && seat != -1 && seat != 0)
			break;
		{
			char *eq = strchr(val, '=');
			if (eq)
			{
				char key[64];
				size_t klen = (size_t)(eq - val);
				if (klen >= sizeof(key))
					klen = sizeof(key) - 1;
				memcpy(key, val, klen);
				key[klen] = 0;
				Lobby_Kex_OnRule(key, eq + 1);
			}
		}
		if (Lobby_IsHost())
			Lobby_Transport_Relay(seat, raw, (size_t)strlen(raw));
		break;
	case 'R':
		if (!val)
			break;
		if (Lobby_IsHost())
		{
			if (seat < 0 || !Lobby_Transport_PeerOwnsAdr(seat, &net_from))
			{
				Con_DPrintf("Lobby: ignoring spoofed ready seat %d\n", seat);
				break;
			}
		}
		Lobby_Kex_OnPlayer(seat, va("\\ready\\%s", val), false);
		if (Lobby_IsHost())
			Lobby_Transport_Relay(seat, raw, (size_t)strlen(raw));
		break;
	case 'P':
		if (!val)
			break;
		if (Lobby_IsHost() && seat >= 0 && Lobby_FindPlayerBySeat(seat)
			&& !Lobby_Transport_PeerOwnsAdr(seat, &net_from)
			&& seat != Lobby_GetLocalSeat())
		{
			/* Host-originated P: may be from us; joiners' P must match endpoint. */
			if (seat != 0)
			{
				Con_DPrintf("Lobby: ignoring spoofed player seat %d\n", seat);
				break;
			}
		}
		if (!Lobby_IsHost() && Lobby_GetLocalSeat() < 0)
			Lobby_Transport_AddPeer(0, &net_from);
		Lobby_Kex_OnPlayer(seat, (*val == '\\') ? val : va("\\%s", val), false);
		if (Lobby_IsHost())
			Lobby_Transport_Relay(seat, raw, (size_t)strlen(raw));
		break;
	case 'D':
		if (Lobby_IsHost() && seat >= 0 && !Lobby_Transport_PeerOwnsAdr(seat, &net_from))
		{
			Con_DPrintf("Lobby: ignoring spoofed leave seat %d\n", seat);
			break;
		}
		Lobby_Kex_OnPlayer(seat, NULL, true);
		Lobby_Transport_RemovePeer(seat);
		if (Lobby_IsHost())
			Lobby_Transport_Relay(seat, raw, (size_t)strlen(raw));
		break;
	case 'G':
		/* game_starting: map|connect_target — NEVER use net_from as game address */
		if (val)
		{
			char mapbuf[64], targetbuf[128];
			char *bar = strchr(val, '|');
			if (bar)
			{
				size_t mlen = (size_t)(bar - val);
				if (mlen >= sizeof(mapbuf))
					mlen = sizeof(mapbuf) - 1;
				memcpy(mapbuf, val, mlen);
				mapbuf[mlen] = 0;
				Q_strncpyz(targetbuf, bar + 1, sizeof(targetbuf));
			}
			else
			{
				Q_strncpyz(mapbuf, val, sizeof(mapbuf));
				targetbuf[0] = 0;
			}
			Con_Printf("Lobby: game starting map='%s' target='%s'\n", mapbuf, targetbuf);
			Lobby_OnGameStartingMsg(mapbuf, targetbuf);
		}
		break;
	case 'S':
		Con_DPrintf("Lobby: ignoring legacy S: start message\n");
		break;
	}
}

qboolean Lobby_Transport_Listen(unsigned short port)
{
	char portstr[16];
	int attempt;
	int attempts;

	if (lobby_tport_col && !lobby_tport_external)
		Lobby_Transport_Close();
	else if (lobby_tport_external)
	{
		lobby_tport_col = NULL;
		lobby_tport_external = false;
	}

	lobby_tport_col = FTENET_CreateCollection(true, Lobby_Transport_ReadPacket_cb);
	if (!lobby_tport_col)
	{
		Con_Printf(CON_ERROR "Lobby: Failed to create transport.\n");
		return false;
	}

	if (port == (unsigned short)-1)
	{
		Q_strncpyz(portstr, "0", sizeof(portstr));
		attempts = 1;
	}
	else
	{
		if (!port)
			port = Lobby_Transport_GetPort();
		Q_snprintfz(portstr, sizeof(portstr), "%u", (unsigned)port);
		attempts = 20;
		FTENET_SetExactPort(lobby_tport_col, true);
	}

	for (attempt = 0; attempt < attempts; attempt++)
	{
		if (FTENET_AddToCollection(lobby_tport_col, "lobby", portstr, NA_IP, NP_DGRAM))
			break;
		if (attempt + 1 < attempts)
			Sys_Sleep(0.05);
	}

	if (attempt == attempts)
	{
		Con_Printf(CON_ERROR "Lobby: Failed to bind UDP port %s.\n", portstr);
		FTENET_CloseCollection(lobby_tport_col);
		lobby_tport_col = NULL;
		return false;
	}
	if (attempt)
		Con_Printf("Lobby: acquired UDP %s after %i retries.\n", portstr, attempt);
	Con_Printf("Lobby: listening on UDP %s (%s)\n",
		portstr, Lobby_IsHost() ? "host" : "client");
	return true;
}

void Lobby_Transport_UseExternalCollection(ftenet_connections_t *col)
{
	lobby_tport_external = !!col;
	lobby_tport_col = col;
}

void Lobby_Transport_Close(void)
{
	lobby_join_pending = false;
	if (lobby_tport_col)
	{
		if (!lobby_tport_external)
			FTENET_CloseCollection(lobby_tport_col);
		lobby_tport_col = NULL;
	}
	lobby_tport_external = false;
	memset(lobby_peer_addrs, 0, sizeof(lobby_peer_addrs));
	memset(lobby_peer_seats, 0, sizeof(lobby_peer_seats));
	memset(lobby_peer_last, 0, sizeof(lobby_peer_last));
	memset(lobby_rel, 0, sizeof(lobby_rel));
	memset(lobby_seen_seq, 0, sizeof(lobby_seen_seq));
	lobby_seen_n = 0;
	lobby_num_peers = 0;
	lobby_host_last = 0;
	lobby_next_hb = 0;
	lobby_next_sync = 0;
}

static void Lobby_Transport_TickHeartbeat(void)
{
	extern double realtime;
	int i;
	char hb[32];
	int n;

	if (!lobby_tport_col || !Lobby_IsActive())
		return;

	/* Expire silent peers / host. */
	if (Lobby_IsHost())
	{
		for (i = lobby_num_peers - 1; i >= 0; i--)
		{
			int seat = lobby_peer_seats[i];
			if (seat == Lobby_GetLocalSeat())
				continue;
			if (lobby_peer_last[i] && realtime - lobby_peer_last[i] > LOBBY_PEER_TIMEOUT)
			{
				Con_Printf("Lobby: peer seat %d timed out\n", seat);
				Lobby_Kex_OnPlayer(seat, NULL, true);
				Lobby_Transport_RemovePeer(seat);
			}
		}
	}
	else if (Lobby_GetLocalSeat() >= 0 && lobby_host_last
		&& realtime - lobby_host_last > LOBBY_PEER_TIMEOUT)
	{
		Q_strncpyz(lobby.status, "Host timed out.", sizeof(lobby.status));
		Q_strncpyz(lobby.error, "host_timeout", sizeof(lobby.error));
		Lobby_SyncCvars();
		Lobby_Close();
		return;
	}

	if (realtime < lobby_next_hb)
		return;
	lobby_next_hb = realtime + LOBBY_HB_INTERVAL;
	n = Lobby_FmtMsg(hb, sizeof(hb), "H:%d", Lobby_GetLocalSeat());
	if (n <= 0)
		return;
	if (Lobby_IsHost())
	{
		for (i = 0; i < lobby_num_peers; i++)
			Lobby_Transport_SendAdr(&lobby_peer_addrs[i], hb, (size_t)n);
	}
	else if (Lobby_Transport_FindPeer(0) >= 0)
		Lobby_Transport_SendTo(0, hb, (size_t)n);
}

void Lobby_Transport_Poll(void)
{
	extern double realtime;

	if (lobby_tport_col)
		NET_ReadPackets(lobby_tport_col);
	Lobby_Transport_TickJoin();
	Lobby_Transport_TickReliable();
	Lobby_Transport_TickHeartbeat();

	if (Lobby_IsHost() && lobby_tport_col && realtime >= lobby_next_sync)
	{
		lobby_next_sync = realtime + LOBBY_SYNC_INTERVAL;
		Lobby_Transport_PushFullSync();
	}
}

qboolean Lobby_Transport_PeerIsLoopback(int seat)
{
	int idx = Lobby_Transport_FindPeer(seat);
	if (idx < 0)
		return false;
	if (lobby_peer_addrs[idx].type == NA_LOOPBACK)
		return true;
	if (lobby_peer_addrs[idx].type == NA_IP
		&& lobby_peer_addrs[idx].address.ip[0] == 127)
		return true;
	return NET_IsLoopBackAddress(&lobby_peer_addrs[idx]);
}

qboolean Lobby_Transport_SendTo(int seat, const void *data, size_t len)
{
	int idx = Lobby_Transport_FindPeer(seat);
	if (!lobby_tport_col || idx < 0)
		return false;
	return Lobby_Transport_SendAdr(&lobby_peer_addrs[idx], data, len);
}

qboolean Lobby_Transport_Broadcast(const void *data, size_t len)
{
	int i;
	qboolean ok = true;
	if (!lobby_tport_col)
		return false;
	for (i = 0; i < lobby_num_peers; i++)
	{
		if (!Lobby_Transport_SendAdr(&lobby_peer_addrs[i], data, len))
			ok = false;
	}
	return ok;
}

void Lobby_Transport_SetPeerAddress(int seat, const char *addrstr)
{
	netadr_t adr;
	char printed[64];

	if (!Lobby_Transport_ParseUdpAdr(addrstr, &adr))
	{
		Con_Printf(CON_ERROR "Lobby: bad UDP peer address \"%s\" (try udp://127.0.0.1:27501)\n",
			addrstr ? addrstr : "");
		return;
	}
	Lobby_Transport_AddPeer(seat, &adr);
	Lobby_RememberJoinHost(addrstr);
	Con_Printf("Lobby: peer seat %d -> %s\n", seat,
		NET_AdrToString(printed, sizeof(printed), &adr));
}

const char *Lobby_Transport_GetPeerAddress(int seat)
{
	static char buf[64];
	int idx = Lobby_Transport_FindPeer(seat);
	if (idx < 0)
		return "";
	return NET_AdrToString(buf, sizeof(buf), &lobby_peer_addrs[idx]);
}
