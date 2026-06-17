# H3 Main Menu Loading Failure Investigation

## Executive Summary

The h3-main-menu page fails to load with "web server IP cannot be accessed" error. The root cause is a **URL scheme mismatch** between what the app.js expects and what the CEF plugin serves. The browser receives `http://web/h3-main-menu/index.html` but CEF's resource handler only recognizes `fte://data/` URLs, causing all fetch requests to fail with HTTP errors that manifest as network access errors to the user.

## Investigation Results

### 1. CEF Plugin URL Handling (ThirdParty/fteqw/plugins/cef/cef.c)

#### What CEF Registers
- **Scheme**: `fte://` (registered at lines 833-846)
- **Flags**: STANDARD | DISPLAY_ISOLATED | SECURE | CORS_ENABLED

#### Resource Handler Logic (lines 1151-1334)
The `resource_handler_process_request` function processes all `fte://` URLs:

```c
// Only handles three URL patterns:
if (!strncmp(u8_url.str, "fte://data/", 11))          // File serving via game filesystem
else if (!strncmp(u8_url.str, "fte://ssqc/", 11))      // Server QuakeC generation
else if (!strncmp(u8_url.str, "fte://csqc/", 11))      // Client QuakeC generation  
else if (!strncmp(u8_url.str, "fte://menu/", 11))      // Menu QuakeC generation
else                                                    // Everything else -> 403 Forbidden
{
    rh->resultcode = 403;
    rh->data = "<html>...forbidden...</html>";
}
```

**Critical Finding**: URLs NOT matching these patterns return **HTTP 403 Forbidden** with generic HTML error page.

#### File Serving Path (line 1193)
```c
rh->fh = fsfuncs->OpenVFS(u8_url.str+6, "rb", FS_GAME);
// u8_url.str+6 removes "fte://" prefix
// So fte://data/web/h3-main-menu/data.json becomes web/h3-main-menu/data.json
```

### 2. Menu URL Configuration (ThirdParty/fteqw/engine/client/m_cefmenu.c)

#### URL Being Set (line 125)
```c
Q_strncpyz(cm->browser_url, "fte://data/web/h3-main-menu/index.html", sizeof(cm->browser_url));
```

**Expected**: Correct - sets `fte://data/web/h3-main-menu/index.html`

#### CEF Command Execution (lines 133-135)
```c
Cbuf_AddText("cef ", RESTRICT_LOCAL);
Cbuf_AddText(cm->browser_url, RESTRICT_LOCAL);
Cbuf_AddText("\n", RESTRICT_LOCAL);
```

This invokes the CEF plugin with the URL.

### 3. Browser URL Mismatch (From Debug Logs)

#### What the Browser Actually Receives
```
[257236:268208:0602/024705.080:VERBOSE1:net\base\network_delegate.cc:38] 
  NetworkDelegate::NotifyBeforeURLRequest: http://web/h3-main-menu/index.html
```

**Critical Issue**: The browser loads `http://web/h3-main-menu/index.html` instead of `fte://data/web/h3-main-menu/index.html`!

This suggests:
1. The CEF plugin is converting or overriding the URL scheme
2. OR the browser.navigate() call is not receiving the correct URL
3. OR there's a custom URL handler intercepting it

### 4. app.js URL Construction Logic (lines 57-101)

The JavaScript tries to handle three URL schemes:

