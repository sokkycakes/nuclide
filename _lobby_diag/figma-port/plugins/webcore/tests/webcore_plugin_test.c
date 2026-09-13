#include "../../plugin.h"
#include "../../engine.h"
#include "../webcore_abi.h"

#include <assert.h>
#include <string.h>

extern qboolean NATIVEEXPORT FTEPlug_Init(plugcorefuncs_t *corefuncs);

static plugcmdfuncs_t fake_cmd;
static plugcvarfuncs_t fake_cvar;
static plugfsfuncs_t fake_fs;
static plugclientfuncs_t fake_client;
static char printed[2048];
static int requested_host;
static int host_available;
static int host_destroyed;
static int host_shutdown;
static char loaded_path[128];
static char commands[512];
static char executed_script[2304];
static const char *arena_snapshot = "{\"active\":true,\"phase\":\"WARMUP\"}";
static ftewebcore_callbacks_t host_callbacks;
static media_decoder_funcs_t *exported_decoder;
static qintptr_t (*exported_tick)(qintptr_t *);
static qintptr_t (*exported_shutdown)(qintptr_t *);

static int HostInitialize(void) { return 1; }
static void HostShutdown(void) { host_shutdown = 1; }
static void HostExecuteJavaScript(ftewebcore_view_t *view, const char *script)
{
	assert(view == (ftewebcore_view_t *)(uintptr_t)1);
	strncpy(executed_script, script, sizeof(executed_script) - 1);
	executed_script[sizeof(executed_script) - 1] = 0;
}

