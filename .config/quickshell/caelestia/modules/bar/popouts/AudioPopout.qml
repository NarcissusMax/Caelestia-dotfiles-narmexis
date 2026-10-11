pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services

Item {
    id: root

    required property PopoutState popouts

    property bool advancedExpanded: false

    implicitWidth: layout.implicitWidth + Tokens.padding.medium * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.medium * 2

    ButtonGroup {
        id: sinks
    }

    ButtonGroup {
        id: sources
    }

    ColumnLayout {
        id: layout

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.spacing.medium

        StyledText {
            text: qsTr("Output device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sinks

            StyledRadioButton {
                id: control

                required property PwNode modelData

                ButtonGroup.group: sinks
                checked: Audio.sink?.id === modelData.id
                onClicked: Audio.setAudioSink(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Input device")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        Repeater {
            model: Audio.sources

            StyledRadioButton {
                required property PwNode modelData

                ButtonGroup.group: sources
                checked: Audio.source?.id === modelData.id
                onClicked: Audio.setAudioSource(modelData)
                text: modelData.description
            }
        }

        StyledText {
            Layout.topMargin: Tokens.spacing.medium
            text: qsTr("Volume (%1)").arg(Audio.muted ? qsTr("Muted") : `${Math.round(Audio.volume * 100)}%`)
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 3

            onWheel: event => {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: parent.implicitHeight

                value: Audio.volume
                onInteraction: value => Audio.setVolume(value)
            }
        }

        DisplayPresets {
            onEditRequested: root.advancedExpanded = true
        }

        TextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            text: qsTr(advancedExpanded ? "Hide adjustments" : "Adjustments…")

            onClicked: root.advancedExpanded = !root.advancedExpanded
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            visible: root.advancedExpanded
            spacing: Tokens.spacing.medium

            DisplaySlider {
                labelText: qsTr("Brightness")
                from: 0.0
                to: 2.0
                stepSize: 0.01
                val: Display.brightnessValue
                format: v => `${Math.round(v * 100)}%`
                onChanged: v => Display.setBrightness(v)
            }

            DisplaySlider {
                labelText: qsTr("Contrast")
                from: 0.0
                to: 2.0
                stepSize: 0.01
                val: Display.contrastValue
                format: v => `${Math.round(v * 100)}%`
                onChanged: v => Display.setContrast(v)
            }

            DisplaySlider {
                labelText: qsTr("Saturation")
                from: 0.0
                to: 1.5
                stepSize: 0.01
                val: Display.saturationValue
                format: v => `${Math.round(v * 100)}%`
                onChanged: v => Display.setSaturation(v)
            }

            DisplaySlider {
                labelText: qsTr("Gamma")
                from: 0.5
                to: 2.5
                stepSize: 0.01
                val: Display.gammaValue
                format: v => v.toFixed(2)
                onChanged: v => Display.setGamma(v)
            }

            DisplaySlider {
                labelText: qsTr("Temperature")
                from: 1500
                to: 10000
                stepSize: 50
                val: Display.temperatureValue
                format: v => `${Math.round(v)}K`
                onChanged: v => Display.setTemperature(v)
            }
        }

        IconTextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            inactiveColour: Colours.palette.m3primaryContainer
            inactiveOnColour: Colours.palette.m3onPrimaryContainer
            verticalPadding: Tokens.padding.extraSmall
            text: qsTr("Open settings")
            icon: "settings"

            onClicked: root.popouts.detachRequested("audio")
        }
    }

    component DisplaySlider: ColumnLayout {
        id: ds

        required property string labelText
        required property real from
        required property real to
        required property real stepSize
        required property real val
        required property var format
        required property var onChanged

        Layout.fillWidth: true
        spacing: Tokens.spacing.extraSmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            StyledText {
                Layout.fillWidth: true
                text: ds.labelText
                font: Tokens.font.body.small
            }

            StyledText {
                text: ds.format(ds.val)
                color: Colours.palette.m3outline
                font: Tokens.font.body.small
            }
        }

        CustomMouseArea {
            Layout.fillWidth: true
            implicitHeight: Tokens.padding.medium * 2

            StyledSlider {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitHeight: parent.implicitHeight

                from: ds.from
                to: ds.to
                stepSize: ds.stepSize
                value: ds.val
                onInteraction: v => ds.onChanged(ds.from + v * (ds.to - ds.from))
            }
        }
    }
}
