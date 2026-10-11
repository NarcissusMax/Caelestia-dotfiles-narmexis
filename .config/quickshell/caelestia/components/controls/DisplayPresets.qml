pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Caelestia.Config
import qs.components
import qs.services

ColumnLayout {
    id: root

    signal editRequested()

    property bool editorOpen: false
    property string selectedName: ""
    property string message: ""
    readonly property bool selectedExists: Display.presets.some(p => p.name === selectedName)

    function showResult(result: string): bool {
        if (result === "saved") {
            message = qsTr("Preset saved");
            return true;
        }
        if (result === "empty")
            message = qsTr("Enter a preset name");
        else if (result === "long")
            message = qsTr("Use a name with 60 characters or fewer");
        else if (result === "duplicate")
            message = qsTr("That name is already in use");
        else
            message = qsTr("Preset is no longer available");
        return false;
    }

    function saveCurrent(): void {
        if (showResult(Display.savePreset(nameField.text)))
            selectedName = nameField.text.trim();
    }

    function updateSelected(): void {
        if (showResult(Display.updatePreset(selectedName)))
            message = qsTr("Preset updated");
    }

    function renameSelected(): void {
        if (showResult(Display.renamePreset(selectedName, nameField.text)))
            selectedName = nameField.text.trim();
    }

    function deleteSelected(name: string): void {
        Display.deletePreset(name);
        if (selectedName === name) {
            selectedName = "";
            nameField.text = "";
        }
        message = qsTr("Preset deleted");
    }

    function beginCreate(): void {
        selectedName = "";
        nameField.text = "";
        message = "";
        editorOpen = true;
        nameField.forceActiveFocus();
    }

    onEditorOpenChanged: ShellState.displayPresetEditorOpen = editorOpen
    Component.onDestruction: {
        if (editorOpen)
            ShellState.displayPresetEditorOpen = false;
    }

    Layout.fillWidth: true
    spacing: Tokens.spacing.small

    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Tokens.spacing.medium

        StyledText {
            Layout.fillWidth: true
            text: qsTr("Display")
            font: Tokens.font.body.builders.medium.weight(Font.Medium).build()
        }

        TextButton {
            type: TextButton.Tonal
            text: qsTr("Add preset")
            onClicked: root.beginCreate()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: root.editorOpen
        spacing: Tokens.spacing.small

        StyledTextField {
            id: nameField

            Layout.fillWidth: true
            Layout.preferredWidth: Tokens.sizes.osd.sliderWidth
            placeholderText: qsTr("Preset name")
            maximumLength: 60
            verticalPadding: Tokens.padding.small
            horizontalPadding: Tokens.padding.medium
            onTextEdited: root.message = ""
            onAccepted: {
                if (root.selectedExists && text.trim() === root.selectedName)
                    root.updateSelected();
                else
                    root.saveCurrent();
            }
        }

        TextButton {
            Layout.fillWidth: true
            text: qsTr("Save as new preset")
            disabled: !nameField.text.trim()
            onClicked: root.saveCurrent()
        }

        TextButton {
            Layout.fillWidth: true
            visible: root.selectedExists
            text: qsTr("Update selected preset from sliders")
            onClicked: root.updateSelected()
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.selectedExists
            spacing: Tokens.spacing.small

            TextButton {
                Layout.fillWidth: true
                type: TextButton.Tonal
                text: qsTr("Rename")
                disabled: !nameField.text.trim()
                onClicked: root.renameSelected()
            }

            TextButton {
                Layout.fillWidth: true
                type: TextButton.Tonal
                text: qsTr("Delete")
                onClicked: root.deleteSelected(root.selectedName)
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: root.message.length > 0
            text: root.message
            color: Colours.palette.m3onSurfaceVariant
            wrapMode: Text.Wrap
            font: Tokens.font.body.small
        }

        TextButton {
            Layout.fillWidth: true
            type: TextButton.Text
            text: qsTr("Close preset editor")
            onClicked: root.editorOpen = false
        }
    }

    ButtonGroup {
        id: displayPresets
    }

    Flickable {
        id: presetList

        Layout.fillWidth: true
        Layout.preferredWidth: Tokens.sizes.osd.sliderWidth
        Layout.preferredHeight: Math.min(presetColumn.implicitHeight, 160)
        contentWidth: width
        contentHeight: presetColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: presetColumn

            width: presetList.width
            spacing: Tokens.spacing.extraSmall

            Repeater {
                model: Display.presets

                RowLayout {
                    id: presetRow

                    required property var modelData

                    Layout.fillWidth: true
                    spacing: Tokens.spacing.small

                    StyledRadioButton {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 0
                        Layout.preferredWidth: 0
                        ButtonGroup.group: displayPresets
                        checked: Display.activePreset === presetRow.modelData.name
                        elideText: true
                        text: presetRow.modelData.name
                        ToolTip.visible: hovered && implicitWidth > width
                        ToolTip.text: presetRow.modelData.name
                        ToolTip.delay: 500
                        onClicked: {
                            Display.applyPreset(presetRow.modelData.name);
                            root.selectedName = presetRow.modelData.name;
                            if (root.editorOpen)
                                nameField.text = presetRow.modelData.name;
                            root.message = "";
                        }
                    }

                    TextButton {
                        type: TextButton.Text
                        horizontalPadding: Tokens.padding.extraSmall
                        text: qsTr("Edit")
                        onClicked: {
                            Display.applyPreset(presetRow.modelData.name);
                            root.selectedName = presetRow.modelData.name;
                            nameField.text = presetRow.modelData.name;
                            root.editorOpen = true;
                            root.message = "";
                            root.editRequested();
                        }
                    }

                    TextButton {
                        type: TextButton.Tonal
                        horizontalPadding: Tokens.padding.extraSmall
                        text: qsTr("Delete")
                        onClicked: root.deleteSelected(presetRow.modelData.name)
                    }
                }
            }
        }
    }

}
