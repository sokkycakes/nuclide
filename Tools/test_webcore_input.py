"""Exercise the native WebCore keyboard API against the shipped join dialogs."""
import ctypes as c
import importlib.util
import json
import mimetypes
import os
from pathlib import Path
import time
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]
TYPE_FILE = ROOT.parent / 'workspace/webcore-fte/Tools/FTE/tests/test_timer_runtime.py'
spec = importlib.util.spec_from_file_location('webcore_test_types', TYPE_FILE)
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)

class ClipboardSnapshot:
    """Preserve clipboard formats in memory; never print clipboard contents."""
    def __enter__(self):
        self.user, self.kernel = c.WinDLL('user32', use_last_error=True), c.WinDLL('kernel32', use_last_error=True)
        self.user.GetClipboardData.restype = c.c_void_p
        self.user.SetClipboardData.argtypes = [c.c_uint, c.c_void_p]
        self.user.SetClipboardData.restype = c.c_void_p
        self.kernel.GlobalSize.argtypes = [c.c_void_p]
        self.kernel.GlobalSize.restype = c.c_size_t
        self.kernel.GlobalLock.argtypes = [c.c_void_p]
        self.kernel.GlobalLock.restype = c.c_void_p
        self.kernel.GlobalUnlock.argtypes = [c.c_void_p]
        self.kernel.GlobalAlloc.argtypes = [c.c_uint, c.c_size_t]
        self.kernel.GlobalAlloc.restype = c.c_void_p
        self.kernel.GlobalFree.argtypes = [c.c_void_p]
        self.saved = []
        self.open()
        try:
            fmt = 0
            while True:
                fmt = self.user.EnumClipboardFormats(fmt)
                if not fmt:
                    break
                handle = self.user.GetClipboardData(fmt)
                size = self.kernel.GlobalSize(handle)
                if fmt in (2, 3, 9, 14, 0x80, 0x82, 0x83, 0x8E) or not size:
                    raise RuntimeError('Clipboard has a non-memory format; refusing to overwrite it for testing.')
                pointer = self.kernel.GlobalLock(handle)
                if not pointer:
                    raise c.WinError(c.get_last_error())
                try:
                    self.saved.append((fmt, c.string_at(pointer, size)))
                finally:
                    self.kernel.GlobalUnlock(handle)
        finally:
            self.user.CloseClipboard()
        return self

    def open(self):
        for _ in range(50):
            if self.user.OpenClipboard(None):
                return
            time.sleep(0.01)
        raise c.WinError(c.get_last_error())

    def __exit__(self, *args):
        self.open()
        try:
            self.user.EmptyClipboard()
            for fmt, payload in self.saved:
                handle = self.kernel.GlobalAlloc(2, len(payload))
                pointer = self.kernel.GlobalLock(handle)
                c.memmove(pointer, payload, len(payload))
                self.kernel.GlobalUnlock(handle)
                if not self.user.SetClipboardData(fmt, handle):
                    self.kernel.GlobalFree(handle)
                    raise c.WinError(c.get_last_error())
        finally:
            self.user.CloseClipboard()

