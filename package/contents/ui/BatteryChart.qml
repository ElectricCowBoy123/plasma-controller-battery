import QtQuick
import QtQuick.Shapes

// Pie (style 0) or ring (style 1) showing a 0–100 value
Item {
    id: chart

    property real value: 0
    property color color: "#3daee9"
    property color trackColor: Qt.rgba(0.5, 0.5, 0.5, 0.2)
    property int style: 0
    property real thickness: Math.max(3, radius * 0.22)

    readonly property real radius: Math.min(width, height) / 2
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real ringRadius: radius - thickness / 2

    property real shown: value
    Behavior on shown { NumberAnimation { duration: 700; easing.type: Easing.OutCubic } }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // pie: full background disc
        ShapePath {
            strokeColor: "transparent"
            fillColor: chart.style === 0 ? chart.trackColor : "transparent"
            PathAngleArc {
                centerX: chart.cx; centerY: chart.cy
                radiusX: chart.radius; radiusY: chart.radius
                startAngle: 0; sweepAngle: 360
            }
        }
        // pie: filled slice from 12 o'clock
        ShapePath {
            strokeColor: "transparent"
            fillColor: chart.style === 0 && chart.shown > 0 ? chart.color : "transparent"
            startX: chart.cx; startY: chart.cy
            PathAngleArc {
                moveToStart: false
                centerX: chart.cx; centerY: chart.cy
                radiusX: chart.radius; radiusY: chart.radius
                startAngle: -90; sweepAngle: 360 * Math.min(chart.shown, 100) / 100
            }
        }
        // ring: track
        ShapePath {
            fillColor: "transparent"
            strokeColor: chart.style === 1 ? chart.trackColor : "transparent"
            strokeWidth: chart.thickness
            capStyle: ShapePath.FlatCap
            PathAngleArc {
                centerX: chart.cx; centerY: chart.cy
                radiusX: chart.ringRadius; radiusY: chart.ringRadius
                startAngle: 0; sweepAngle: 360
            }
        }
        // ring: value arc
        ShapePath {
            fillColor: "transparent"
            strokeColor: chart.style === 1 && chart.shown > 0 ? chart.color : "transparent"
            strokeWidth: chart.thickness
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: chart.cx; centerY: chart.cy
                radiusX: chart.ringRadius; radiusY: chart.ringRadius
                startAngle: -90; sweepAngle: 360 * Math.min(chart.shown, 100) / 100
            }
        }
    }
}
