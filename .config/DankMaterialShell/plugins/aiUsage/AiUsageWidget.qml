import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "Usage.js" as Usage

PluginComponent {
    id: root

    property var payload: null
    property string activeBackend: "omp"
    property string fallbackReason: ""
    property string errorMessage: ""
    property bool loading: false
    property double now: Date.now()
    readonly property string backend: pluginData.backend || "auto"
    readonly property int refreshInterval: Math.max(60000, Number(pluginData.refreshInterval) || 120000)
    readonly property var snapshot: payload ? Usage.normalize(payload.text, payload.backend, now) : ({providers: [], warnings: []})
    readonly property var topUsage: Usage.chooseTop(snapshot.providers)
    readonly property string barText: topUsage ? Math.round(topUsage.percent) + "%" : loading ? "…" : errorMessage ? "ERR" : "N/A"
    readonly property string notices: [errorMessage, fallbackReason].concat(snapshot.warnings).filter(function(s) { return !!s }).join("\n")

    function usageColor(percent) {
        return percent >= 80 ? Theme.error : percent >= 60 ? Theme.warning : Theme.success
    }

    function startBackend(name) {
        activeBackend = name
        var executable = name === "omp" ? (pluginData.ompPath || "omp") : (pluginData.codexbarPath || "codexbar")
        // The shell only execs positional arguments; paths/settings are never interpolated.
        var command = ["sh", "-c", "exec \"$@\"", "ai-usage", executable, "usage"]
        if (name === "omp") {
            command.push("--json", "--no-extensions")
        } else {
            command.push("--format", "json", "--provider", "both", "--source", pluginData.sourceMode || "oauth")
        }
        usageProcess.command = command
        usageProcess.running = true
    }

    function refresh() {
        if (loading) return
        loading = true
        fallbackReason = ""
        startBackend(backend === "codexbar" ? "codexbar" : "omp")
    }

    function acceptOutput(text, code, stderrText) {
        var failure = ""
        try {
            // Exit 1/3 can contain usable providers. Judge the payload, not the status.
            var result = Usage.normalize(text, activeBackend, Date.now())
            if (Usage.chooseTop(result.providers)) {
                now = Date.now()
                payload = {text: text, backend: activeBackend}
                errorMessage = ""
                loading = false
                return
            }
            failure = result.warnings.join("\n") || "No usable quota windows returned"
        } catch (e) {
            failure = "Invalid or missing usage JSON: " + e.message
        }
        failure = activeBackend + " (exit " + code + "): " + failure
        if (stderrText.trim()) failure += "\n" + stderrText.trim().slice(0, 800)
        if (backend === "auto" && activeBackend === "omp") {
            fallbackReason = failure + "\nUsing CodexBar fallback."
            Qt.callLater(function() { root.startBackend("codexbar") })
            return
        }
        // Keep the last good snapshot, but explicitly mark it stale.
        errorMessage = (payload ? "Stale — refresh failed.\n" : "") + failure
        loading = false
    }

    Component.onCompleted: Qt.callLater(refresh)
    onBackendChanged: Qt.callLater(refresh)

    Process {
        id: usageProcess
        stdout: StdioCollector { id: usageOutput }
        stderr: StdioCollector { id: usageErrors }
        onExited: (code, status) => root.acceptOutput(usageOutput.text, code, usageErrors.text)
    }

    Timer {
        interval: root.refreshInterval
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS
            DankIcon {
                name: root.errorMessage ? "warning" : "monitoring"
                size: Theme.iconSize - 6
                color: root.topUsage ? root.usageColor(root.topUsage.percent) : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
            StyledText {
                text: root.barText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.topUsage ? root.usageColor(root.topUsage.percent) : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS
            DankIcon {
                name: root.errorMessage ? "warning" : "monitoring"
                size: Theme.iconSize - 6
                color: root.topUsage ? root.usageColor(root.topUsage.percent) : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
            StyledText {
                text: root.topUsage ? Math.round(root.topUsage.percent) + "%" : root.loading ? "…" : "—"
                font.pixelSize: Theme.fontSizeSmall
                color: root.topUsage ? root.usageColor(root.topUsage.percent) : Theme.surfaceVariantText
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: 480
    popoutContent: Component {
        PopoutComponent {
            headerText: "Plans"
            showCloseButton: true
            headerActions: Component {
                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: refreshArea.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                    DankIcon {
                        anchors.centerIn: parent
                        name: "refresh"
                        size: 18
                        color: Theme.surfaceText
                    }
                    MouseArea {
                        id: refreshArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.refresh()
                    }
                }
            }

            Flickable {
                width: parent.width
                height: Math.min(cards.implicitHeight, Math.max(180, (root.parentScreen ? root.parentScreen.height : 900) - 240), 650)
                contentHeight: cards.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: cards
                    width: parent.width
                    spacing: Theme.spacingS

                    StyledText {
                        width: parent.width
                        visible: !!root.notices
                        text: root.notices
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: Theme.warning
                        font.pixelSize: Theme.fontSizeSmall
                    }

                    StyledText {
                        width: parent.width
                        visible: root.snapshot.providers.length === 0
                        text: root.loading ? "Fetching usage…" : "No usage limits available. Check provider authentication."
                        wrapMode: Text.WordWrap
                        color: Theme.surfaceVariantText
                    }

                    Repeater {
                        model: root.snapshot.providers
                        StyledRect {
                            id: providerCard
                            required property var modelData
                            width: cards.width
                            height: providerColumn.implicitHeight + Theme.spacingM * 2
                            radius: Theme.cornerRadius
                            color: Theme.surfaceContainerHigh

                            Column {
                                id: providerColumn
                                x: Theme.spacingM
                                y: Theme.spacingM
                                width: parent.width - Theme.spacingM * 2
                                spacing: Theme.spacingS

                                StyledText {
                                    width: parent.width
                                    text: providerCard.modelData.name + (providerCard.modelData.plan ? " · " + providerCard.modelData.plan : "")
                                    textFormat: Text.PlainText
                                    wrapMode: Text.WordWrap
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Font.Bold
                                    color: Theme.surfaceText
                                }
                                StyledText {
                                    width: parent.width
                                    visible: !!text
                                    text: providerCard.modelData.identity
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                }
                                StyledText {
                                    width: parent.width
                                    visible: !!text
                                    text: providerCard.modelData.error
                                    textFormat: Text.PlainText
                                    wrapMode: Text.Wrap
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.warning
                                }

                                Repeater {
                                    model: providerCard.modelData.windows
                                    Column {
                                        id: quota
                                        required property var modelData
                                        width: providerColumn.width
                                        spacing: 4
                                        StyledText {
                                            width: parent.width
                                            text: quota.modelData.label + " · " + (quota.modelData.percent === null ? "Usage unavailable" : quota.modelData.percent.toFixed(1) + "% used")
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: quota.modelData.percent === null ? Theme.surfaceVariantText : root.usageColor(quota.modelData.percent)
                                            wrapMode: Text.WordWrap
                                        }
                                        Rectangle {
                                            width: parent.width
                                            height: 8
                                            radius: 4
                                            color: Theme.surfaceContainerHighest
                                            Rectangle {
                                                width: Math.max(0, Math.min(1, (quota.modelData.percent || 0) / 100)) * parent.width
                                                height: parent.height
                                                radius: parent.radius
                                                color: root.usageColor(quota.modelData.percent || 0)
                                            }
                                            Rectangle {
                                                visible: quota.modelData.expectedPercent !== null
                                                x: Math.max(0, Math.min(parent.width - width, parent.width * (quota.modelData.expectedPercent || 0) / 100))
                                                width: 2
                                                height: parent.height + 4
                                                y: -2
                                                color: Theme.surfaceText
                                            }
                                        }
                                        StyledText {
                                            width: parent.width
                                            text: Usage.windowDetail(quota.modelData, root.now)
                                            textFormat: Text.PlainText
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceVariantText
                                        }
                                    }
                                }

                                Repeater {
                                    model: providerCard.modelData.details
                                    StyledText {
                                        required property string modelData
                                        width: providerColumn.width
                                        text: modelData
                                        textFormat: Text.PlainText
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Theme.fontSizeSmall
                                        color: Theme.surfaceVariantText
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
