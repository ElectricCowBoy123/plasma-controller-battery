import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.iconthemes as KIconThemes

KCM.SimpleKCM {
    id: page

    property string cfg_iconName
    property alias cfg_monochrome: monochrome.checked
    property alias cfg_showPercentAlways: showAlways.checked
    property alias cfg_hideWhenDisconnected: hideDisconnected.checked
    property int cfg_chartStyle
    property int cfg_badgeStyle
    property int cfg_clickAction
    property alias cfg_useAccentColor: useAccent.checked
    property alias cfg_chartColor: chartColor.color
    property alias cfg_lowColor: lowColor.color
    property alias cfg_lowThreshold: lowThreshold.value
    property alias cfg_refreshSeconds: refreshSeconds.value

    // filled in by Plasma's config dialog
    property var cfg_iconNameDefault
    property var cfg_monochromeDefault
    property var cfg_showPercentAlwaysDefault
    property var cfg_hideWhenDisconnectedDefault
    property var cfg_chartStyleDefault
    property var cfg_useAccentColorDefault
    property var cfg_chartColorDefault
    property var cfg_lowColorDefault
    property var cfg_lowThresholdDefault
    property var cfg_refreshSecondsDefault
    property var cfg_badgeStyleDefault
    property var cfg_clickActionDefault

    readonly property var presetIcons: [
        "input-gamepad-symbolic",
        "input-gaming-symbolic",
        "applications-games-symbolic",
        "joystick",
        "battery-good-symbolic",
    ]

    readonly property KIconThemes.IconDialog iconDialog: KIconThemes.IconDialog {
        onIconNameChanged: iconName => {
            if (iconName) page.cfg_iconName = iconName;
        }
    }

    Kirigami.FormLayout {
        RowLayout {
            Kirigami.FormData.label: "Icon:"
            spacing: Kirigami.Units.smallSpacing

            Repeater {
                model: page.presetIcons
                QQC2.ToolButton {
                    required property string modelData
                    checkable: true
                    checked: page.cfg_iconName === modelData
                    onClicked: page.cfg_iconName = modelData
                    implicitWidth: Kirigami.Units.iconSizes.medium + Kirigami.Units.largeSpacing * 2
                    implicitHeight: implicitWidth
                    contentItem: Kirigami.Icon {
                        source: modelData
                        isMask: monochrome.checked
                        color: Kirigami.Theme.textColor
                    }
                    QQC2.ToolTip.text: modelData
                    QQC2.ToolTip.visible: hovered
                }
            }

            QQC2.Button {
                text: "Other…"
                icon.name: page.presetIcons.includes(page.cfg_iconName) ? "document-open" : page.cfg_iconName
                onClicked: page.iconDialog.open()
            }
        }

        QQC2.CheckBox {
            id: monochrome
            text: "Monochrome icon"
        }
        QQC2.CheckBox {
            id: showAlways
            text: "Always show percentage (replaces the icon with a controller badge)"
        }
        QQC2.ComboBox {
            id: badgeStyle
            Kirigami.FormData.label: "Badge style:"
            enabled: showAlways.checked
            model: ["Classic", "Bold", "Gauge (fills with charge)"]
            currentIndex: page.cfg_badgeStyle
            onActivated: index => page.cfg_badgeStyle = index
        }

        RowLayout {
            Kirigami.FormData.label: "Badge preview:"
            enabled: showAlways.checked
            spacing: Kirigami.Units.largeSpacing
            Repeater {
                model: [85, 40, Math.max(lowThreshold.value, 5)]
                Rectangle {
                    required property int modelData
                    implicitWidth: Kirigami.Units.gridUnit * 4
                    implicitHeight: Kirigami.Units.gridUnit * 2.5
                    radius: Kirigami.Units.cornerRadius
                    color: Qt.rgba(0, 0, 0, 0.25)
                    ControllerBadge {
                        anchors.centerIn: parent
                        variant: page.cfg_badgeStyle
                        height: Math.round(parent.height * 0.75)
                        width: Math.round(height * unitW / unitH)
                        level: modelData
                        charging: modelData === 85
                        color: modelData <= lowThreshold.value ? lowColor.color : Kirigami.Theme.textColor
                    }
                }
            }
        }

        QQC2.CheckBox {
            id: hideDisconnected
            text: "Hide from panel when no controller is connected"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.RadioButton {
            Kirigami.FormData.label: "Clicking the icon:"
            text: "Shows battery details"
            checked: page.cfg_clickAction === 0
            onToggled: if (checked) page.cfg_clickAction = 0
        }
        QQC2.RadioButton {
            text: "Disconnects the controller (Bluetooth)"
            checked: page.cfg_clickAction === 1
            onToggled: if (checked) page.cfg_clickAction = 1
        }
        QQC2.Label {
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.Wrap
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            text: page.cfg_clickAction === 1
                ? "Right-click → Show Details opens the battery popup."
                : "Right-click → Disconnect Controller is always available."
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: "Chart style:"
            QQC2.RadioButton {
                text: "Pie"
                checked: page.cfg_chartStyle === 0
                onToggled: if (checked) page.cfg_chartStyle = 0
            }
            QQC2.RadioButton {
                text: "Ring"
                checked: page.cfg_chartStyle === 1
                onToggled: if (checked) page.cfg_chartStyle = 1
            }
        }

        QQC2.CheckBox {
            id: useAccent
            Kirigami.FormData.label: "Chart color:"
            text: "Use system accent color"
        }
        KQuickControls.ColorButton {
            id: chartColor
            enabled: !useAccent.checked
            showAlphaChannel: false
            dialogTitle: "Chart color"
        }

        RowLayout {
            Kirigami.FormData.label: "Low battery:"
            QQC2.SpinBox {
                id: lowThreshold
                from: 0
                to: 100
                stepSize: 5
                textFromValue: (value) => value + "%"
                valueFromText: (text) => parseInt(text)
            }
            KQuickControls.ColorButton {
                id: lowColor
                showAlphaChannel: false
                dialogTitle: "Low battery color"
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Preview:"
            spacing: Kirigami.Units.largeSpacing
            BatteryChart {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: Layout.preferredWidth
                value: 65
                style: page.cfg_chartStyle
                color: useAccent.checked ? Kirigami.Theme.highlightColor : chartColor.color
                trackColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            }
            BatteryChart {
                Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                Layout.preferredHeight: Layout.preferredWidth
                value: Math.max(lowThreshold.value, 5)
                style: page.cfg_chartStyle
                color: lowColor.color
                trackColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
            }
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: refreshSeconds
            Kirigami.FormData.label: "Check every:"
            from: 2
            to: 600
            textFromValue: (value) => value + " s"
            valueFromText: (text) => parseInt(text)
        }
    }
}
