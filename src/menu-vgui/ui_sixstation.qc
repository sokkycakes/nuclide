/*
 * sixstation_cover.swf reconstruction experiment.
 *
 * The original Flash 5 movie is rendered as a Quake-compatible RoQ, then
 * handed off to its exact stopped frame. MenuQC owns the view lifecycle and
 * the two original invisible button hit regions.
 */

#define SIXSTATION_DURATION 3.333333f
#define SIXSTATION_MEDIA "sixstation_intro"
#define SIXSTATION_VIDEO "video/sixstation.roq"
#define SIXSTATION_FINAL "gfx/sixstation/final.png"

static bool g_sixstationActive;
static bool g_sixstationMediaActive;
static float g_sixstationStartTime;

void m_display(void);

static void
UI_Sixstation_Close(void)
{
	if (g_sixstationMediaActive) {
		gecko_destroy(SIXSTATION_MEDIA);
		g_sixstationMediaActive = false;
	}

	g_sixstationActive = false;
}

void
UI_Sixstation_Open(void)
{
	UI_Sixstation_Close();
	m_display();

	g_sixstationActive = true;
	g_sixstationStartTime = time;
	g_sixstationMediaActive = (bool)gecko_create(SIXSTATION_MEDIA, SIXSTATION_VIDEO);

	if (!g_sixstationMediaActive)
		print("^1sixstation:^7 could not open video/sixstation.roq; showing final frame.\n");
}

void
UI_Sixstation_Shutdown(void)
{
	UI_Sixstation_Close();
}

void
UI_Sixstation_RendererRestarted(void)
{
	if (!g_sixstationActive)
		return;

	if (g_sixstationMediaActive)
		gecko_destroy(SIXSTATION_MEDIA);

	g_sixstationStartTime = time;
	g_sixstationMediaActive = (bool)gecko_create(SIXSTATION_MEDIA, SIXSTATION_VIDEO);
}

bool
UI_Sixstation_Draw(void)
{
	vector stageMins;
	vector stageSize;
	float stageSide;

	if (!g_sixstationActive)
		return false;

	/* Original SWF background: #ECEBCC. */
	drawfill([0, 0], g_vidsize, [0.925490, 0.921569, 0.800000], 1.0f, DRAWFLAG_NORMAL);

	stageSide = min(g_vidsize[0], g_vidsize[1]);
	stageSize = [stageSide, stageSide];
	stageMins = (g_vidsize - stageSize) * 0.5f;

	if (g_sixstationMediaActive && (time - g_sixstationStartTime < SIXSTATION_DURATION)) {
		drawpic(stageMins, SIXSTATION_MEDIA, stageSize, [1, 1, 1], 1.0f, DRAWFLAG_NORMAL);
	} else {
		if (g_sixstationMediaActive) {
			gecko_destroy(SIXSTATION_MEDIA);
			g_sixstationMediaActive = false;
		}

		drawpic(stageMins, SIXSTATION_FINAL, stageSize, [1, 1, 1], 1.0f, DRAWFLAG_NORMAL);
	}

	return true;
}

static bool
UI_Sixstation_PointInBounds(vector point, vector mins, vector size)
{
	return (point[0] >= mins[0] && point[0] < mins[0] + size[0] &&
		point[1] >= mins[1] && point[1] < mins[1] + size[1]);
}

bool
UI_Sixstation_Input(float evtype, float scanx, float chary, float devid)
{
	vector stageMins;
	vector sourcePoint;
	vector buttonSize = [12.202909, 44.972973];
	float stageSide;

	if (!g_sixstationActive)
		return false;

	if (evtype == IE_KEYDOWN && chary == K_ESCAPE) {
		UI_Sixstation_Close();
		return true;
	}

	if (evtype != IE_KEYDOWN || scanx != K_MOUSE1)
		return true;

	/* Buttons do not exist on the root timeline until its stopped frame. */
	if (time - g_sixstationStartTime < SIXSTATION_DURATION)
		return true;

	stageSide = min(g_vidsize[0], g_vidsize[1]);
	stageMins = (g_vidsize - [stageSide, stageSide]) * 0.5f;
	sourcePoint = (g_vecMousePos - stageMins) * (512.0f / stageSide);

	if (UI_Sixstation_PointInBounds(sourcePoint, [91.780000, 98.291892], buttonSize)) {
		print("sixstation: PC version selected (original target: mix.html)\n");
	} else if (UI_Sixstation_PointInBounds(sourcePoint, [104.329091, 98.291892], buttonSize)) {
		print("sixstation: Mac version selected (original target: mix_mac.html)\n");
	}

	return true;
}
