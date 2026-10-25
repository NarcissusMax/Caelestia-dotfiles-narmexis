pragma Singleton
import QtQuick
import Quickshell.Io
import "../../"

QtObject {
    id: service
    property var state: ({})
    property bool started: false
    property var pendingValues: ({})
    property string pendingMonitor: ""
    readonly property bool ready: state.ready === true && backend.running
    readonly property string error: state.error || ""
    readonly property var monitors: state.monitors || []

    function start() { started = true; }
    function entry(monitor) {
        return (state.settings || {})[monitor] || {enabled: false, profile: "Default", values: state.defaults || {}};
    }
    function send(request) {
        if (!backend.running || !ready) return;
        backend.write(JSON.stringify(request) + "\n");
    }
    function flush() {
        previewTimer.stop();
        if (pendingMonitor && Object.keys(pendingValues).length) {
            send({op: "set", monitor: pendingMonitor, values: pendingValues});
            pendingValues = ({});
            pendingMonitor = "";
        }
    }
    function setValue(monitor, key, value) {
        if (pendingMonitor && pendingMonitor !== monitor) flush();
        pendingMonitor = monitor;
        let patch = Object.assign({}, pendingValues);
        patch[key] = value;
        pendingValues = patch;
        // Optimistic UI, with compositor updates capped at ten per second.
        let next = JSON.parse(JSON.stringify(state));
        if (next.settings && next.settings[monitor]) {
            next.settings[monitor].values[key] = value;
            next.settings[monitor].profile = "Custom";
            state = next;
        }
        if (!previewTimer.running) previewTimer.start();
    }
    function action(op, monitor, extra) {
        flush();
        send(Object.assign({op: op, monitor: monitor}, extra || {}));
    }

    property Timer previewTimer: Timer {
        interval: 100
        onTriggered: service.flush()
    }
    property Timer retryTimer: Timer {
        interval: 1500
        onTriggered: if (service.started) service.backend.running = true
    }
    property Process backend: Process {
        command: ["python3", Qt.resolvedUrl("../../media/display_backend.py").toString().replace("file://", ""), "serve"]
        running: service.started
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    let next = JSON.parse(line);
                    if (service.pendingMonitor && next.settings && next.settings[service.pendingMonitor]) {
                        let entry = next.settings[service.pendingMonitor];
                        entry.values = Object.assign({}, entry.values, service.pendingValues);
                        entry.profile = "Custom";
                    }
                    service.state = next;
                } catch (e) {
                    console.warn("Display controller response:", e);
                }
            }
        }
        stderr: SplitParser { onRead: line => console.warn("Display controller:", line) }
        onExited: (exitCode, exitStatus) => {
            service.state = Object.assign({}, service.state, {ready: false, error: service.state.error || "Display controller stopped. Reconnecting…"});
            service.retryTimer.restart();
        }
    }
}
