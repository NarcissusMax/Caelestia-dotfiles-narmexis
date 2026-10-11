pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    readonly property string ctlPath: "/home/narmexis/.local/bin/qsdisplay"

    property real brightnessValue: 1.0     // 0.0 .. 2.0      (100% shown)
    property real contrastValue: 1.0       // 0.0 .. 2.0      (100% shown)
    property real gammaValue: 1.0          // 0.5 .. 2.5      (1.0 = neutral)
    property real saturationValue: 1.0     // 0.0 .. 1.5      (100% shown)
    property real temperatureValue: 6500   // 1500 .. 10000 K (6500 neutral)
    property bool loaded: false

    property list<var> presets: []

    readonly property string activePreset: {
        for (const p of presets) {
            if (Math.abs(p.brightness - brightnessValue) < 0.005 &&
                Math.abs(p.contrast - contrastValue) < 0.005 &&
                Math.abs(p.gamma - gammaValue) < 0.005 &&
                Math.abs(p.saturation - saturationValue) < 0.005 &&
                Math.abs(p.temperature - temperatureValue) < 50)
                return p.name;
        }
        return "Custom";
    }

    function set(key: string, value: real): void {
        if (key === "brightness") brightnessValue = value;
        else if (key === "contrast") contrastValue = value;
        else if (key === "gamma") gammaValue = value;
        else if (key === "saturation") saturationValue = value;
        else if (key === "temperature") temperatureValue = value;
        writeTimer.restart();
    }

    function setBrightness(v: real): void { set("brightness", v); }
    function setContrast(v: real): void { set("contrast", v); }
    function setGamma(v: real): void { set("gamma", v); }
    function setSaturation(v: real): void { set("saturation", v); }
    function setTemperature(v: real): void { set("temperature", v); }

    function applyPreset(name: string): void {
        for (const p of presets) {
            if (p.name !== name)
                continue;
            brightnessValue = p.brightness;
            contrastValue = p.contrast;
            gammaValue = p.gamma;
            saturationValue = p.saturation;
            temperatureValue = p.temperature;
            writeNow();
            return;
        }
    }

    function presetValues(name: string): var {
        return {
            name,
            brightness: brightnessValue,
            contrast: contrastValue,
            gamma: gammaValue,
            saturation: saturationValue,
            temperature: temperatureValue
        };
    }

    function validPreset(p: var): bool {
        return p && typeof p.name === "string" && p.name.trim().length > 0 && p.name.length <= 60
            && Number.isFinite(p.brightness) && p.brightness >= 0 && p.brightness <= 2
            && Number.isFinite(p.contrast) && p.contrast >= 0 && p.contrast <= 2
            && Number.isFinite(p.gamma) && p.gamma >= 0.5 && p.gamma <= 2.5
            && Number.isFinite(p.saturation) && p.saturation >= 0 && p.saturation <= 1.5
            && Number.isFinite(p.temperature) && p.temperature >= 1500 && p.temperature <= 10000;
    }

    function persistPresets(): void {
        presetStorage.setText(JSON.stringify({ version: 2, presets }, null, 2));
    }

    function cleanPresets(data: var): var {
        const seen = new Set();
        return data.filter(p => {
            if (!validPreset(p) || seen.has(p.name.toLowerCase()))
                return false;
            seen.add(p.name.toLowerCase());
            return true;
        });
    }

    function savePreset(name: string): string {
        const trimmed = name.trim();
        if (!trimmed)
            return "empty";
        if (trimmed.length > 60)
            return "long";
        if (presets.some(p => p.name.toLowerCase() === trimmed.toLowerCase()))
            return "duplicate";

        presets = [...presets, presetValues(trimmed)];
        persistPresets();
        return "saved";
    }

    function updatePreset(name: string): string {
        const index = presets.findIndex(p => p.name === name);
        if (index < 0)
            return "missing";
        const next = presets.slice();
        next[index] = presetValues(name);
        presets = next;
        persistPresets();
        return "saved";
    }

    function renamePreset(oldName: string, newName: string): string {
        const trimmed = newName.trim();
        if (!trimmed)
            return "empty";
        if (trimmed.length > 60)
            return "long";
        const index = presets.findIndex(p => p.name === oldName);
        if (index < 0)
            return "missing";
        if (presets.some((p, i) => i !== index && p.name.toLowerCase() === trimmed.toLowerCase()))
            return "duplicate";

        const next = presets.slice();
        next[index] = Object.assign({}, next[index], { name: trimmed });
        presets = next;
        persistPresets();
        return "saved";
    }

    function deletePreset(name: string): void {
        const next = presets.filter(p => p.name !== name);
        if (next.length === presets.length)
            return;
        presets = next;
        persistPresets();
    }

    function writeNow(): void {
        writeTimer.stop();
        proc.command = [
            ctlPath, "set",
            `brightness=${brightnessValue}`,
            `contrast=${contrastValue}`,
            `gamma=${gammaValue}`,
            `saturation=${saturationValue}`,
            `temperature=${temperatureValue}`
        ];
        proc.running = true;
    }

    Component.onCompleted: {
        initProc.command = [ctlPath, "get"];
        initProc.running = true;
    }

    Timer {
        id: writeTimer
        interval: 150
        onTriggered: root.writeNow()
    }

    FileView {
        id: presetStorage

        path: `${Paths.config}/display-presets.json`
        printErrors: false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && data.version === 2 && Array.isArray(data.presets))
                    root.presets = root.cleanPresets(data.presets);
                else if (Array.isArray(data))
                    root.presets = root.cleanPresets(data);
            } catch (error) {
                console.warn(`Unable to read display presets: ${error}`);
            }
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => root.persistPresets());
            else
                console.warn(`Unable to load display presets: ${err}`);
        }
    }

    Process {
        id: initProc
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const idx = line.indexOf("=");
                    if (idx < 0)
                        continue;
                    const key = line.slice(0, idx);
                    const value = parseFloat(line.slice(idx + 1));
                    if (isNaN(value))
                        continue;
                    if (key === "brightness") root.brightnessValue = value;
                    else if (key === "contrast") root.contrastValue = value;
                    else if (key === "gamma") root.gammaValue = value;
                    else if (key === "saturation") root.saturationValue = value;
                    else if (key === "temperature") root.temperatureValue = value;
                }
                root.loaded = true;
            }
        }
    }

    Process {
        id: proc

        readonly property int unused: 0 // silence qmllint about empty id
        stdout: StdioCollector {}
    }
}
