import Quickshell
import Quickshell.Hyprland
// import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.Notifications
import QtQuick
import "../widgets"
import QtQuick.Layouts

Scope {
    property font customFont: Qt.font({
        bold: true,
        pointSize: 12,
        family: "FantasqueSansMNerdFont"
    })

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: root
            property var modelData
            screen: modelData

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: 10
                left: 10
                right: 10
            }

            height: 50
            color: "#171a18"

            RowLayout {
                spacing: 15

                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 30
                }

                Text {
                    font: customFont
                    color: "#8ec07c"
                    text: ""
                }

                HyprlandWorkspacesWidget {
                    font: customFont
                    default_color: "#689D6A"
                    active_color: "#8ec07c"
                    empty_color: "#928374"
                    spacing: 15
                }
            }

            RowLayout {
                anchors.centerIn: parent
                spacing: 15

                ClockWidget {
                    font: customFont
                    color: "#8ec07c"
                }

                NotificationsWidget {
                    font: customFont
                    color: "#8ec07c"
                }
            }

            RowLayout {
                anchors {
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                    rightMargin: 30
                }
                spacing: 15

                // Image {
                //     Layout.fillHeight: true
                //     Layout.maximumHeight: 20
                //
                //     source: SystemTray.items.values[0].icon
                //     fillMode: Image.PreserveAspectFit
                // }

                PlayingWidget {
                    custom_font: customFont
                    hover_color: "#928374"
                    default_color: "#8ec07c"
                }

                NetworkWidget {
                    font: customFont
                    color: "#8ec07c"
                }

                AudioWidget {
                    font: customFont
                    color: "#8ec07c"
                    node: Pipewire.defaultAudioSink
                }
            }
        }
    }
}