static void HostUpdate(void)
{
	const void *data;
	const char *mime;
	void *resource;
	size_t size;
	char reply[128];

	assert(host_callbacks.resource_open(host_callbacks.userdata,
		"fte://data/ui/index.html?v=1", &data, &size, &mime, &resource));
	assert(!strcmp(loaded_path, "data/ui/index.html"));
	assert(size == 4);
	assert(!strcmp(mime, "text/html"));
	assert(host_callbacks.js_query(host_callbacks.userdata,
		"getstats", reply, sizeof(reply)) == 5);
	assert(!strcmp(reply, "[7,9]"));
	{
		static const char expected_hud[] =
			"{\"health\":42,\"healthMax\":100,\"ammo\":17,\"ammoCurrent\":5,\"ammoMax\":99,\"charges\":2,"
			"\"timer\":\"01:23\",\"speed\":321,\"scoreLeft\":4,\"scoreRight\":6,"
			"\"exLevel\":\"3\",\"reload\":\"0.0\",\"player1\":\"Alice \\\"Ace\\\"\","
			"\"player2\":\"Bob\\\\Two\"}";
		char hud_reply[512];
		assert(host_callbacks.js_query(host_callbacks.userdata,
			"gethud", hud_reply, sizeof(hud_reply)) == strlen(expected_hud));
		assert(!strcmp(hud_reply, expected_hud));
	}
	assert(host_callbacks.js_query(host_callbacks.userdata,
		"getarena", reply, sizeof(reply)) ==
		strlen("{\"active\":true,\"phase\":\"WARMUP\"}"));
	assert(!strcmp(reply, "{\"active\":true,\"phase\":\"WARMUP\"}"));
	arena_snapshot = "{\"active\":true,\"phase\":\"WARMUP\",\"round\":\"1\",\"map\":\"dm_campgrounds\",\"readyCount\":2,\"players\":[\"Bob\",\"Alice\"],\"local\":{\"state\":1,\"hero\":\"archstiletto\",\"needsHero\":false,\"joining\":true},\"heroes\":[{\"id\":\"archstiletto\",\"name\":\"archstiletto\"}] }";
	assert(host_callbacks.js_query(host_callbacks.userdata, "getarena", reply, sizeof(reply)) == strlen(arena_snapshot));
	arena_snapshot = "not json";
	assert(!host_callbacks.js_query(host_callbacks.userdata, "getarena", reply, sizeof(reply)));
	arena_snapshot = "{\"active\":true,}";
	assert(!host_callbacks.js_query(host_callbacks.userdata, "getarena", reply, sizeof(reply)));
	arena_snapshot = "{\"note\":\"active\",\"active\":\"true\"}";
	assert(!host_callbacks.js_query(host_callbacks.userdata, "getarena", reply, sizeof(reply)));
	arena_snapshot = "{\"active\":true,\"phase\":\"WARMUP\"}";
	{
		static const struct {
			const char *request;
			const char *command;
		} actions[] = {
			{ "lobby_action:ready", "lobby_ready 1\n" },
			{ "lobby_action:setmap:envtest", "lobby_set map envtest\n" },
			{ "lobby_action:close", "lobby_close\n" },
            { "lobby_action:setruleset:DUEL", "lobby_set ruleset DUEL\n" },
            { "lobby_action:setlimits:15:30", "lobby_limits 15 30\n" },
            { "lobby_action:chat:6869", "lobby_chat_hex 6869\n" }
		};
		size_t i;
		for (i = 0; i < countof(actions); ++i)
		{
			size_t before = strlen(commands);
			size_t required = host_callbacks.js_query(host_callbacks.userdata,
				actions[i].request, NULL, 0);
			assert(required == strlen("{\"ok\":true}"));
			assert(strlen(commands) == before);
			assert(host_callbacks.js_query(host_callbacks.userdata,
				actions[i].request, reply, sizeof(reply)) == required);
			assert(!strcmp(reply, "{\"ok\":true}"));
			assert(!strcmp(commands + before, actions[i].command));
		}
	}
	{
        const char *invalid[] = { "lobby_action:chat:", "lobby_action:chat:1", "lobby_action:chat:zz", "lobby_action:chat:41;quit", "lobby_action:setlimits:181:0", "lobby_action:setlimits:1:2:3", "lobby_action:setlimits:1:-2", "lobby_action:setruleset:DUEL;quit" };
        size_t k, before = strlen(commands);
        for (k = 0; k < countof(invalid); k++)
            assert(!host_callbacks.js_query(host_callbacks.userdata, invalid[k], reply, sizeof(reply)));
        assert(strlen(commands) == before);
		static const struct {
			const char *request;
			const char *command;
		} actions[] = {
			{ "arena_action:join", "cmd joinTeam 1\n" },
			{ "arena_action:spectate", "cmd spectate\nwebcore_closemenu\n" },
			{ "arena_action:play", "cmd play\n" },
			{ "arena_action:choosehero", "cmd choosehero\n" },
			{ "arena_action:ready", "cmd ready\n" },
			{ "arena_action:unready", "cmd notready\n" },
			{ "arena_action:hero:archstiletto", "cmd selecthero archstiletto\n" },
			{ "arena_action:close", "webcore_closemenu\n" }
		};
		size_t i;
		for (i = 0; i < countof(actions); ++i)
		{
			size_t before = strlen(commands);
			size_t required = host_callbacks.js_query(host_callbacks.userdata,
				actions[i].request, NULL, 0);
			assert(required == strlen("{\"ok\":true}"));
			assert(strlen(commands) == before);
			assert(host_callbacks.js_query(host_callbacks.userdata,
				actions[i].request, reply, required) == required);
			assert(strlen(commands) == before);
			assert(host_callbacks.js_query(host_callbacks.userdata,
				actions[i].request, reply, sizeof(reply)) == required);
			assert(!strcmp(reply, "{\"ok\":true}"));
			assert(!strcmp(commands + before, actions[i].command));
		}
		assert(!host_callbacks.js_query(host_callbacks.userdata,
			"arena_action:hero:not_allowed", reply, sizeof(reply)));
		assert(!host_callbacks.js_query(host_callbacks.userdata,
			"arena_action:hero:archstiletto\nquit", reply, sizeof(reply)));
		assert(!host_callbacks.js_query(host_callbacks.userdata,
			"arena_action:unknown", reply, sizeof(reply)));
	}
	host_callbacks.resource_close(host_callbacks.userdata, resource);
}

static ftewebcore_view_t *HostCreate(const char *url, int width, int height,
	const ftewebcore_callbacks_t *callbacks)
{
	assert(!strcmp(url, "fte://data/web/hud/index.html"));
	assert(width == 640 && height == 480);
	host_callbacks = *callbacks;
	return (ftewebcore_view_t *)(uintptr_t)1;
}

