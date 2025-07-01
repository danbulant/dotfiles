pragma ComponentBehavior: Bound
import "root:/"
import "root:/services"
import "root:/modules/common"
import "root:/modules/common/widgets"
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Scope {
//     id: overviewScope
    PanelWindow {
        id: root
        // required property var modelData
        property string searchingText: ""
        // readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
        // property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor.id)
        // property bool searching: overviewScope.previewWindows
        // screen: modelData
        visible: GlobalStates.overviewSearchOpen

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Overlay
        // WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: GlobalStates.overviewSearchOpen ? columnLayout : null
        }
        HyprlandWindow.visibleMask: Region {
            item: GlobalStates.overviewSearchOpen ? columnLayout : null
        }


        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        HyprlandFocusGrab {
            id: grab
            windows: [ root ]
            // property bool canBeActive: root.monitorIsFocused
            onCleared: () => {
                if (!active) GlobalStates.overviewSearchOpen = false
            }
        }

        Connections {
            target: GlobalStates
            function onOverviewSearchOpenChanged() {
                if (!GlobalStates.overviewSearchOpen) {
                    searchWidget.disableExpandAnimation()
                    GlobalStates.dontAutoCancelSearch = false;
                } else {
                    if (!GlobalStates.dontAutoCancelSearch) {
                        searchWidget.cancelSearch()
                    }
                    delayedGrabTimer.start()
                }
            }
        }

        Timer {
            id: delayedGrabTimer
            interval: ConfigOptions.hacks.arbitraryRaceConditionDelay
            repeat: false
            onTriggered: {
                // if (!grab.canBeActive) return
                grab.active = GlobalStates.overviewSearchOpen
            }
        }

        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
        }

        ColumnLayout {
            id: columnLayout
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: !ConfigOptions.bar.bottom ? parent.top : undefined
                bottom: ConfigOptions.bar.bottom ? parent.bottom : undefined
            }

            Keys.onPressed: (event) => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewSearchOpen = false;
                }
            }

            Item {
                height: 1 // Prevent Wayland protocol error
                width: 1 // Prevent Wayland protocol error
            }

            SearchWidget {
                id: searchWidget
                Layout.alignment: Qt.AlignHCenter
                onSearchingTextChanged: (text) => {
                    root.searchingText = searchingText
                    // root.searching = (searchingText.length > 0)
                }
            }
        }

    }
// }
