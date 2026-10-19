import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "aiUsage"

    StyledText {
        width: parent.width
        text: "AI Usage"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }
    StyledText {
        width: parent.width
        text: "Auto prefers omp usage --json and falls back to CodexBar only if OMP returns no usable limits. Partial provider failures never hide working accounts, including recoverable CLI exits 1 and 3. A failed refresh retains the last good values with a stale warning. The bar uses each account’s session limit, or weekly when session is absent, then shows the highest usage across accounts."
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
    DankDropdown {
        text: "Usage backend"
        currentValue: root.loadValue("backend", "auto")
        options: ["auto", "omp", "codexbar"]
        onValueChanged: value => root.saveValue("backend", value)
    }
    DankDropdown {
        text: "Refresh interval (milliseconds)"
        currentValue: root.loadValue("refreshInterval", "120000")
        options: ["60000", "120000", "300000", "900000", "1800000"]
        onValueChanged: value => root.saveValue("refreshInterval", value)
    }
    StyledText {
        width: parent.width
        text: "Executable paths (blank uses PATH)"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeMedium
    }
    DankTextField {
        width: parent.width
        text: root.loadValue("ompPath", "")
        placeholderText: "omp"
        onEditingFinished: root.saveValue("ompPath", text)
    }
    DankTextField {
        width: parent.width
        text: root.loadValue("codexbarPath", "")
        placeholderText: "codexbar"
        onEditingFinished: root.saveValue("codexbarPath", text)
    }
    DankDropdown {
        text: "CodexBar source"
        currentValue: root.loadValue("sourceMode", "oauth")
        options: ["oauth", "auto", "cli", "api"]
        onValueChanged: value => root.saveValue("sourceMode", value)
    }
    StyledText {
        width: parent.width
        text: "The bar shows an icon and usage percentage. Popout ranges show all reported windows, relative reset times and saved resets with their nearest expiry. Cache age is shown as a relative time per account. Expected usage is a linear pacing guide, not a provider forecast. Monthly windows without a duration use the previous calendar-month anniversary of their reset time. Missing monetary data is not estimated from quota percentages.\n\nThis plugin is deployed by the dotfiles Home Manager module. Enable AI Usage in DMS Plugins and add it in the bar’s widget settings on each machine. Authentication stays local; OMP uses its own credentials, CodexBar its own."
        wrapMode: Text.WordWrap
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
    }
}