class NativeInputTest(unittest.TestCase):
    def test_join_dialogs(self):
        dll = Path(os.environ.get('FTEWEBCORE_DLL', str(ROOT / 'ftewebcore.dll')))
        directory = os.add_dll_directory(str(dll.parent))
        library = c.WinDLL(str(dll))
        get_api = library.ftewebcore_get_api
        get_api.argtypes = [c.c_uint32, c.POINTER(t.API)]
        get_api.restype = c.c_int
        api = t.API()
        api.struct_size = c.sizeof(api)
        self.assertEqual(get_api(1, c.byref(api)), 1)
        self.assertEqual(api.initialize(), 1)
        buffers, results = [], []

        @t.RESOURCE_OPEN
        def resource_open(_u, url, data, size, mime, resource):
            parts = urlsplit(url.decode())
            path = (ROOT / 'base' / parts.netloc / unquote(parts.path).lstrip('/')).resolve()
            if ROOT / 'base' not in path.parents or not path.is_file():
                return 0
            payload = path.read_bytes()
            buf = c.create_string_buffer(payload)
            kind = c.c_char_p((mimetypes.guess_type(str(path))[0] or 'application/octet-stream').encode())
            buffers.extend([buf, kind])
            data[0], size[0], mime[0] = c.cast(buf, c.c_void_p), len(payload), kind
            resource[0] = c.c_void_p(len(buffers))
            return 1

        @t.RESOURCE_CLOSE
        def resource_close(*args):
            pass

        @t.JS_QUERY
        def query(_u, request, reply, capacity):
            text = request.decode()
            if text.startswith('test:') and not reply:
                results.append(json.loads(text[5:]))
            response = b'[]'
            if reply and capacity:
                c.memmove(reply, response + b'\0', min(capacity, len(response) + 1))
            return len(response)

        @t.PAINT
        def paint(*args):
            pass

        cb = t.Callbacks(c.sizeof(t.Callbacks), None, resource_open, resource_close, query, paint)
        execute = c.WINFUNCTYPE(None, c.c_void_p, c.c_char_p)(api.execute_javascript)
        send = c.WINFUNCTYPE(None, c.c_void_p, c.c_int, c.c_uint32, c.c_int)(api.key)
        focus = c.WINFUNCTYPE(None, c.c_void_p, c.c_int)(api.set_focus)
        move = c.WINFUNCTYPE(None, c.c_void_p, c.c_int, c.c_int)(api.mouse_move)
        button = c.WINFUNCTYPE(None, c.c_void_p, c.c_int, c.c_int)(api.mouse_button)

        def pump(duration=0.05):
            until = time.monotonic() + duration
            while time.monotonic() < until:
                api.update()
                time.sleep(0.005)

        def js(source):
            execute(view, source.encode())
            pump()

        def key(code, char=0):
            send(view, code, char, 1)
            send(view, code, char, 0)

        def text(value):
            for char in value:
                key(ord(char.lower()) if char.isascii() else 0, ord(char))
            pump()

        def ctrl(char):
            send(view,137,0,1)
            key(ord(char), ord(char) - 96)
            send(view,137,0,0)
            pump()

        def state(expected):
            count = len(results)
            js("try { fte_query('test:'+JSON.stringify({value:field.value,start:field.selectionStart,end:field.selectionEnd,active:document.activeElement.id,events:events.slice(-8)})); } catch(e) { fte_query('test:'+JSON.stringify({error:String(e)})); }")
            self.assertGreater(len(results), count, 'state query did not execute')
            actual = results[-1]
            self.assertEqual(actual.get('value'), expected, actual)
            return actual

        try:
            for menu in ['title-menu', 'title-menu-v2']:
                with self.subTest(menu=menu):
                    view = api.create_view(('fte://data/web/' + menu + '/index.html').encode(), 1024, 768, c.byref(cb))
                    try:
                        pump(0.8)
                        focus(view, 1)
                        js("document.querySelector('[data-action=join-lobby]').click();")
                        pump(0.8)
                        js("var field=document.getElementById('join-code'),events=[];['keydown','keypress','beforeinput','input','paste'].forEach(function(name){field.addEventListener(name,function(e){events.push({type:e.type,key:e.key,prevented:e.defaultPrevented});});});var r=field.getBoundingClientRect();fte_query('test:'+JSON.stringify({x:r.left+r.width/2,y:r.top+r.height/2}));")
                        rect = results[-1]
                        move(view, int(rect['x']), int(rect['y']))
                        button(view, 0, 1); button(view, 0, 0); pump()
                        self.assertEqual(state('')['active'], 'join-code')
                        text('abc')
                        state('abc')
                        key(127); key(134); key(140); pump()
                        state('a')
                        send(view,137,0,1); key(ord('a'),1); send(view,137,0,0)
                        text('Z')
                        state('Z')
                        js("field.readOnly=true;")
                        text('x')
                        state('Z')
                        with ClipboardSnapshot():
                            ctrl('a'); state('Z'); ctrl('c'); state('Z')
                            ctrl('v'); state('Z')  # A read-only field must not paste.
                            js("field.readOnly=false;")
                            text('replacement')
                            state('replacement')
                            ctrl('a'); ctrl('v')
                            state('Z')
                            self.assertIn('paste', [e['type'] for e in results[-1]['events']])
                            ctrl('a'); ctrl('x')
                            state('')
                            ctrl('v')
                            state('Z')
                            js("field.addEventListener('paste',function(e){e.preventDefault();},{once:true});")
                            ctrl('v'); state('Z')
                        js("field.addEventListener('keydown',function(e){if(e.key==='q')e.preventDefault();});field.addEventListener('keypress',function(e){if(e.key==='r')e.preventDefault();});")
                        text('qr')
                        state('Z')
                        js("field.addEventListener('beforeinput',function(e){if(e.data==='s')e.preventDefault();});")
                        text('s'); state('Z')
                        js("field.disabled=true;")
                        text('x'); state('Z')
                        js("field.disabled=false;field.focus();")
                        ctrl('a'); text('Aé😀'); state('Aé😀')
                        ctrl('a'); js("field.maxLength=4;")
                        text('abcdef'); state('abcd')
                        # Shift+Left selects one character, then typing replaces it.
                        send(view,138,0,1); key(134); send(view,138,0,0)
                        text('X'); state('abcX')
                        print(menu + ': native click, typing, editing, copy/cut/paste, cancellation, Unicode and limits pass', flush=True)
                    finally:
                        api.destroy_view(view)
        finally:
            api.shutdown()
            directory.close()

if __name__ == '__main__':
    unittest.main()
