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

Scope {
    id: overviewScope

    OverviewSearch {
        id: searchPanel
    }

    Variants {
        id: overviewVariants
        model: Quickshell.screens
        PanelWindow {
            id: root
            required property var modelData
            readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.screen)
            property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor.id)
            screen: modelData
            visible: GlobalStates.overviewWindowsOpen

            WlrLayershell.namespace: "quickshell:overview"
            WlrLayershell.layer: WlrLayer.Overlay
            // WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            color: "transparent"

            mask: Region {
                item: GlobalStates.overviewWindowsOpen ? columnLayout : null
            }
            HyprlandWindow.visibleMask: Region {
                item: GlobalStates.overviewWindowsOpen ? columnLayout : null
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
                property bool canBeActive: root.monitorIsFocused
                onCleared: () => {
                    if (!active) GlobalStates.overviewWindowsOpen = false
                }
            }

            Connections {
                target: GlobalStates
                function onOverviewWindowsOpenChanged() {
                    if (GlobalStates.overviewWindowsOpen)  {
                        delayedGrabTimer.start()
                    }
                }
            }

            Timer {
                id: delayedGrabTimer
                interval: ConfigOptions.hacks.arbitraryRaceConditionDelay
                repeat: false
                onTriggered: {
                    if (!grab.canBeActive) return
                    grab.active = GlobalStates.overviewWindowsOpen
                }
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight

            ColumnLayout {
                id: columnLayout
                visible: GlobalStates.overviewWindowsOpen
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: !ConfigOptions.bar.bottom ? parent.top : undefined
                    bottom: ConfigOptions.bar.bottom ? parent.bottom : undefined
                }

                Keys.onPressed: (event) => {
                    if (event.key === Qt.Key_Escape) {
                        GlobalStates.overviewWindowsOpen = false;
                    } else if (event.key === Qt.Key_Left) {
                        Hyprland.dispatch("workspace r-1");
                    } else if (event.key === Qt.Key_Right) {
                        Hyprland.dispatch("workspace r+1");
                    }
                }

                Item {
                    height: 1 // Prevent Wayland protocol error
                    width: 1 // Prevent Wayland protocol error
                }

                Loader {
                    id: overviewLoader
                    active: GlobalStates.overviewWindowsOpen
                    sourceComponent: OverviewWidget {
                        panelWindow: root
                        visible: true
                    }
                }
            }

        }
    }


    // IpcHandler {
	// 	target: "overview"

    //     function toggle() {
    //         GlobalStates.overviewOpen = !GlobalStates.overviewOpen
    //     }
    //     function close() {
    //         GlobalStates.overviewOpen = false
    //     }
    //     function open() {
    //         GlobalStates.overviewOpen = true
    //     }
    //     function toggleReleaseInterrupt() {
    //         GlobalStates.superReleaseMightTrigger = false
    //     }
	// }
    GlobalShortcut {
        name: "overviewSearchToggle"
        description: qsTr("Toggles overview on press")

        onPressed: {
            GlobalStates.overviewSearchOpen = !GlobalStates.overviewSearchOpen
        }
    }
    GlobalShortcut {
        name: "overviewToggle"
        description: qsTr("Toggles overview on press")

        onPressed: {
            GlobalStates.overviewWindowsOpen = !GlobalStates.overviewWindowsOpen
        }
    }
    GlobalShortcut {
        name: "overviewClose"
        description: qsTr("Closes overview")

        onPressed: {
            GlobalStates.overviewSearchOpen = false
            GlobalStates.overviewWindowOpen = false
        }
    }
    GlobalShortcut {
        name: "overviewToggleRelease"
        description: qsTr("Toggles overview on release")

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true
                return
            }
            GlobalStates.overviewWindowsOpen = !GlobalStates.overviewWindowsOpen
        }
    }
    GlobalShortcut {
        name: "overviewToggleReleaseInterrupt"
        description: qsTr("Interrupts possibility of overview being toggled on release. ") +
            qsTr("This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. ") +
            qsTr("To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything.")

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: qsTr("Toggle clipboard query on overview widget")

        onPressed: {
            if (GlobalStates.overviewSearchOpen && GlobalStates.dontAutoCancelSearch) {
                GlobalStates.overviewSearchOpen = false;
                return;
            }
            GlobalStates.dontAutoCancelSearch = true;
            searchPanel.setSearchingText(
                ConfigOptions.search.prefix.clipboard
            );
            GlobalStates.overviewSearchOpen = true;
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: qsTr("Toggle emoji query on overview widget")

        onPressed: {
            if (GlobalStates.overviewSearchOpen && GlobalStates.dontAutoCancelSearch) {
                GlobalStates.overviewSearchOpen = false;
                return;
            }
            GlobalStates.dontAutoCancelSearch = true;
            searchPanel.setSearchingText(
                ConfigOptions.search.prefix.emojis
            );
            GlobalStates.overviewSearchOpen = true;
        }
    }

}
