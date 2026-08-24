import QtQuick

Item {
    property bool layerBlurVisible: false
    property real layerBlurRadius: 0
    property bool backgroundBlurVisible: false
    default property alias effects: effectHost.data
    Item {
        id: effectHost
    }
}
