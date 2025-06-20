import QtQuick
import Quickshell.Hyprland
import Quickshell.Widgets

WrapperRectangle {
    required property int id
    required property string icon
    required property color default_color
    required property color empty_color
    required property color active_color
    required property font font
    property bool active: false
    color: active ? "#753a88" : "transparent"

    radius: 20
    topMargin: 3
    bottomMargin: 3
    leftMargin: active ? 12 : 6
    rightMargin: active ? 12 : 6

    Text {
        text: icon
        color: active ? parent.active_color : parent.empty_color
        font: parent.font

        Component.onCompleted: {
            Hyprland.rawEvent.connect(hyprEvent)
            colorWorkspace()
        }

        function hyprEvent(e) {
            if (e.name == "workspace") {
                parent.active = e.data == id
                if (e.data == id) {
                    text.color = parent.active_color
                } else {
                    colorWorkspace()
                }
            }
        }

        function colorWorkspace() {
            if (Hyprland.workspaces.values.some((w) => {
                return w.id == id && w.lastIpcObject.windows > 0
            })) {
                text.color = parent.default_color
            } else {
                text.color = parent.empty_color
            }
        }
    }
}
