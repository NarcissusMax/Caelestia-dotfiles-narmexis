pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
    id: root

    readonly property MprisPlayer player: Players.active
    readonly property real minimum: Math.max(0.25, player?.minRate ?? 1)
    readonly property real maximum: Math.min(4, player?.maxRate ?? 1)
    readonly property bool available: player !== null && maximum > minimum
    readonly property var presets: [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2, 2.5, 3, 4]
    property bool presetsExpanded: false

    function rateText(rate: real): string {
        return `${Number(rate.toFixed(2))}×`;
    }

    function setRate(rate: real): void {
        if (!available)
            return;
        player.rate = Math.round(Math.max(minimum, Math.min(maximum, rate)) * 100) / 100;
    }

    function stepRate(direction: int): void {
        if (available)
            setRate((Math.round(player.rate * 100) + direction * 10) / 100);
    }

    spacing: Tokens.spacing.extraSmall

    RowLayout {
        Layout.fillWidth: true

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Playback speed")
            font: Tokens.font.body.small
            color: Colours.palette.m3onSurfaceVariant
        }

        TextButton {
            id: presetButton

            text: root.available ? root.rateText(root.player.rate) + (root.presetsExpanded ? " ▴" : " ▾") : qsTr("Unavailable")
            disabled: !root.available
            type: TextButton.Tonal
            verticalPadding: Tokens.padding.extraSmall
            onClicked: root.presetsExpanded = !root.presetsExpanded
        }
    }

    StyledSlider {
        Layout.fillWidth: true
        from: 0.25
        to: 4
        stepSize: 0.01
        value: root.player?.rate ?? 1
        enabled: root.available
        onInteraction: position => root.setRate(0.25 + position * 3.75)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        TextButton {
            Layout.fillWidth: true
            text: "−0.1×"
            type: TextButton.Tonal
            verticalPadding: Tokens.padding.extraSmall
            disabled: !root.available || root.player.rate <= root.minimum + 0.001
            onClicked: root.stepRate(-1)
        }

        TextButton {
            Layout.fillWidth: true
            text: "+0.1×"
            type: TextButton.Tonal
            verticalPadding: Tokens.padding.extraSmall
            disabled: !root.available || root.player.rate >= root.maximum - 0.001
            onClicked: root.stepRate(1)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        visible: root.presetsExpanded
        columns: 4
        columnSpacing: Tokens.spacing.extraSmall
        rowSpacing: Tokens.spacing.extraSmall

        Repeater {
            model: root.presets

            TextButton {
                required property real modelData

                Layout.fillWidth: true
                text: root.rateText(modelData)
                type: TextButton.Tonal
                checked: Math.abs((root.player?.rate ?? 0) - modelData) < 0.001
                isToggle: true
                verticalPadding: Tokens.padding.extraSmall
                disabled: !root.available || modelData < root.minimum || modelData > root.maximum
                onClicked: {
                    root.setRate(modelData);
                    root.presetsExpanded = false;
                }
            }
        }
    }
}
