import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    readonly property var cfg: Plasmoid.configuration

    // -1 when no controller is connected
    property int level: -1
    property string status: ""
    property string hidId: ""
    property string hidName: ""
    property string address: ""

    readonly property bool connected: level >= 0
    readonly property bool charging: status === "Charging"
    readonly property bool low: connected && !charging && level <= cfg.lowThreshold
    readonly property bool canDisconnect: connected && connectionName === "Bluetooth" && /^([0-9a-f]{2}:){5}[0-9a-f]{2}$/i.test(address)
    property bool disconnecting: false

    readonly property color chartColor: low ? cfg.lowColor
        : cfg.useAccentColor ? Kirigami.Theme.highlightColor : cfg.chartColor

    readonly property string deviceName: {
        const product = hidId.split(":")[2] || "";
        if (/05C4|09CC/i.test(product)) return "DualShock 4";
        if (/0CE6/i.test(product)) return "DualSense";
        if (/0DF2/i.test(product)) return "DualSense Edge";
        return hidName || "Controller";
    }
    readonly property string connectionName: {
        const bus = hidId.split(":")[0] || "";
        if (bus === "0005") return "Bluetooth";
        if (bus === "0003") return "USB";
        return "Unknown";
    }
    readonly property string statusText: {
        switch (status) {
        case "Charging": return "Charging";
        case "Discharging": return "On battery";
        case "Full": return "Fully charged";
        case "Not charging": return "Plugged in, not charging";
        default: return status || "Unknown";
        }
    }

    // hid-playstation (DS4/DualSense) and the older hid-sony driver
    readonly property string probe: "for d in /sys/class/power_supply/ps-controller-battery-* /sys/class/power_supply/sony_controller_battery_*; do "
        + "[ -r \"$d/capacity\" ] || continue; u=\"$d/device/uevent\"; "
        + "echo \"$(cat \"$d/capacity\")|$(cat \"$d/status\")|$(sed -n 's/^HID_ID=//p' \"$u\")|$(sed -n 's/^HID_NAME=//p' \"$u\")|$(sed -n 's/^HID_UNIQ=//p' \"$u\")\"; "
        + "break; done; true"

    Plasmoid.icon: cfg.iconName
    // The panel removes HiddenStatus widgets entirely (except in edit mode).
    // Plasma overwrites the status while the popup or context menu is open and
    // restores a stale value afterwards, so it is re-applied after every probe.
    function updateStatus() {
        Plasmoid.status = connected ? PlasmaCore.Types.ActiveStatus
            : cfg.hideWhenDisconnected ? PlasmaCore.Types.HiddenStatus : PlasmaCore.Types.PassiveStatus;
    }
    onConnectedChanged: updateStatus()
    Component.onCompleted: updateStatus()

    Connections {
        target: Plasmoid.configuration
        function onHideWhenDisconnectedChanged() { root.updateStatus(); }
    }
    preferredRepresentation: compactRepresentation

    // the hover overlay replaces the tooltip
    toolTipMainText: ""
    toolTipSubText: ""

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            const parts = (data["stdout"] || "").trim().split("|");
            const n = parseInt(parts[0]);
            root.level = isNaN(n) ? -1 : n;
            root.status = parts[1] || "";
            root.hidId = parts[2] || "";
            root.hidName = parts[3] || "";
            root.address = parts[4] || "";
            root.updateStatus();
            disconnectSource(source);
        }
    }

    // one-off shell commands (bluetoothctl)
    P5Support.DataSource {
        id: command
        engine: "executable"
        onNewData: (source, data) => {
            disconnectSource(source);
            settle.restart();
        }
    }

    Timer {
        id: settle
        interval: 1500
        onTriggered: {
            root.disconnecting = false;
            root.refresh();
        }
    }

    function disconnectController() {
        if (!canDisconnect || disconnecting)
            return;
        disconnecting = true;
        expanded = false;
        command.connectSource("bluetoothctl disconnect " + address.toUpperCase());
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Disconnect Controller"
            icon.name: "network-disconnect"
            visible: root.canDisconnect
            onTriggered: root.disconnectController()
        },
        PlasmaCore.Action {
            text: "Show Details"
            icon.name: "documentinfo"
            visible: root.cfg.clickAction === 1
            onTriggered: root.expanded = true
        }
    ]

    Timer {
        interval: Math.max(2, root.cfg.refreshSeconds) * 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.probe)
    }

    function refresh() {
        exec.connectSource(probe);
    }

    onExpandedChanged: if (root.expanded) root.refresh(); else root.updateStatus()

    compactRepresentation: MouseArea {
        id: compact

        // "always show percentage" swaps the icon for the controller badge
        readonly property bool badgeMode: root.cfg.showPercentAlways
        readonly property real badgeAspect: root.cfg.badgeStyle === 0 ? 1.35 : 1.2
        readonly property bool overlay: root.connected && containsMouse && !badgeMode

        Layout.minimumWidth: badgeMode ? Math.round(height * badgeAspect) : height
        Layout.preferredWidth: Layout.minimumWidth
        Layout.maximumWidth: Layout.minimumWidth
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) root.refresh();
            else if (root.cfg.clickAction === 1 && root.canDisconnect) root.disconnectController();
            else root.expanded = !root.expanded;
        }

        Kirigami.Icon {
            id: icon
            visible: !compact.badgeMode
            anchors.centerIn: parent
            width: Math.min(parent.width, parent.height, Kirigami.Units.iconSizes.medium)
            height: width
            source: root.cfg.iconName
            isMask: root.cfg.monochrome
            color: root.low ? root.cfg.lowColor : Kirigami.Theme.textColor
            opacity: compact.overlay ? 0.18 : root.connected ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }

        PlasmaComponents3.Label {
            anchors.fill: icon
            anchors.margins: -Kirigami.Units.smallSpacing
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            visible: !compact.badgeMode
            text: root.level + "%"
            font.bold: true
            font.pixelSize: icon.height * 0.6
            fontSizeMode: Text.Fit
            minimumPixelSize: 6
            color: root.low ? root.cfg.lowColor : Kirigami.Theme.textColor
            opacity: compact.overlay ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.shortDuration } }
        }

        ControllerBadge {
            visible: compact.badgeMode
            anchors.centerIn: parent
            variant: root.cfg.badgeStyle
            height: Math.round(parent.height * (variant === 0 ? 0.72 : 0.8))
            width: Math.round(height * unitW / unitH)
            level: root.level
            charging: root.charging
            color: root.low ? root.cfg.lowColor : Kirigami.Theme.textColor
            opacity: root.connected && !root.disconnecting ? 1 : 0.4
            Behavior on opacity { NumberAnimation { duration: Kirigami.Units.longDuration } }
        }

        // small dot while charging
        Rectangle {
            visible: root.charging && !compact.badgeMode
            width: Math.max(4, icon.width * 0.22)
            height: width
            radius: width / 2
            color: Kirigami.Theme.positiveTextColor
            anchors.right: icon.right
            anchors.bottom: icon.bottom
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 19
        Layout.preferredHeight: Kirigami.Units.gridUnit * 21

        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            RowLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: root.cfg.iconName
                    isMask: root.cfg.monochrome
                    color: Kirigami.Theme.textColor
                    Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                    Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                }
                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    level: 3
                    text: root.connected ? root.deviceName : "Controller Battery"
                    elide: Text.ElideRight
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: root.refresh()
                    PlasmaComponents3.ToolTip.text: "Refresh"
                    PlasmaComponents3.ToolTip.visible: hovered
                }
                PlasmaComponents3.ToolButton {
                    icon.name: "configure"
                    onClicked: Plasmoid.internalAction("configure").trigger()
                    PlasmaComponents3.ToolTip.text: "Configure…"
                    PlasmaComponents3.ToolTip.visible: hovered
                }
            }
        }

        contentItem: Item {
            PlasmaExtras.PlaceholderMessage {
                anchors.centerIn: parent
                width: parent.width - Kirigami.Units.gridUnit * 2
                visible: !root.connected
                iconName: root.cfg.iconName
                text: "No controller connected"
                explanation: "Turn on your controller or plug it in with a USB cable."
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Kirigami.Units.largeSpacing
                visible: root.connected
                spacing: Kirigami.Units.largeSpacing

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Kirigami.Units.gridUnit * 8

                    BatteryChart {
                        id: chart
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height, Kirigami.Units.gridUnit * 11)
                        height: width
                        value: root.level
                        style: root.cfg.chartStyle
                        color: root.chartColor
                        trackColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                    }

                    // percentage in the middle of the ring
                    ColumnLayout {
                        anchors.centerIn: chart
                        visible: root.cfg.chartStyle === 1
                        spacing: 0
                        PlasmaExtras.Heading {
                            Layout.alignment: Qt.AlignHCenter
                            level: 1
                            text: root.level + "%"
                        }
                        PlasmaComponents3.Label {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.statusText
                            opacity: 0.7
                        }
                    }
                }

                // percentage under the pie
                ColumnLayout {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.cfg.chartStyle === 0
                    spacing: 0
                    PlasmaExtras.Heading {
                        Layout.alignment: Qt.AlignHCenter
                        level: 1
                        text: root.level + "%"
                    }
                    PlasmaComponents3.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: root.statusText
                        opacity: 0.7
                    }
                }

                Kirigami.Separator { Layout.fillWidth: true }

                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Kirigami.Units.largeSpacing
                    rowSpacing: Kirigami.Units.smallSpacing

                    PlasmaComponents3.Label { text: "Connection"; opacity: 0.7 }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.connectionName
                    }
                    PlasmaComponents3.Label { text: "Address"; opacity: 0.7 }
                    PlasmaComponents3.Label {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.address.toUpperCase()
                        font.family: "monospace"
                        elide: Text.ElideLeft
                    }
                }

                PlasmaComponents3.Button {
                    Layout.alignment: Qt.AlignHCenter
                    visible: root.canDisconnect
                    enabled: !root.disconnecting
                    icon.name: "network-disconnect"
                    text: root.disconnecting ? "Disconnecting…" : "Disconnect"
                    onClicked: root.disconnectController()
                }
            }
        }
    }
}
