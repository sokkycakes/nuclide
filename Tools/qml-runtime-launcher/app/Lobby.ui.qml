/*
This is a UI file (.ui.qml) that is intended to be edited in Qt Design Studio only.
It is supposed to be strictly declarative and only uses a subset of QML. If you edit
this file manually, you might introduce QML code that is not supported by Qt Design Studio.
Check out https://doc.qt.io/qtcreator/creator-quick-ui-forms.html for details on .ui.qml files.
*/

import QtQuick
import QtQuick.Controls

Item {
    id: root
    width: 640
    height: 480

    Rectangle {
        id: bg
        color: "#73373737"
        anchors.fill: parent

        Pane {
            id: gamePane
            x: 8
            y: 8
            width: 312
            height: 464
        }

        GroupBox {
            id: groupBox
            x: 326
            y: 41
            width: 306
            height: 431
            anchors.right: parent.right
            anchors.rightMargin: 8
            title: qsTr("")

            Frame {
                id: frame
                anchors.fill: parent
                anchors.leftMargin: 21
            }
        }
    }
}
