pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: view
    property bool panelActive: false
    property string selectedMonitor: ""
    property bool advanced: false
    property string editMode: ""
    readonly property var entry: DisplayService.entry(selectedMonitor)
    readonly property bool customProfile: (DisplayService.state.customProfiles || []).indexOf(entry.profile) >= 0

    function syncToggles() {
        if (enableToggle) enableToggle.checked = entry.enabled;
        if (grayscaleToggle) grayscaleToggle.checked = entry.values.grayscale === true;
        if (invertToggle) invertToggle.checked = entry.values.invert === true;
    }
    onEntryChanged: syncToggles()

    function chooseMonitor() {
        let monitors = DisplayService.monitors;
        if (!monitors.length) { selectedMonitor = ""; return; }
        if (monitors.some(m => m.name === selectedMonitor)) return;
        selectedMonitor = (monitors.find(m => m.focused) || monitors[0]).name;
    }
    function commitProfile() {
        if (!profileName.text.trim()) return;
        DisplayService.action(editMode, selectedMonitor, {profile: editMode === "rename" ? entry.profile : "", name: profileName.text.trim()});
        editMode = "";
    }
    onPanelActiveChanged: {
        if (panelActive) { DisplayService.send({op: "refresh"}); chooseMonitor(); }
        else DisplayService.flush();
    }
    Connections {
        target: DisplayService
        function onMonitorsChanged() { view.chooseMonitor(); }
        function onStateChanged() {
            view.syncToggles();
        }
    }
    Component.onCompleted: { DisplayService.start(); chooseMonitor(); }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: "󰍹"
                font.family: ThemeBackend.iconFont
                font.pixelSize: 23
                color: ThemeBackend.mauve
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text {
                    text: view.selectedMonitor || "No monitor connected"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    color: ThemeBackend.text
                }
                Text {
                    Layout.fillWidth: true
                    text: (DisplayService.monitors.find(m => m.name === view.selectedMonitor) || {}).description || "Waiting for Hyprland…"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 9
                    color: ThemeBackend.subtext0
                    elide: Text.ElideRight
                }
            }
            Toggle {
                id: enableToggle
                checked: view.entry.enabled
                buttonText: checked ? "Enabled" : "Off"
                textFontSize: 11
                accentColor: ThemeBackend.mauve
                enabled: DisplayService.ready && !!view.selectedMonitor
                Accessible.role: Accessible.CheckBox
                Accessible.name: "Enable display adjustments for " + view.selectedMonitor
                onToggled: checked => DisplayService.action("enable", view.selectedMonitor, {enabled: checked})
            }
        }

        Flow {
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? implicitHeight : 0
            visible: DisplayService.monitors.length > 1
            spacing: 6
            Repeater {
                model: DisplayService.monitors
                ClickButton {
                    required property var modelData
                    buttonText: modelData.name
                    implicitHeight: 26
                    textFontSize: 10
                    accentColor: view.selectedMonitor === modelData.name ? ThemeBackend.mauve : ThemeBackend.surface0
                    textColor: view.selectedMonitor === modelData.name ? ThemeBackend.base : ThemeBackend.text
                    onClicked: { DisplayService.flush(); view.selectedMonitor = modelData.name; }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(ThemeBackend.text, 0.10) }

        QQC.ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
            QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded

            ColumnLayout {
                width: scroll.availableWidth
                spacing: 12

                Text {
                    text: "LIGHT & COLOR"
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 22
                    rowSpacing: 10
                    enabled: DisplayService.ready && !!view.selectedMonitor
                    Repeater {
                        model: ["brightness", "contrast", "saturation", "gamma", "temperature", "blueLight"]
                        DisplaySlider {
                            required property string modelData
                            controlKey: modelData
                            monitor: view.selectedMonitor
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Toggle {
                        id: grayscaleToggle
                        Layout.fillWidth: true
                        buttonText: "Grayscale"
                        textFontSize: 11
                        checked: view.entry.values.grayscale === true
                        accentColor: ThemeBackend.mauve
                        enabled: DisplayService.ready && !!view.selectedMonitor
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Grayscale"
                        onToggled: checked => DisplayService.setValue(view.selectedMonitor, "grayscale", checked)
                    }
                    Toggle {
                        id: invertToggle
                        Layout.fillWidth: true
                        buttonText: "Invert colors"
                        textFontSize: 11
                        checked: view.entry.values.invert === true
                        accentColor: ThemeBackend.mauve
                        enabled: DisplayService.ready && !!view.selectedMonitor
                        Accessible.role: Accessible.CheckBox
                        Accessible.name: "Invert colors"
                        onToggled: checked => DisplayService.setValue(view.selectedMonitor, "invert", checked)
                    }
                }

                ClickButton {
                    Layout.fillWidth: true
                    implicitHeight: 29
                    buttonText: view.advanced ? "Advanced adjustments  ▴" : "Advanced adjustments  ▾"
                    textFontSize: 10
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext1
                    Accessible.name: "Advanced adjustments"
                    Accessible.role: Accessible.Button
                    Accessible.description: view.advanced ? "Expanded" : "Collapsed"
                    onClicked: view.advanced = !view.advanced
                }
                GridLayout {
                    Layout.fillWidth: true
                    visible: view.advanced
                    columns: 2
                    columnSpacing: 22
                    rowSpacing: 10
                    enabled: DisplayService.ready && !!view.selectedMonitor
                    Repeater {
                        model: ["hue", "shadows", "red", "redGamma", "green", "greenGamma", "blue", "blueGamma", "blackLevel", "whiteLevel", "highlights"]
                        DisplaySlider {
                            required property string modelData
                            controlKey: modelData
                            monitor: view.selectedMonitor
                        }
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: !view.entry.enabled ? "Adjustments are off. Enable to preview your changes." : "Live desktop color • " + view.entry.profile
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 9
                    color: ThemeBackend.subtext0
                }
                Text {
                    Layout.fillWidth: true
                    text: "Brightness dims pixel output. It does not change the backlight."
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 8
                    color: ThemeBackend.subtext0
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Qt.alpha(ThemeBackend.text, 0.10) }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "PROFILES"
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                    font.weight: Font.Bold
                    color: ThemeBackend.subtext0
                }
                Text {
                    text: view.entry.profile
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: 10
                    color: ThemeBackend.mauve
                }
            }
            QQC.ScrollView {
                id: profileScroll
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(profileFlow.implicitHeight, 60)
                contentWidth: availableWidth
                clip: true
                QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
                QQC.ScrollBar.vertical.policy: QQC.ScrollBar.AsNeeded
                Flow {
                    id: profileFlow
                    width: profileScroll.availableWidth
                    spacing: 5
                    Repeater {
                        model: DisplayService.state.profiles || []
                        ClickButton {
                            required property string modelData
                            implicitHeight: 25
                            horizontalPadding: 9
                            textFontSize: 9
                            cornerRadius: ThemeBackend.borderRadius
                            buttonText: modelData
                            accentColor: view.entry.profile === modelData ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: view.entry.profile === modelData ? ThemeBackend.base : ThemeBackend.subtext1
                            enabled: DisplayService.ready && !!view.selectedMonitor
                            Accessible.role: Accessible.Button
                            Accessible.name: "Apply " + modelData + " profile"
                            onClicked: { view.editMode = ""; DisplayService.action("preset", view.selectedMonitor, {profile: modelData}); }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                ClickButton {
                    buttonText: "Save as…"
                    textFontSize: 10
                    implicitHeight: 28
                    enabled: DisplayService.ready && !!view.selectedMonitor
                    onClicked: { view.editMode = "save"; profileName.text = ""; profileName.forceActiveFocus(); }
                }
                ClickButton {
                    buttonText: "Rename"
                    textFontSize: 10
                    implicitHeight: 28
                    visible: view.customProfile
                    onClicked: { view.editMode = "rename"; profileName.text = view.entry.profile; profileName.forceActiveFocus(); }
                }
                ClickButton {
                    buttonText: "Delete"
                    textFontSize: 10
                    implicitHeight: 28
                    visible: view.customProfile
                    onClicked: DisplayService.action("delete", view.selectedMonitor, {profile: view.entry.profile})
                }
                Item { Layout.fillWidth: true }
                ClickButton {
                    buttonText: "Reset"
                    buttonIcon: "󰑓"
                    textFontSize: 10
                    implicitHeight: 28
                    enabled: DisplayService.ready && !!view.selectedMonitor
                    Accessible.name: "Reset selected monitor to defaults"
                    onClicked: { view.editMode = ""; DisplayService.action("reset", view.selectedMonitor); }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: view.editMode !== ""
                spacing: 6
                Input {
                    id: profileName
                    Layout.fillWidth: true
                    implicitHeight: 30
                    maximumLength: 48
                    placeholderText: "Profile name"
                    fontPixelSize: 10
                    cornerRadius: ThemeBackend.borderRadius
                    Accessible.name: "Profile name"
                    onAccepted: view.commitProfile()
                }
                ClickButton {
                    buttonText: "Save"
                    implicitHeight: 30
                    textFontSize: 10
                    enabled: !!profileName.text.trim()
                    onClicked: view.commitProfile()
                }
                ClickButton {
                    buttonText: "Cancel"
                    implicitHeight: 30
                    textFontSize: 10
                    onClicked: view.editMode = ""
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: !!DisplayService.error || !!DisplayService.state.warning
            text: DisplayService.error || DisplayService.state.warning || ""
            wrapMode: Text.WordWrap
            color: DisplayService.error ? ThemeBackend.red : ThemeBackend.peach
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 9
            Accessible.role: Accessible.StaticText
            Accessible.name: text
        }
    }
}
