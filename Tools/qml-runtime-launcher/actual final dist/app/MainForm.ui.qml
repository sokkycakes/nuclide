import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Studio.DesignEffects


Rectangle {
    id: root
    width: 532
    height: 196
    color: "#2d2d2d"
    border.width: 0

    // Driven by main.qml. Keep bindings JS-free (.ui.qml rule).
    property bool busy: false
    property bool downloading: false
    property real progress: 0.0
    property string progressLabel: "0%"
    property string message: "Checking for updates..."
    property string currentBuildLabel: "current build: -"
    property string actionLabel: "Update"
    property bool actionEnabled: false
    property bool actionVisible: false

    property alias updateButton: button

    Image {
        id: the
        x: 238
        y: -87
        width: 279
        height: 394
        opacity: 0.2
        source: "images/the.svg"
        rotation: -88.285
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: squig
        x: 283
        y: -100
        width: 195
        height: 239
        opacity: 0.06
        source: "images/squig.svg"
        rotation: 0
        fillMode: Image.PreserveAspectFit
    }

    Image {
        id: logotile
        x: 8
        y: 0
        width: 236
        height: 61
        opacity: 0.1
        source: "images/logotile.svg"
        fillMode: Image.PreserveAspectFit
    }

    ProgressBar {
        id: progressBar
        width: 480
        height: 8
        from: 0
        to: 1
        value: root.progress
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 64
        visible: root.downloading
        anchors.horizontalCenterOffset: 1
        layer.enabled: false
        smooth: false
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Text {
        id: title
        x: 242
        y: 27
        color: "#404040"
        text: qsTr(" updater")
        font.pixelSize: 18
        font.weight: Font.Black
        font.family: "standard 07_57"
        DesignEffect {
            visible: true
            layerBlurVisible: false
            layerBlurRadius: 16
            effects: [
                DesignDropShadow {
                    visible: false
                    offsetY: 0
                }
            ]
            backgroundBlurVisible: false
        }
    }

    Button {
        id: button
        text: root.actionLabel
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 25
        anchors.bottomMargin: 25
        enabled: root.actionEnabled
        visible: root.actionVisible
        font.family: "standard 07_57"
    }

    BusyIndicator {
        id: busyIndicator
        running: root.busy
        visible: root.busy
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 27
    }

    Text {
        id: currentBuild
        x: 8
        y: 51
        color: "#636363"
        text: root.currentBuildLabel
        font.pixelSize: 12
        font.weight: Font.Black
        font.family: "hooge 05_57"
        DesignEffect {
            visible: true
            layerBlurVisible: false
            layerBlurRadius: 16
            effects: [
                DesignDropShadow {
                    visible: false
                    offsetY: 0
                }
            ]
            backgroundBlurVisible: false
        }
    }

    Text {
        id: messageText
        x: 29
        y: 87
        width: 470
        color: "#ffffff"
        text: root.message
        wrapMode: Text.WordWrap
        font.pixelSize: 14
        font.weight: Font.Black
        font.family: "standard 07_57"
        DesignEffect {
            visible: true
            layerBlurVisible: false
            layerBlurRadius: 16
            effects: [
                DesignDropShadow {
                    visible: false
                    offsetY: 0
                }
            ]
            backgroundBlurVisible: false
        }
    }

    Text {
        id: progressText
        x: 27
        y: 145
        color: "#717171"
        text: root.progressLabel
        visible: root.downloading
        font.pointSize: 9
        font.family: "hooge 05_57"
    }

    Image {
        id: squig1
        x: 382
        y: 57
        width: 195
        height: 239
        opacity: 0.06
        source: "images/squig.svg"
        scale: 1.5
        rotation: 180
        fillMode: Image.PreserveAspectFit
    }
}
