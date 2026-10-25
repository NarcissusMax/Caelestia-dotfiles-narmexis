import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

ColumnLayout {
    id: row
    required property string controlKey
    required property string monitor
    property var spec: DisplayService.state.controls ? DisplayService.state.controls[controlKey] : [0, 100, 0, 1, controlKey, ""]
    property real currentValue: Number(DisplayService.entry(monitor).values[controlKey] ?? spec[2])
    readonly property int decimals: spec[3] < 1 ? 2 : 0
    readonly property real buttonStep: {
        let amount = spec[5] === "%" ? 5 : (spec[1] - spec[0]) * 0.05;
        return Number(Math.max(spec[3], Math.round(amount / spec[3]) * spec[3]).toFixed(decimals));
    }

    function adjust(direction) {
        if (!DisplayService.ready || !monitor) return;
        let next = Number(Math.max(spec[0], Math.min(spec[1], currentValue + direction * buttonStep)).toFixed(decimals));
        if (next === currentValue) return;
        DisplayService.setValue(monitor, controlKey, next);
        DisplayService.flush();
    }

    function resetToDefault() {
        if (!DisplayService.ready || !monitor || currentValue === Number(spec[2])) return;
        DisplayService.setValue(monitor, controlKey, Number(spec[2]));
        DisplayService.flush();
    }
    onCurrentValueChanged: if (!slider.isDragging) slider.value = currentValue
    spacing: 4
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    Layout.preferredHeight: 66

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            Layout.fillWidth: true
            text: row.spec[4]
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: ThemeBackend.text
            elide: Text.ElideRight
        }
        ClickButton {
            Layout.preferredWidth: 34
            implicitHeight: 22
            horizontalPadding: 4
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: 9
            buttonText: "−5%"
            enabled: DisplayService.ready && !!row.monitor && row.currentValue > row.spec[0]
            opacity: enabled ? 1 : 0.35
            Accessible.role: Accessible.Button
            Accessible.name: "Decrease " + row.spec[4] + " by five percent"
            Accessible.description: "Subtract " + row.buttonStep + row.spec[5]
            Accessible.onPressAction: row.adjust(-1)
            onClicked: row.adjust(-1)
        }
        Text {
            Layout.preferredWidth: 56
            text: row.currentValue.toFixed(row.decimals) + row.spec[5]
            horizontalAlignment: Text.AlignHCenter
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 11
            font.weight: Font.Bold
            color: ThemeBackend.mauve
        }
        ClickButton {
            Layout.preferredWidth: 34
            implicitHeight: 22
            horizontalPadding: 4
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: 9
            buttonText: "+5%"
            enabled: DisplayService.ready && !!row.monitor && row.currentValue < row.spec[1]
            opacity: enabled ? 1 : 0.35
            Accessible.role: Accessible.Button
            Accessible.name: "Increase " + row.spec[4] + " by five percent"
            Accessible.description: "Add " + row.buttonStep + row.spec[5]
            Accessible.onPressAction: row.adjust(1)
            onClicked: row.adjust(1)
        }
    }
    SliderProgress {
        id: slider
        Layout.fillWidth: true
        Layout.preferredHeight: 16
        from: row.spec[0]
        to: row.spec[1]
        value: row.currentValue
        keyStep: row.spec[3]
        backgroundColor: Qt.alpha(ThemeBackend.surface1, ThemeBackend.elementOpacity)
        gradColor1: ThemeBackend.mauve
        glowOpacity: 0.12
        Accessible.role: Accessible.Slider
        Accessible.name: row.spec[4]
        Accessible.description: "Range " + row.spec[0] + " to " + row.spec[1] + "; default " + row.spec[2]
        onMoved: val => {
            let step = row.spec[3];
            DisplayService.setValue(row.monitor, row.controlKey, Math.round(val / step) * step);
        }
        onDragFinished: { slider.value = row.currentValue; DisplayService.flush(); }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            color: "transparent"
            radius: parent.cornerRadius + 3
            border.color: ThemeBackend.mauve
            visible: slider.activeFocus
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: row.spec[0] + row.spec[5]
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 8
            color: ThemeBackend.subtext0
        }
        Item { Layout.fillWidth: true }
        ClickButton {
            implicitHeight: 20
            horizontalPadding: 7
            cornerRadius: ThemeBackend.borderRadius
            textFontSize: 8
            buttonIcon: "󰑓"
            iconFontSize: 10
            buttonText: "Default " + row.spec[2] + row.spec[5]
            textColor: enabled ? ThemeBackend.mauve : ThemeBackend.subtext0
            enabled: DisplayService.ready && !!row.monitor && row.currentValue !== Number(row.spec[2])
            opacity: enabled ? 1 : 0.55
            Accessible.role: Accessible.Button
            Accessible.name: "Reset " + row.spec[4] + " to default"
            Accessible.description: "Restore only " + row.spec[4] + " to " + row.spec[2] + row.spec[5]
            Accessible.onPressAction: row.resetToDefault()
            onClicked: row.resetToDefault()
        }
        Item { Layout.fillWidth: true }
        Text {
            text: row.spec[1] + row.spec[5]
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 8
            color: ThemeBackend.subtext0
        }
    }
}
