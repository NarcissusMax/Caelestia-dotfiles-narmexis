pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property Brightness.Monitor monitor
    required property ScreenState screenState

    required property real volume
    required property bool muted
    required property real sourceVolume
    required property bool sourceMuted
    required property real brightness

    property bool advancedExpanded: false

    implicitWidth: layout.implicitWidth + Tokens.padding.large + layout.anchors.horizontalCenterOffset * 2
    implicitHeight: layout.implicitHeight + Tokens.padding.large * 2

    ColumnLayout {
        id: layout

        anchors.centerIn: parent
        anchors.horizontalCenterOffset: CUtils.clamp(Tokens.padding.large - Config.border.thickness, 0, Tokens.padding.large) / 2
        spacing: Tokens.spacing.medium

        // Speaker volume
        CustomMouseArea {
            function onWheel(event: WheelEvent) {
                if (event.angleDelta.y > 0)
                    Audio.incrementVolume();
                else if (event.angleDelta.y < 0)
                    Audio.decrementVolume();
            }

            implicitWidth: Tokens.sizes.osd.sliderWidth
            implicitHeight: Tokens.sizes.osd.sliderHeight

            FilledSlider {
                anchors.fill: parent

                icon: Icons.getVolumeIcon(value, root.muted)
                value: root.volume
                to: GlobalConfig.services.maxVolume
                onMoved: Audio.setVolume(value)
            }
        }

        // Microphone volume
        WrappedLoader {
            shouldBeActive: Config.osd.enableMicrophone && (!Config.osd.enableBrightness || !root.screenState.session)

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    if (event.angleDelta.y > 0)
                        Audio.incrementSourceVolume();
                    else if (event.angleDelta.y < 0)
                        Audio.decrementSourceVolume();
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    anchors.fill: parent

                    icon: Icons.getMicVolumeIcon(value, root.sourceMuted)
                    value: root.sourceVolume
                    to: GlobalConfig.services.maxVolume
                    onMoved: Audio.setSourceVolume(value)
                }
            }
        }

        // Brightness
        WrappedLoader {
            shouldBeActive: Config.osd.enableBrightness

            sourceComponent: CustomMouseArea {
                function onWheel(event: WheelEvent) {
                    const monitor = root.monitor;
                    if (!monitor)
                        return;
                    if (event.angleDelta.y > 0)
                        monitor.setBrightness(monitor.brightness + GlobalConfig.services.brightnessIncrement);
                    else if (event.angleDelta.y < 0)
                        monitor.setBrightness(monitor.brightness - GlobalConfig.services.brightnessIncrement);
                }

                implicitWidth: Tokens.sizes.osd.sliderWidth
                implicitHeight: Tokens.sizes.osd.sliderHeight

                FilledSlider {
                    anchors.fill: parent

                    icon: `brightness_${(Math.round(value * 6) + 1)}`
                    value: root.brightness
                    onMoved: root.monitor?.setBrightness(value)
                }
            }
        }

        // Display adjustments
        DisplayPresets {
            onEditRequested: root.advancedExpanded = true
        }

        TextButton {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small
            text: qsTr(root.advancedExpanded ? "Hide adjustments" : "Adjustments…")

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

    component WrappedLoader: Loader {
        required property bool shouldBeActive

        asynchronous: true
        Layout.preferredHeight: shouldBeActive ? Tokens.sizes.osd.sliderHeight : 0
        opacity: shouldBeActive ? 1 : 0
        active: opacity > 0
        visible: active

        Behavior on Layout.preferredHeight {
            Anim {
                type: Anim.Emphasized
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }
    }
}
