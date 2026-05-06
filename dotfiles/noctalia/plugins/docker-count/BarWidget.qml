import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
    id: root

    property var pluginApi: null
    property ShellScreen screen
    property string widgetId: ""
    property string section: ""
    property int sectionWidgetIndex: -1
    property int sectionWidgetsCount: 0
    property real baseSize: Style.capsuleHeight
    property bool applyUiScale: false
    property bool dockerRunning: false
    property int runningCount: 0

    readonly property real baseDimension: applyUiScale ? Math.round(baseSize * Style.uiScaleRatio) : Math.round(baseSize)

    visible: dockerRunning
    implicitWidth: visible ? Math.max(baseDimension, contentRow.implicitWidth + Style.marginM * 2) : 0
    implicitHeight: visible ? baseDimension : 0

    Component.onCompleted: dockerCountProcess.running = true

    Process {
        id: dockerCountProcess
        command: ["docker", "ps", "-q"]
        stdout: StdioCollector {
            onStreamFinished: {
                var output = this.text.trim();
                root.runningCount = output === "" ? 0 : output.split('\n').length;
            }
        }
        onExited: (code, status) => {
            root.dockerRunning = (code === 0);
        }
    }

    Timer {
        interval: (pluginApi && pluginApi.pluginSettings && pluginApi.pluginSettings.refreshInterval) || 5000
        running: true
        repeat: true
        onTriggered: dockerCountProcess.running = true
    }

    Rectangle {
        id: visualCapsule
        anchors.fill: parent
        color: Color.mSurfaceVariant
        radius: Math.min(Style.radiusL, height / 2)

        RowLayout {
            id: contentRow
            anchors.centerIn: parent
            spacing: Style.marginXS

            NIcon {
                icon: "brand-docker"
                color: Color.mPrimary
            }

            NText {
                text: root.runningCount
                pointSize: Style.fontSizeS
                font.weight: Style.fontWeightBold
                color: Color.mPrimary
                Layout.rightMargin: Style.marginXS
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            Quickshell.execDetached(["kitty", "--app-id=kitty-lazydocker", "-e", "lazydocker"]);
        }
    }
}