```javascript
const isFteScheme = location.href.startsWith("fte://") || location.origin.includes("fte");

if (isFteScheme || location.href.startsWith("game://")) {
    // Detect fte:// or game:// scheme and construct absolute URL
    const fullPath = location.href;
    
    if (fullPath.startsWith("fte://")) {
        // Extract directory from href
        fullPath = fullPath.substring(6);  // Remove "fte://"
        const dir = fullPath.substring(0, fullPath.lastIndexOf('/'));
        dataUrl = `fte://${dir}/data.json?t=${Date.now()}`;
        console.warn(`[H3 Menu] Detected fte:// scheme. Converted to: "${dataUrl}"`);
    } else if (fullPath.startsWith("game://")) {
        // game:// -> fte:// with data prefix
        fullPath = fullPath.substring(7);
        const dir = fullPath.substring(0, fullPath.lastIndexOf('/'));
        dataUrl = `fte://data/${dir}/data.json?t=${Date.now()}`;
        console.warn(`[H3 Menu] Detected game:// scheme. Converted to fte:// with data prefix: "${dataUrl}"`);
    }
} else {
    // Plain http/https - use relative path
    console.warn(`[H3 Menu] Not using fte:// or game:// scheme, using relative path`);
    dataUrl = "data.json?t=" + Date.now();
}
```

#### The Problem
**`location.href` is `http://web/h3-main-menu/index.html`**, not `fte://...`, so:
- `isFteScheme` check fails (http doesn't start with fte://)
- Falls through to "use relative path" branch
- Attempts `fetch("data.json?t=" + Date.now())`
- This becomes `http://web/h3-main-menu/data.json`
- **CEF resource handler receives `http://...` URL** 
- **CEF does NOT register handlers for `http://` scheme**
- **Browser defaults to real HTTP request**
- **Fails because there's no actual web server at `http://web/`**

### 5. Console Error Output (app.js line 97)
```javascript
} catch (err) {
    console.error("Failed to load data.json:", err);
    document.body.innerHTML =
        "<pre style='color:red;padding:2em'>Failed to load data.json: " + err.message + "</pre>";
    return;
}
```

The error is caught and displayed as: **"Failed to load data.json: (network error message)"**

This would appear as "web server IP cannot be accessed" because the browser interprets the `http://web/...` fetch as a network request to a non-existent server.

---

## Root Cause Analysis

### Primary Issue: URL Scheme Conversion
CEF is being initialized with `fte://data/web/h3-main-menu/index.html`, but somewhere between the CEF plugin and the browser's initial navigation, the URL is being converted to `http://web/h3-main-menu/index.html`.

**Possible causes:**
1. CEF itself might have a setting that converts non-standard schemes to http
2. The CEF plugin's browser creation might be stripping the scheme
3. There's an intermediate URL mapper that's converting fte:// to http://

### Secondary Issue: Relative URL Resolution
Even if the index.html loads correctly on an http:// URL, the app.js uses relative path `data.json` for its fetch, which won't match the CEF resource handler's patterns.

### Tertiary Issue: CORS Headers
The CEF resource handler sets CORS headers (lines 1184-1187):
```c
res_catfield(&rh->responseheaders, "Access-Control-Allow-Origin", "fte://data");
res_catfield(&rh->responseheaders, "Access-Control-Allow-Origin", "fte://csqc");
res_catfield(&rh->responseheaders, "Access-Control-Allow-Origin", "fte://ssqc");
res_catfield(&rh->responseheaders, "Access-Control-Allow-Origin", "fte://menu");
```

These headers don't include `http://` origins, so even if the fetch were to somehow work, CORS would block it.

---

## Data.json File Location

- **Path**: `base/web/h3-main-menu/data.json`
- **VFS Resolution**: Should resolve to `web/h3-main-menu/data.json` when accessed as `fte://data/web/h3-main-menu/data.json`
- **Status**: File exists and is valid JSON (300+ lines)
- **Size**: ~22KB

The file serves correctly when accessed through the proper `fte://data/` URL scheme.

---

## Exact URLs Being Requested

### Browser Initial Navigation
- **Expected**: `fte://data/web/h3-main-menu/index.html`
- **Actual**: `http://web/h3-main-menu/index.html` ← **WRONG**

### app.js data.json Fetch
- **If fte:// navigation worked**: Would construct `fte://data/web/h3-main-menu/data.json` (correct)
- **What actually happens**: Falls back to `http://web/h3-main-menu/data.json` ← **WRONG**
- **App then logs**: `[H3 Menu] Not using fte:// or game:// scheme, using relative path`

### HTTP 403 Response Flow
If somehow the CEF resource handler DID receive `http://web/...`:
1. URL doesn't match `fte://data/`, `fte://ssqc/`, `fte://csqc/`, or `fte://menu/`
2. Falls to else clause (line 1320)
3. Returns HTTP 403 with HTML error message
4. Browser receives error page

---

## CEF Scheme Registration Summary

| Scheme | Supported | Handler | Result |
|--------|-----------|---------|--------|
| `fte://data/` | ✓ | VFS file serving | 200 OK or 404 Not Found |
| `fte://ssqc/` | ✓ | Server QuakeC generation | 200 OK or 404 |
| `fte://csqc/` | ✓ | Client QuakeC generation | 200 OK or 404 |
| `fte://menu/` | ✓ | Menu QuakeC generation | 200 OK or 404 |
| `http://` | ✗ | (no handler) | Browser defaults to real HTTP |
| `https://` | ✗ | (no handler) | Browser defaults to real HTTPS |
| `game://` | ✗ | (no handler) | Browser default behavior |
| Everything else | - | Forbidden handler | 403 Forbidden |

---

## Summary of Findings

1. **URL Scheme Mismatch**: The h3-main-menu is configured to load at `fte://data/web/h3-main-menu/index.html` but the browser receives `http://web/h3-main-menu/index.html`

2. **CEF Resource Handler Gap**: CEF's scheme handler factory only processes `fte://` URLs. All other schemes (including `http://`) fall through to browser defaults

3. **app.js Fallback Logic**: When `location.href` is not `fte://` or `game://`, the app falls back to relative path loading (`data.json`), which becomes `http://web/h3-main-menu/data.json`

4. **Network Resolution Failure**: Since there's no actual HTTP server listening on `http://web/`, the browser reports a network error that manifests as "web server IP cannot be accessed"

5. **CORS Headers Incomplete**: Even if a workaround were attempted, the CORS headers don't include `http://` origins, so cross-origin fetch would fail

6. **data.json File Exists**: The actual data.json is present and valid, just not being served due to the URL scheme issue

---

## The Core Problem

**CEF is being initialized with the wrong URL scheme**, or the CEF plugin/browser is incorrectly converting `fte://` URLs to `http://` URLs during initialization. The app.js detects this mismatch and falls back to relative path loading, which tries to fetch from a non-existent HTTP server, resulting in the observed network error.