static void HostDestroy(ftewebcore_view_t *view)
{
	assert(view == (ftewebcore_view_t *)(uintptr_t)1);
	host_destroyed = 1;
}

static int HostNavigate(ftewebcore_view_t *view, const char *url)
{
	(void)view; (void)url; return 1;
}
static void HostResize(ftewebcore_view_t *view, int width, int height)
{ (void)view; (void)width; (void)height; }
static void HostMouseMove(ftewebcore_view_t *view, int x, int y)
{ (void)view; (void)x; (void)y; }
static void HostMouseButton(ftewebcore_view_t *view, int button, int down)
{ (void)view; (void)button; (void)down; }
static void HostMouseWheel(ftewebcore_view_t *view, int x, int y)
{ (void)view; (void)x; (void)y; }
static void HostKey(ftewebcore_view_t *view, int key, uint32_t unicode, int down)
{ (void)view; (void)key; (void)unicode; (void)down; }

static int HostGetApi(uint32_t version, ftewebcore_api_t *api)
{
	assert(version == FTEWEBCORE_ABI_VERSION);
	api->abi_version = FTEWEBCORE_ABI_VERSION;
	api->initialize = HostInitialize;
	api->shutdown = HostShutdown;
	api->update = HostUpdate;
	api->create_view = HostCreate;
	api->destroy_view = HostDestroy;
	api->navigate = HostNavigate;
	api->resize = HostResize;
	api->mouse_move = HostMouseMove;
	api->mouse_button = HostMouseButton;
	api->mouse_wheel = HostMouseWheel;
	api->key = HostKey;
	api->execute_javascript = HostExecuteJavaScript;
	return 1;
}

static void *QDECL FakeGetEngineInterface(const char *name, size_t size)
{
	(void)size;
	if (!strcmp(name, plugcmdfuncs_name)) return &fake_cmd;
	if (!strcmp(name, plugcvarfuncs_name)) return &fake_cvar;
	if (!strcmp(name, plugfsfuncs_name)) return &fake_fs;
	if (!strcmp(name, plugclientfuncs_name)) return &fake_client;
	return NULL;
}

static qboolean QDECL FakeExportFunction(const char *name, funcptr_t function)
{
	if (!strcmp(name, "Tick"))
		exported_tick = (qintptr_t (*)(qintptr_t *))function;
	else if (!strcmp(name, "Shutdown"))
		exported_shutdown = (qintptr_t (*)(qintptr_t *))function;
	return qtrue;
}

static qboolean QDECL FakeExportInterface(const char *name, void *interface,
	size_t size)
{
	(void)size;
	if (!strcmp(name, "Media_VideoDecoder"))
		exported_decoder = (media_decoder_funcs_t *)interface;
	return qtrue;
}

static void QDECL FakePrint(const char *message)
{
	size_t used = strlen(printed);
	size_t available = sizeof(printed) - used - 1;
	strncat(printed, message, available);
}

static void QDECL FakeAddText(const char *text, qboolean insert)
{
	(void)insert;
	strncat(commands, text, sizeof(commands) - strlen(commands) - 1);
}

static qboolean QDECL FakeGetString(const char *name, char *retstring,
	quintptr_t sizeofretstring)
{
	const char *value = "";

	if (!strcmp(name, "webcore_arena_snapshot"))
		value = arena_snapshot;
	else if (!strcmp(name, "webcore_arena_hero_ids"))
		value = "archstiletto vagrant";
	else if (!strcmp(name, "webcore_hud_health")) value = "42";
	else if (!strcmp(name, "webcore_hud_health_max")) value = "100";
	else if (!strcmp(name, "webcore_hud_ammo")) value = "17";
	else if (!strcmp(name, "webcore_hud_clip")) value = "5";
	else if (!strcmp(name, "webcore_hud_ammo_max")) value = "99";
	else if (!strcmp(name, "webcore_hud_charges")) value = "2";
	else if (!strcmp(name, "webcore_hud_speed")) value = "321";
	else if (!strcmp(name, "webcore_hud_timer")) value = "01:23";
	else if (!strcmp(name, "webcore_hud_score_left")) value = "4";
	else if (!strcmp(name, "webcore_hud_score_right")) value = "6";
	else if (!strcmp(name, "webcore_hud_player1")) value = "Alice \"Ace\"";
	else if (!strcmp(name, "webcore_hud_player2")) value = "Bob\\Two";

	if (!retstring || !sizeofretstring)
		return qfalse;
	strncpy(retstring, value, sizeofretstring - 1);
	retstring[sizeofretstring - 1] = '\0';
	return qtrue;
}

