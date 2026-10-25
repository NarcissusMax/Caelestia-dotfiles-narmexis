import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

ColumnLayout {
    id: speedRoot

    property var player: null
    readonly property real minimum: player ? Math.max(0.25, player.minRate) : 0.25
    readonly property real maximum: player ? Math.min(4, player.maxRate) : 4
    readonly property bool available: !!player && player.canControl
        && Number.isFinite(minimum) && Number.isFinite(maximum) && maximum > minimum
    readonly property real currentRate: player ? player.rate : 1
    readonly property var presets: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]
    readonly property var supportedPresets: presets.filter(rate => rate >= minimum && rate <= maximum)

    function s(value) { return Scaler.s(value); }
    function rateText(value) { return Number(Number(value).toFixed(2)) + "×"; }
    function setRate(value) {
        if (!available || !Number.isFinite(value)) return;
        const rounded = Math.round(value * 100) / 100;
        player.rate = Math.max(minimum, Math.min(maximum, rounded));
    }
    function stepRate(direction) {
        setRate((Math.round(currentRate * 100) + direction * 10) / 100);
    }

    spacing: s(8)

    RowLayout {
        Layout.fillWidth: true
        spacing: speedRoot.s(8)

        Text {
            Layout.fillWidth: true
            text: qsTr("Playback speed")
            color: ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: speedRoot.s(12)
            font.bold: true
        }

        ClickButton {
            objectName: "decreasePlaybackSpeed"
            Layout.preferredWidth: speedRoot.s(65)
            Layout.preferredHeight: speedRoot.s(28)
            buttonText: "−0.1×"
            textFontSize: speedRoot.s(11)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            enabled: speedRoot.available && speedRoot.currentRate > speedRoot.minimum + 0.001
            action_highlight: activeFocus
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Decrease playback speed")
            Accessible.onPressAction: speedRoot.stepRate(-1)
            onClicked: speedRoot.stepRate(-1)
        }

        Dropdown {
            id: presetPicker
            objectName: "playbackSpeedPresets"
            Layout.preferredWidth: speedRoot.s(125)
            Layout.preferredHeight: speedRoot.s(28)
            options: speedRoot.available ? speedRoot.supportedPresets.map(rate => speedRoot.rateText(rate)) : []
            placeholderText: speedRoot.available ? speedRoot.rateText(speedRoot.currentRate) : qsTr("Unavailable")
            enabled: speedRoot.available
            fuzzySearch: false
            fontPixelSize: speedRoot.s(11)
            cornerRadius: ThemeBackend.borderRadius
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            dropdownColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            Accessible.name: qsTr("Playback speed presets")
            onValueChanged: (index, value) => speedRoot.setRate(speedRoot.supportedPresets[index])

            Binding {
                target: presetPicker
                property: "currentIndex"
                value: speedRoot.supportedPresets.findIndex(rate => Math.abs(rate - speedRoot.currentRate) < 0.001)
            }

            Connections {
                target: speedRoot
                function onPlayerChanged() { presetPicker.closePopup(); }
            }
        }

        ClickButton {
            objectName: "increasePlaybackSpeed"
            Layout.preferredWidth: speedRoot.s(65)
            Layout.preferredHeight: speedRoot.s(28)
            buttonText: "+0.1×"
            textFontSize: speedRoot.s(11)
            accentColor: ThemeBackend.surface0
            textColor: ThemeBackend.text
            enabled: speedRoot.available && speedRoot.currentRate < speedRoot.maximum - 0.001
            action_highlight: activeFocus
            Accessible.role: Accessible.Button
            Accessible.name: qsTr("Increase playback speed")
            Accessible.onPressAction: speedRoot.stepRate(1)
            onClicked: speedRoot.stepRate(1)
        }
    }

    Draggable {
        objectName: "playbackSpeedSlider"
        Layout.fillWidth: true
        Layout.preferredHeight: speedRoot.s(14)
        from: speedRoot.minimum
        to: speedRoot.maximum
        value: speedRoot.currentRate
        stepSize: 0.01
        defaultValue: 1
        enabled: speedRoot.available
        activeFocusOnTab: enabled
        action_highlight: activeFocus
        alwaysShowHandle: true
        handleSize: speedRoot.s(14)
        accentColor: ThemeBackend.mauve
        backgroundColor: ThemeBackend.surface1
        valueFormatter: value => speedRoot.rateText(value)
        Accessible.role: Accessible.Slider
        Accessible.name: qsTr("Playback speed")
        onMoved: value => speedRoot.setRate(value)
    }
}
