import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Fusion
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 532
    height: 196
    minimumWidth: 532
    maximumWidth: 532
    minimumHeight: 196
    maximumHeight: 196
    visible: true
    title: "stiletto updater"
    color: "#2d2d2d"
    flags: Qt.Window | Qt.FramelessWindowHint

    // --- updater state ---
    property string manifestURL: ""
    property string localVersionFile: "game/version.txt"
    property string localVersion: ""
    property string remoteVersion: ""
    property var remoteManifest: null
    property bool updateAvailable: false
    property bool applyRunning: false

    FontLoader {
        id: fontStandard
        source: "fonts/standard_07_57.ttf/standard_07_57.ttf"
    }
    FontLoader {
        id: fontHooge
        source: "fonts/standard_07_57.ttf/hooge-0557-regular_ufonts.com.ttf"
    }

    MainForm {
        id: form
        anchors.fill: parent

        updateButton.onClicked: {
            if (window.updateAvailable)
                window.startApply()
            else
                window.checkForUpdates()
        }
    }

    Timer {
        id: applyPoll
        interval: 250
        repeat: true
        onTriggered: window.pollApplyStatus()
    }

    // Drag the frameless window from the top strip (buttons sit above this).
    MouseArea {
        id: dragRegion
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 44
        z: 1
        property real pressX: 0
        property real pressY: 0
        onPressed: function (mouse) {
            pressX = mouse.x
            pressY = mouse.y
        }
        onPositionChanged: function (mouse) {
            if (pressed) {
                window.x += mouse.x - pressX
                window.y += mouse.y - pressY
            }
        }
    }

    Row {
        id: windowControls
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 6
        anchors.rightMargin: 6
        spacing: 2
        z: 2

        Rectangle {
            width: 28
            height: 28
            radius: 4
            color: minArea.containsMouse ? "#3a3a3a" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "—"
                color: "#b0b0b0"
                font.pixelSize: 12
                font.family: "standard 07_57"
            }

            MouseArea {
                id: minArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: window.showMinimized()
            }
        }

        Rectangle {
            width: 28
            height: 28
            radius: 4
            color: closeArea.containsMouse ? "#5a2020" : "transparent"

            Text {
                anchors.centerIn: parent
                text: "×"
                color: closeArea.containsMouse ? "#ffffff" : "#b0b0b0"
                font.pixelSize: 16
                font.family: "standard 07_57"
            }

            MouseArea {
                id: closeArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: window.close()
            }
        }
    }

    Component.onCompleted: {
        loadConfigThenCheck()
    }

    function setBusy(on, message) {
        form.busy = on
        if (message !== undefined && message !== null)
            form.message = message
    }

    function setBuildLabel(version) {
        form.currentBuildLabel = version && version.length
            ? ("current build: " + version)
            : "current build: —"
    }

    function setAction(label, enabled, visible) {
        form.actionLabel = label
        form.actionEnabled = enabled
        form.actionVisible = visible
    }

    function setProgress(value) {
        form.progress = value
        form.progressLabel = Math.round(value * 100) + "%"
    }

    function loadConfigThenCheck() {
        setBusy(true, "Reading config...")
        setAction("Update", false, false)

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            if (xhr.status === 200 || xhr.status === 0) {
                try {
                    var cfg = JSON.parse(xhr.responseText)
                    if (cfg.manifestURL)
                        window.manifestURL = cfg.manifestURL
                    if (cfg.localVersionFile)
                        window.localVersionFile = cfg.localVersionFile
                    if (cfg.windowTitle)
                        window.title = cfg.windowTitle
                } catch (e) {
                    form.message = "Couldn't parse config.json"
                    setBusy(false)
                    setAction("Retry", true, true)
                    return
                }
            }

            readLocalVersionThenCheck()
        }
        xhr.open("GET", Qt.resolvedUrl("config.json"))
        xhr.send()
    }

    function readLocalVersionThenCheck() {
        setBusy(true, "Reading local build...")
        setAction("Update", false, false)

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            // status 0 is common for successful file:// / qrc reads in qml
            if ((xhr.status === 200 || xhr.status === 0) && xhr.responseText) {
                window.localVersion = String(xhr.responseText).trim()
            } else {
                window.localVersion = ""
            }
            setBuildLabel(window.localVersion)
            checkForUpdates()
        }
        // Local install lives under ../game/ (see config localVersionFile).
        xhr.open("GET", Qt.resolvedUrl("../" + window.localVersionFile))
        xhr.send()
    }

    function checkForUpdates() {
        window.updateAvailable = false
        window.remoteManifest = null
        window.remoteVersion = ""
        form.downloading = false
        setProgress(0)
        setAction("Update", false, false)

        if (!window.manifestURL || window.manifestURL.length === 0) {
            setBusy(false)
            form.message = "Set manifestURL in app/config.json"
            setAction("Retry", true, true)
            return
        }

        setBusy(true, "Connecting to update server...")
        setAction("Update", false, false)

        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            setBusy(false)

            if (xhr.status !== 200) {
                form.message = "Couldn't connect to update server"
                setAction("Retry", true, true)
                return
            }

            try {
                var manifest = JSON.parse(xhr.responseText)
                window.remoteManifest = manifest
                window.remoteVersion = manifest.version || ""
            } catch (e) {
                form.message = "Couldn't parse update manifest"
                setAction("Retry", true, true)
                return
            }

            if (!window.remoteVersion) {
                form.message = "Manifest has no version"
                setAction("Retry", true, true)
                return
            }

            if (window.localVersion && window.localVersion === window.remoteVersion) {
                window.updateAvailable = false
                form.message = "Build is up to date"
                setAction("Check", true, true)
            } else {
                window.updateAvailable = true
                form.message = window.localVersion
                    ? ("New build available: " + window.remoteVersion)
                    : ("Nightly build " + window.remoteVersion + " is ready")
                setAction("Update", true, true)
            }
        }
        xhr.onerror = function () {
            setBusy(false)
            form.message = "Couldn't connect to update server"
            setAction("Retry", true, true)
        }
        xhr.open("GET", window.manifestURL)
        xhr.send()
    }

    function startApply() {
        if (!window.remoteManifest || !window.updateAvailable)
            return

        form.downloading = true
        setProgress(0)
        setBusy(false, "Starting update...")
        setAction("Update", false, false)
        window.applyRunning = true

        // Ask NuclideLauncher.exe to re-enter in --apply mode (same binary).
        var put = new XMLHttpRequest()
        put.onreadystatechange = function () {
            if (put.readyState !== XMLHttpRequest.DONE)
                return

            var launcherUrl = Qt.resolvedUrl("../NuclideLauncher.exe")
            if (!Qt.openUrlExternally(launcherUrl)) {
                form.downloading = false
                window.applyRunning = false
                form.message = "Couldn't start updater apply"
                setAction("Retry", true, true)
                return
            }
            applyPoll.start()
        }
        put.open("PUT", Qt.resolvedUrl("../apply.request"))
        put.send("1")
    }

    function pollApplyStatus() {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return

            if (!(xhr.status === 200 || xhr.status === 0) || !xhr.responseText)
                return

            try {
                var st = JSON.parse(xhr.responseText)
            } catch (e) {
                return
            }

            if (st.message)
                form.message = st.message
            if (typeof st.progress === "number")
                setProgress(st.progress)

            if (st.phase === "download") {
                form.downloading = true
                form.busy = false
            } else if (st.phase === "apply") {
                form.downloading = false
                form.busy = true
            } else if (st.phase === "done") {
                applyPoll.stop()
                window.applyRunning = false
                form.downloading = false
                form.busy = false
                setProgress(1)
                if (st.version) {
                    window.localVersion = st.version
                    setBuildLabel(st.version)
                }
                window.updateAvailable = false
                setAction("Check", true, true)
            } else if (st.phase === "error") {
                applyPoll.stop()
                window.applyRunning = false
                form.downloading = false
                form.busy = false
                setProgress(0)
                setAction("Retry", true, true)
            }
        }
        xhr.open("GET", Qt.resolvedUrl("../apply-status.json"))
        xhr.send()
    }

    function startDownload() {
        startApply()
    }
}
