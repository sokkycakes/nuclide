#define LB_W 960.0f
#define LB_H 720.0f
#define LB_PW 282.0f
#define LB_MW 522.0f
#define LB_MH 175.0f
#define LB_SX 53.0f
#define LB_SY 245.0f
#define LB_BGC [0.0f,0.0f,0.0f]
#define LB_BGA 0.55f
#define LB_PBG [0.13f,0.13f,0.13f]
#define LB_TXC [1.0f,1.0f,1.0f]
#define LB_DIM [0.68f,0.68f,0.68f]
#define LB_ACC [0.92f,0.94f,0.97f]
#define LB_GLD [1.0f,0.8f,0.2f]
#define LB_RDY [0.2f,0.8f,0.2f]
#define LB_NRD [0.8f,0.2f,0.2f]
#define LB_BTN [0.3f,0.3f,0.3f]
#define LB_BTH [0.45f,0.45f,0.45f]
#define LB_BRD [0.46f,0.46f,0.46f]

var vector g_lbPos;
var vector g_lbSize;

static void Lb_Calc(void) {
	float sc = min(g_vidsize[0]/LB_W, g_vidsize[1]/LB_H);
	g_lbPos = [(g_vidsize[0]-LB_W*sc)*0.5f, (g_vidsize[1]-LB_H*sc)*0.5f];
	g_lbSize = [LB_W*sc, LB_H*sc];
}
static vector Lb_S(vector p) { return [p[0]/LB_W*g_lbSize[0], p[1]/LB_H*g_lbSize[1]]; }
static vector Lb_P(vector p) { return [g_lbPos[0]+(p[0]/LB_W)*g_lbSize[0], g_lbPos[1]+(p[1]/LB_H)*g_lbSize[1]]; }
static bool Lb_Hit(vector pt, vector p, vector s) { return (pt[0]>=p[0]&&pt[0]<=p[0]+s[0]&&pt[1]>=p[1]&&pt[1]<=p[1]+s[1]); }
static void Lb_DrawBG(void) { drawfill([0,0],g_vidsize,LB_BGC,LB_BGA,0); drawfill(g_lbPos,g_lbSize,[0.05f,0.05f,0.05f],0.85f,0); }
static void Lb_DrawMap(void) { vector p=Lb_P([50,67]); vector s=Lb_S([522,175]); drawfill(p,s,[0.24f,0.24f,0.24f],0.65f,0); string mn=serverkey("mapname"); if(!STRING_SET(mn)) mn="unknown"; Font_DrawText_RGBA(p+[7,s[1]-48], mn, LB_TXC, 0.65f, FONT_SPEC); }
static void Lb_DrawRoster(void) {
	float px=LB_W-LB_PW-50; vector rp=Lb_P([px,29]); vector rs=Lb_S([LB_PW,37]); drawfill(rp,rs,LB_PBG,0.72f,0);
	float dw=Lb_S([111,37])[0]; drawfill(rp,[dw+1,rs[1]],LB_BRD,1.0f,0);
	Font_DrawText_RGBA(rp+Lb_S([4,1]),"room\ncode",LB_DIM,1.0f,FONT_SPEC_HINT);
	string cd=serverkey("lobby_roomcode"); if(!STRING_SET(cd)) cd="----"; Font_DrawText_RGBA(rp+Lb_S([62,2]),cd,LB_TXC,1.0f,FONT_SPEC);
	int t=(int)serverkeyfloat("lobby_total"); string cs=sprintf("%i / %i",t,16); float cw=Font_StringWidth(cs,true,FONT_SPEC);
	float cx=rp[0]+rs[0]-Lb_S([15,0])[0]-cw; Font_DrawText_RGBA([cx,rp[1]+Lb_S([4,0])[1]],cs,LB_ACC,1.0f,FONT_SPEC);
	int rd=(int)serverkeyfloat("lobby_ready"); string rs2=sprintf("%i",rd);
	float rw=Font_StringWidth(rs2,true,FONT_SPEC); float rx=cx-Lb_S([24,0])[0]-rw; Font_DrawText_RGBA([rx,rp[1]+Lb_S([4,0])[1]],rs2,LB_GLD,1.0f,FONT_SPEC);
}
static void Lb_DrawPlayers(void) {
	float px=LB_W-LB_PW-50; vector pp=Lb_P([px,67]); float ph=LB_H-77;
	vector ps=Lb_S([LB_PW,ph]); drawfill(pp,ps,LB_BGC,0.2f,0);
	float nh=Lb_S([0,36])[1]; float gap=Lb_S([0,3])[1]; vector ns=Lb_S([LB_PW-6,36]);
	for(int i=0i;i<16;i++){ string pn=getplayerkeyvalue(i,"name"); if(!STRING_SET(pn)) continue;
	float st=getplayerkeyfloat(i,"*lobby_state"); float y=pp[1]+3+(i*(nh+gap));
	drawfill([pp[0]+3,y],ns,[0.32f,0.32f,0.32f],1.0f,0);
	string stxt; vector sc; if(st==1){stxt="READY";sc=LB_RDY;}else if(st==2){stxt="SPEC";sc=LB_DIM;}else{stxt="WAITING";sc=LB_NRD;}
	Font_DrawText_RGBA([pp[0]+3+Lb_S([8,0])[0],y+(nh-Font_GetHeight(FONT_SPEC_HINT))*0.5f],pn,LB_TXC,1.0f,FONT_SPEC_HINT);
	float sw=Font_StringWidth(stxt,false,FONT_SPEC_HINT); float sx=pp[0]+3+ns[0]-Lb_S([8,0])[0]-sw;
	Font_DrawText_RGBA([sx,y+(nh-Font_GetHeight(FONT_SPEC_HINT))*0.5f],stxt,sc,1.0f,FONT_SPEC_HINT);}
}
static void Lb_DrawSettings(void) {
	vector sp=Lb_P([LB_SX,LB_SY]); float lh=32; float cy=sp[1]+Lb_S([0,lh])[1];
	Font_DrawText_RGBA(sp,"LOBBY OPTIONS",LB_ACC,1.0f,FONT_SPEC);
	Font_DrawText_RGBA([sp[0],cy],"RULESET:",LB_DIM,1.0f,FONT_SPEC_HINT);
	string rs=serverkey("g_gametype");if(!STRING_SET(rs))rs="dm_lobby";
	Font_DrawText_RGBA([sp[0]+Font_StringWidth("RULESET:",false,FONT_SPEC_HINT)+20,cy],rs,LB_DIM,1.0f,FONT_SPEC_HINT);
	cy+=Lb_S([0,lh])[1]; Font_DrawText_RGBA([sp[0],cy],"MAP:",LB_DIM,1.0f,FONT_SPEC_HINT);
	string mn=serverkey("mapname");if(!STRING_SET(mn))mn="unknown";
	Font_DrawText_RGBA([sp[0]+Font_StringWidth("MAP:",false,FONT_SPEC_HINT)+20,cy],mn,LB_DIM,1.0f,FONT_SPEC_HINT);
	cy+=Lb_S([0,lh])[1]; Font_DrawText_RGBA([sp[0],cy],"SERVER:",LB_DIM,1.0f,FONT_SPEC_HINT);
	Font_DrawText_RGBA([sp[0]+Font_StringWidth("SERVER:",false,FONT_SPEC_HINT)+20,cy],"Listen",LB_DIM,1.0f,FONT_SPEC_HINT);
	cy+=Lb_S([0,lh])[1]; Font_DrawText_RGBA([sp[0],cy],"HOST:",LB_DIM,1.0f,FONT_SPEC_HINT);
	string hst=serverkey("lobby_host");if(!STRING_SET(hst))hst="???";
	Font_DrawText_RGBA([sp[0]+Font_StringWidth("HOST:",false,FONT_SPEC_HINT)+20,cy],hst,LB_GLD,1.0f,FONT_SPEC_HINT);
	cy+=Lb_S([0,lh])[1]; float bw=Lb_S([280,0])[0]; float bh=Lb_S([0,47])[1]; float by=cy+Lb_S([0,8])[1];
	bool host=false; string mn2=getplayerkeyvalue(player_localnum,"name"); if(STRING_SET(mn2)&&mn2==hst)host=true;
	drawfill([sp[0],by],[bw,bh],host?LB_BTH:LB_BTN,1.0f,0); drawfill([sp[0],by],[bw,2],LB_TXC,1.0f,0);
	drawfill([sp[0],by+bh-2],[bw,2],LB_TXC,1.0f,0);
	if(host){string bt="START GAME";Font_DrawText_RGBA([sp[0]+(bw-Font_StringWidth(bt,false,FONT_SPEC))*0.5f,by+(bh-Font_GetHeight(FONT_SPEC))*0.5f],bt,LB_DIM,1.0f,FONT_SPEC);}
	else{string bt2="WAITING FOR HOST";Font_DrawText_RGBA([sp[0]+(bw-Font_StringWidth(bt2,false,FONT_SPEC_HINT))*0.5f,by+(bh-Font_GetHeight(FONT_SPEC_HINT))*0.5f],bt2,LB_DIM,1.0f,FONT_SPEC_HINT);}
}
static void Lb_DrawReady(void) {
	string st=serverkey("lobby_state"); float ms=getplayerkeyfloat(player_localnum,"*lobby_state");
	if(st=="COUNTDOWN"){float r=serverkeyfloat("lobby_countdown");if(r<=0)r=0;string cs=sprintf("%.0f",r);
	float cw=Font_StringWidth(cs,true,FONT_SPEC);Font_DrawText_RGBA([(g_vidsize[0]-cw)*0.5f,g_vidsize[1]*0.35f],cs,LB_GLD,1.0f,FONT_SPEC);}
	float bw=Lb_S([200,0])[0];float bh=Lb_S([0,40])[1];float bx=(g_vidsize[0]-bw)*0.5f;float by=g_vidsize[1]-Lb_S([0,100])[1];
	string bt;vector bc;if(ms==1){bt="CANCEL";bc=LB_NRD;}else{bt="READY UP";bc=LB_RDY;}
	drawfill([bx,by],[bw,bh],bc,0.8f,0);
	Font_DrawText_RGBA([bx+(bw-Font_StringWidth(bt,false,FONT_SPEC_HINT))*0.5f,by+(bh-Font_GetHeight(FONT_SPEC_HINT))*0.5f],bt,LB_TXC,1.0f,FONT_SPEC_HINT);
}
static void Lb_DrawEsc(void) { Font_DrawText_RGBA(Lb_P([48,622]),"[ESC] Back",LB_DIM,1.0f,FONT_SPEC_HINT); }
bool LobbyOverlay_ShouldDraw(void){string s=serverkey("lobby_state");return(s=="WARMUP"||s=="COUNTDOWN");}
void LobbyOverlay_InputFrame(void){
	string st=serverkey("lobby_state");if(st!="WARMUP"&&st!="COUNTDOWN")return;
	if(!(input_buttons&1))return;vector mp=g_vecMousePos;
	float bw=Lb_S([200,0])[0];float bh=Lb_S([0,40])[1];float bx=(g_vidsize[0]-bw)*0.5f;float by=g_vidsize[1]-Lb_S([0,100])[1];
	if(Lb_Hit(mp,[bx,by],[bw,bh])){float ms=getplayerkeyfloat(player_localnum,"*lobby_state");if(ms==1)localcmd("cmd notready\n");else localcmd("cmd ready\n");return;}
	float sy=LB_SY+32*4+8;float bw2=Lb_S([280,0])[0];float bh2=Lb_S([0,47])[1];vector sbp=Lb_P([LB_SX,sy]);
	if(Lb_Hit(mp,sbp,[bw2,bh2])){string hst=serverkey("lobby_host");string mn=getplayerkeyvalue(player_localnum,"name");if(STRING_SET(mn)&&mn==hst)localcmd("cmd startgame\n");}
}
void LobbyOverlay_Draw(void){if(!LobbyOverlay_ShouldDraw())return;Lb_Calc();Lb_DrawBG();Lb_DrawMap();Lb_DrawRoster();Lb_DrawPlayers();Lb_DrawSettings();Lb_DrawReady();Lb_DrawEsc();}