static dllhandle_t *QDECL FakeLoadDLL(const char *name,
	struct dllfunction_s *functions)
{
	requested_host |= !strcmp(name, "ftewebcore") || !strcmp(name, "./ftewebcore");
	if (!host_available)
		return NULL;
	assert(functions && !strcmp(functions[0].name, "ftewebcore_get_api"));
	*functions[0].funcptr = HostGetApi;
	return (dllhandle_t *)(uintptr_t)1;
}

static void QDECL FakeCloseDLL(dllhandle_t *handle)
{
	assert(handle == (dllhandle_t *)(uintptr_t)1);
}

static void *QDECL FakeMalloc(size_t size) { return malloc(size); }
static void QDECL FakeFree(void *data) { free(data); }

static void *QDECL FakeLoadFile(const char *path, size_t *size)
{
	char *data = (char *)malloc(4);
	strcpy(loaded_path, path);
	memcpy(data, "test", 4);
	*size = 4;
	return data;
}

static int QDECL FakeGetStats(int seat, unsigned int *stats, int count)
{
	(void)seat;
	assert(count >= 2);
	stats[0] = 7;
	stats[1] = 9;
	return 2;
}

static void QDECL FakeGetPredInfo(int seat, vec3_t outvel)
{
	(void)seat;
	outvel[0] = 3;
	outvel[1] = 4;
	outvel[2] = 0;
}

static void InitializeCore(plugcorefuncs_t *core)
{
	memset(core, 0, sizeof(*core));
	core->GetEngineInterface = FakeGetEngineInterface;
	core->ExportFunction = FakeExportFunction;
	core->ExportInterface = FakeExportInterface;
	core->Print = FakePrint;
	core->LoadDLL = FakeLoadDLL;
	core->CloseDLL = FakeCloseDLL;
	core->Malloc = FakeMalloc;
	core->Free = FakeFree;
	fake_fs.LoadFile = FakeLoadFile;
	fake_client.GetStats = FakeGetStats;
	fake_client.GetPredInfo = FakeGetPredInfo;
	fake_cmd.AddText = FakeAddText;
	fake_cvar.GetString = FakeGetString;
}

int main(void)
{
	plugcorefuncs_t core;
	void *browser;
	const void *data;
	const char *mime;
	void *resource;
	size_t size;

	InitializeCore(&core);
	assert(!FTEPlug_Init(&core));
	assert(requested_host);
	assert(strstr(printed, "unable to load ftewebcore host DLL") != NULL);
	assert(strstr(printed, "required host or engine interface missing") != NULL);

	host_available = 1;
	assert(FTEPlug_Init(&core));
	assert(exported_decoder && exported_tick && exported_shutdown);
	browser = exported_decoder->createdecoder(
		"webcore:fte://data/web/hud/index.html");
	assert(browser);

	assert(host_callbacks.resource_open(host_callbacks.userdata,
		"fte://data/ui/index.html", &data, &size, &mime, &resource));
	host_callbacks.resource_close(host_callbacks.userdata, resource);
	assert(!host_callbacks.js_query(host_callbacks.userdata,
		"getstats", NULL, 0));
	executed_script[0] = 0;
	exported_tick(NULL);
	assert(!strcmp(executed_script,
		"window.WebCoreHud_Receive&&window.WebCoreHud_Receive("
		"{\"health\":42,\"healthMax\":100,\"ammo\":17,\"ammoCurrent\":5,\"ammoMax\":99,\"charges\":2,"
		"\"timer\":\"01:23\",\"speed\":321,\"scoreLeft\":4,\"scoreRight\":6,"
		"\"exLevel\":\"3\",\"reload\":\"0.0\",\"player1\":\"Alice \\\"Ace\\\"\","
		"\"player2\":\"Bob\\\\Two\"});"));
	exported_decoder->shutdown(browser);
	assert(host_destroyed);
	exported_shutdown(NULL);
	assert(host_shutdown);
	return 0;
}
