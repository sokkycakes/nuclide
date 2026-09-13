"""Render and exercise the real lobby bundle in the installed WebCore DLL."""
import ctypes as c
import importlib.util
import json
import mimetypes
import os
from pathlib import Path
import time
from urllib.parse import unquote, urlsplit
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '_lobby_diag/figma-port'
spec = importlib.util.spec_from_file_location('webcore_types', ROOT.parent / 'workspace/webcore-fte/Tools/FTE/tests/test_timer_runtime.py')
t = importlib.util.module_from_spec(spec); spec.loader.exec_module(t)
SNAPSHOT = dict(active=True, sessionId='ui-test', revision=1, uiVersion=1, isHost=True,
    localSeat=0, phase='WAITING', status='Waiting for players', map='envtest', max=16,
    roomCode='A41B9C', network='online', canReady=True, canStart=True, canCancel=False,
    canChangeMap=True, canLeave=True, canChat=True, serverTime=1000,
    settings=dict(ruleset='DUEL', servertype='LISTEN SERVER', timelimit='10', fraglimit='20'),
    players=[dict(seat=0,name='PlayerName',host=True,ready=False,connected=True)])

def main():
    directory = os.add_dll_directory(str(ROOT))
    lib = c.WinDLL(str(ROOT / 'ftewebcore.dll'))
    get = lib.ftewebcore_get_api; get.argtypes=[c.c_uint32,c.POINTER(t.API)]; get.restype=c.c_int
    api=t.API(); api.struct_size=c.sizeof(api)
    assert get(1,c.byref(api)) == 1 and api.initialize() == 1
    gdi = c.WinDLL('gdi32')
    gdi.AddFontResourceExW.argtypes = [c.c_wchar_p,c.c_uint32,c.c_void_p]
    gdi.RemoveFontResourceExW.argtypes = [c.c_wchar_p,c.c_uint32,c.c_void_p]
    fonts = []
    for path in [ROOT/'base/data/web/hud/assets/fonts/TradeGothicNextLTProBdCn.ttf', ROOT/'base/data/web/ql-menu/assets/standard_07_57.ttf'] + list((ROOT/'base/data/web/lobby-menu/assets/fonts').glob('*.ttf')):
        assert gdi.AddFontResourceExW(str(path),16,None), 'Unable to register ' + path.name
        fonts.append(str(path))
    buffers=[]; results=[]; messages=[]; actions=[]; errors=[]; paints=[]; sounds=[]
    connection = {'available': True}
    @t.RESOURCE_OPEN
    def resource_open(_u,url,data,size,mime,resource):
        parts=urlsplit(url.decode()); path=(ROOT/'base'/parts.netloc/unquote(parts.path).lstrip('/')).resolve()
        if ROOT/'base' not in path.parents or not path.is_file(): return 0
        payload=path.read_bytes(); buf=c.create_string_buffer(payload)
        kind=c.c_char_p((mimetypes.guess_type(str(path))[0] or 'application/octet-stream').encode())
        buffers.extend([buf,kind]); data[0]=c.cast(buf,c.c_void_p); size[0]=len(payload); mime[0]=kind; resource[0]=c.c_void_p(len(buffers)); return 1
    @t.RESOURCE_CLOSE
    def resource_close(*_): pass
    @t.JS_QUERY
    def query(_u,request,reply,capacity):
        req=request.decode(); response='[]'
        if req=='getlobby': response=json.dumps(SNAPSHOT) if connection['available'] else ''
        elif req=='getlobbychat': response=json.dumps(messages)
        elif req.startswith('test:') and not reply: results.append(json.loads(req[5:]))
        elif req.startswith('error:') and not reply: errors.append(req[6:])
        elif req.startswith('localsound:') and not reply: sounds.append(req[11:])
        elif req.startswith('lobby_action:'):
            response='{"ok":true}'
            if reply:
                action=req[13:]; actions.append(action)
                if action.startswith('chat:'):
                    text=bytes.fromhex(action[5:]).decode(); messages.append(dict(id=len(messages)+1,seat=0,name='PlayerName',text=text))
                elif action.startswith('setmap:'): SNAPSHOT['map']=action[7:]
                elif action.startswith('setruleset:'): SNAPSHOT['settings']['ruleset']=action[11:]
                elif action in ('ready','unready'):
                    next(p for p in SNAPSHOT['players'] if p['seat']==SNAPSHOT['localSeat'])['ready']=action=='ready'
                SNAPSHOT['revision']+=1
        elif req.startswith('clipboard_copy:') or req.startswith('cbuf:'): response='ok'
        encoded=response.encode()
        if reply and capacity: c.memmove(reply,encoded+b'\0',min(capacity,len(encoded)+1))
        return len(encoded)
    @t.PAINT
    def paint(_u,pixels,w,h,stride,_r,_count):
        paints[:]=[(c.string_at(pixels,stride*h),w,h,stride)]
    cb=t.Callbacks(c.sizeof(t.Callbacks),None,resource_open,resource_close,query,paint)
    execute=c.WINFUNCTYPE(None,c.c_void_p,c.c_char_p)(api.execute_javascript)
    send=c.WINFUNCTYPE(None,c.c_void_p,c.c_int,c.c_uint32,c.c_int)(api.key)
    focus=c.WINFUNCTYPE(None,c.c_void_p,c.c_int)(api.set_focus)
    move=c.WINFUNCTYPE(None,c.c_void_p,c.c_int,c.c_int)(api.mouse_move)
    button=c.WINFUNCTYPE(None,c.c_void_p,c.c_int,c.c_int)(api.mouse_button)
    wheel=c.WINFUNCTYPE(None,c.c_void_p,c.c_int,c.c_int)(api.mouse_wheel)
    resize=c.WINFUNCTYPE(None,c.c_void_p,c.c_int,c.c_int)(api.resize)
    def pump(duration=.15):
        end=time.monotonic()+duration
        while time.monotonic()<end: api.update(); time.sleep(.005)
    view=api.create_view(b'fte://data/web/lobby-menu/index.html',960,720,c.byref(cb))
    execute(view, b'__fte_transparent:1')
    def js(source): execute(view,source.encode()); pump()
    def value(expression):
        before=len(results)
        js("try { fte_query('test:'+JSON.stringify("+expression+")); } catch(e) { fte_query('test:'+JSON.stringify({error:String(e)})); }")
        assert len(results)>before, 'JavaScript did not run'
        return results[-1]
    def click(selector):
        rect=value("(function(){var r=document.querySelector("+json.dumps(selector)+").getBoundingClientRect();return {x:r.left+r.width/2,y:r.top+r.height/2};})()")
        assert 'error' not in rect,rect
        move(view,int(rect['x']),int(rect['y'])); button(view,0,1); button(view,0,0); pump()
    def key(code,char=0): send(view,code,char,1); send(view,code,char,0); pump(.015)
    def capture(name):
        pump(.3); assert paints,'No paint callback'
        payload,w,h,stride=paints[-1]
        image=Image.frombytes('RGBA',(w,h),payload,'raw','BGRA',stride)
        # Native pixels are premultiplied: composite directly for the white/gray Figma canvas.
        raw=bytearray(image.tobytes())
        for i in range(0,len(raw),4):
            alpha=raw[i+3]
            for j in range(3): raw[i+j]=min(255,raw[i+j]+round(229*(255-alpha)/255))
            raw[i+3]=255
        Image.frombytes('RGBA',(w,h),bytes(raw)).save(OUT/(name+'.png'))
    try:
        pump(1); focus(view,1)
        js("window.addEventListener('error',function(e){fte_query('error:'+e.message);});")
        assert value("!!document.getElementById('BtnLobbyOptions')"), 'Bundle did not mount'
        assert value("document.getElementById('ImgLevelImage').textContent")=='Env Test'
        assert value("document.activeElement.id")=='BtnLobbyOptions', 'Initial keyboard focus missing'
        assert not sounds, 'Initial focus should be silent'
        bar=value("(function(){var e=document.getElementById('LobbyFocusBar'),r=e.getBoundingClientRect(),c=getComputedStyle(e);return [r.x,r.y,r.width,r.height,c.backgroundColor,c.transitionDuration]})()")
        assert abs(bar[0]-53)<1 and abs(bar[1]-252.2)<1 and abs(bar[2]-518.391)<1 and abs(bar[3]-24)<1 and bar[4]=='rgb(191, 191, 191)', bar
        assert value("getComputedStyle(document.getElementById('BtnLobbyOptions')).fontFamily").startswith('"standard 07_57"')
        panel=value("(function(){var e=document.getElementById('BgPanel'),r=e.getBoundingClientRect();return [r.x,r.y,r.width,r.height,getComputedStyle(e).backgroundImage]})()")
        assert panel[:4]==[39,14,544,693] and 'linear-gradient' in panel[4] and '4.8077%' in panel[4] and '95%' in panel[4], panel
        assert value("document.getElementById('BgPanel').previousElementSibling===null"), 'Background panel must paint behind lobby content'
        assert value("document.querySelector('.leave-hint img').naturalWidth > 0"), 'Figma Escape asset did not decode'
        capture('lobby-webcore-960')
        connection['available'] = False; pump(.6)
        assert value("document.getElementById('StatusLine').textContent")==''
        pump(2)
        assert 'connection' in value("document.getElementById('StatusLine').textContent")
        connection['available'] = True; pump(.5)
        assert value("document.getElementById('StatusLine').textContent")=='', 'Recovery must clear status even without a new revision'
        click('#ChatInput')
        for ch in 'wasd hello ; "world"': key(ord(ch.lower()),ord(ch))
        assert value("document.getElementById('ChatInput').value")=='wasd hello ; "world"'
        key(13); pump(.4)
        assert messages[-1]['text']=='wasd hello ; "world"',messages
        assert value("document.getElementById('ChatInput').value")==''
        click('#BtnChangeRuleset')
        assert sounds[-2:]==['misc/menu1','misc/menu2'], 'Title menu navigate/confirm sounds must play'
        assert value("Math.round(document.getElementById('LobbyFocusBar').getBoundingClientRect().y)")==276
        assert value("document.getElementById('BtnChangeRuleset').classList.contains('is-selected')")
        click('#RulesetChoices .choice:nth-child(2)'); pump(.4)
        assert SNAPSHOT['settings']['ruleset']=='DEATHMATCH'
        assert value("!document.getElementById('view-settings')")
        click('#BtnChangeMap'); click('[data-map="lean"]'); pump(.4)
        assert SNAPSHOT['map']=='lean'
        js("document.getElementById('BtnChangeMap').focus()")
        key(133)
        assert value("document.activeElement.id")=='BtnServerType', 'ArrowDown should move within the lobby list'
        assert sounds[-1]=='misc/menu1'
        move(view,200,365); wheel(view,0,-120); pump(.2)
        assert value("document.activeElement.id")=='BtnStartGame', 'Wheel should advance the title-style selection'
        key(132)
        assert value("document.activeElement.id")=='BtnServerType', 'ArrowUp should move back within the list'
        js("document.getElementById('BtnChangeMap').focus()")
        SNAPSHOT['canChangeMap']=False; SNAPSHOT['revision']+=1; pump(.4)
        assert value("document.activeElement.id")=='BtnLobbyOptions', 'Focus must leave a setting when it becomes disabled'
        SNAPSHOT['canChangeMap']=True; SNAPSHOT['revision']+=1; pump(.4)
        click('#BtnLobbyOptions'); click('#TimeLimit')
        key(27); assert value("!document.getElementById('view-settings')")
        assert sounds[-1]=='misc/menu3', 'Escape should play the title menu back sound'
        click('#BtnLeaveLobby')
        assert value("document.activeElement.id")=='BtnCancelLeave'
        key(13); assert value("!document.getElementById('LeaveConfirm')"), 'Enter on Stay must not leave'
        assert 'close' not in actions
        assert value("!document.getElementById('GuestLock')")
        click('#BtnLobbyOptions')
        SNAPSHOT['isHost']=False; SNAPSHOT['localSeat']=1
        SNAPSHOT['players'].append(dict(seat=1,name='Guest',host=False,ready=False,connected=True))
        SNAPSHOT['canStart']=False; SNAPSHOT['canChangeMap']=False; SNAPSHOT['revision']+=1
        pump(.5)
        assert value("!document.getElementById('view-settings')"), 'Host-only dialog must close when host authority is lost'
        assert value("document.getElementById('GuestLock').textContent")=='Lobby settings locked to Host.'
        assert value("document.querySelector('#GuestLock img').naturalWidth > 0"), 'Guest lock artwork did not decode'
        assert value("Array.from(document.querySelectorAll('.setting-row')).every(b => b.disabled)")
        before_actions = len(actions); before_sounds = len(sounds)
        for selector in ['#BtnLobbyOptions','#BtnChangeRuleset','#BtnChangeMap','#BtnServerType']:
            click(selector)
        assert value("!document.getElementById('view-settings')")
        assert len(actions)==before_actions, 'Locked rows must not send engine actions'
        assert len(sounds)==before_sounds, 'Locked rows must remain silent'
        js("document.getElementById('BtnReady').focus()")
        key(9,0)
        assert value("!document.activeElement.classList.contains('setting-row')"), 'Keyboard navigation must skip locked rows'
        capture('lobby-webcore-960-guest-lock')
        assert value("document.getElementById('BtnChangeMap').disabled")
        assert value("!document.getElementById('BtnStartGame')")
        assert value("!!document.getElementById('BtnReady')")
        click('#BtnReady'); pump(.4)
        assert SNAPSHOT['players'][1]['ready'], 'Guest ready action did not use the local seat'
        SNAPSHOT['phase']='COUNTDOWN'; SNAPSHOT['countdownEnd']=1005; SNAPSHOT['revision']+=1
        pump(.4)
        assert 'Starting in' in value("document.getElementById('BtnReady').textContent")
        SNAPSHOT['phase']='WAITING'; SNAPSHOT['countdownEnd']=0; SNAPSHOT['revision']+=1
        pump(.4)
        assert value("document.getElementById('BtnReady').textContent")=='Unready'
        resize(view,1920,1080); pump(.5)
        rect=value("(function(){var r=document.getElementById('LobbyStage').getBoundingClientRect();return {x:r.left,y:r.top,w:r.width,h:r.height};})()")
        assert rect==dict(x=240,y=0,w=1440,h=1080),rect
        capture('lobby-webcore-1920-guest')
        SNAPSHOT['isHost']=True; SNAPSHOT['localSeat']=0; SNAPSHOT['canStart']=True; SNAPSHOT['canChangeMap']=True; SNAPSHOT['revision']+=1
        pump(.5)
        assert value("!document.getElementById('GuestLock')")
        click('#BtnLobbyOptions')
        assert value("!!document.getElementById('view-settings')"), 'Host controls must recover when host authority returns'
        assert not errors,errors
        print('PASS: actual WebCore render, chat native typing/send, ruleset/map actions, dialogs, safe Enter/Stay, guest permissions, 4:3 and 16:9 layout.',flush=True)
    finally:
        api.destroy_view(view); api.shutdown()
        for font in fonts: gdi.RemoveFontResourceExW(font,16,None)
        directory.close()
if __name__=='__main__': main()
