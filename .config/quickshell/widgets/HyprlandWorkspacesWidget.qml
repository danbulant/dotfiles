import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: container
    property var icons: {1: "1", 2: "2", 3: "3", 4: "4", 5: "5"}
    property int nWorkspaces: 5
    property font font
    property color default_color
    property color empty_color
    property color active_color

    Component.onCompleted: {
        var workspaceComponent = Qt.createComponent("../components/HyprlandWorkspace.qml")
        Hyprland.rawEvent.connect(hyprEvent)
        for (var i = 1; i <= nWorkspaces; i++) {
            var workspace = workspaceComponent
                .createObject(container, 
                    {
                        id: i, 
                        icon: icons[i], 
                        font: font, 
                        default_color: default_color,
                        empty_color: empty_color,
                        active_color: active_color
                    }
                )
            if (workspace == null) {
                console.log("Error creating workspace")
            }
        }
    }

    function hyprEvent(e) {
        // console.log(e.name, e.data)
        // console.log(Hyprland.workspaces.values)
        // console.log(Hyprland)
    }
}
