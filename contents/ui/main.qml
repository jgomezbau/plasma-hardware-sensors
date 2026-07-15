import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    property string hostName: "Equipo"
    property string modelName: ""

    property real cpu: NaN
    property real cpuCritical: NaN
    property real maximumCpu: NaN

    property var temperatureSensors: []
    property var visibleTemperatures: []
    property var coreSensors: []
    property var fanSensors: []

    property bool cpuExpanded: false
    property var history: []
    property string lastUpdate: "--:--:--"
    property string errorMessage: ""

    property string scriptPath: {
        const url = Qt.resolvedUrl("../scripts/read-sensors.sh").toString()
        return url.replace("file://", "")
    }

    property string command: "/usr/bin/env bash \"" + scriptPath + "\""

    function numericValue(value) {
        if (value === null || value === undefined)
            return NaN

        const converted = Number(value)
        return Number.isFinite(converted) ? converted : NaN
    }

    function temperature(value) {
        if (!Number.isFinite(value))
            return "N/D"

        return (Math.round(value / 100) / 10).toLocaleString(
                    Qt.locale(), "f", 1) + " °C"
    }

    function rpm(value) {
        if (!Number.isFinite(value))
            return "N/D"

        return Math.round(value).toLocaleString(
                    Qt.locale(), "f", 0) + " RPM"
    }

    function temperatureColor(value, critical) {
        if (!Number.isFinite(value))
            return Kirigami.Theme.disabledTextColor

        if (Number.isFinite(critical)) {
            if (value >= critical - 5000)
                return "#ef5350"
            if (value >= critical - 15000)
                return "#ff7043"
            if (value >= critical - 25000)
                return "#ffb300"
            return "#45c45a"
        }

        if (value >= 95000)
            return "#ef5350"
        if (value >= 85000)
            return "#ff7043"
        if (value >= 75000)
            return "#ffb300"
        return "#45c45a"
    }

    function statusText(value, critical) {
        if (!Number.isFinite(value))
            return "Sin datos"

        if (Number.isFinite(critical)) {
            if (value >= critical - 5000)
                return "Crítico"
            if (value >= critical - 15000)
                return "Alto"
            if (value >= critical - 25000)
                return "Elevado"
            return "Normal"
        }

        if (value >= 95000)
            return "Crítico"
        if (value >= 85000)
            return "Alto"
        if (value >= 75000)
            return "Elevado"
        return "Normal"
    }

    function iconForSensor(sensor) {
        if (sensor.device === "acpitz")
            return "preferences-system"
        if (sensor.device === "thinkpad")
            return "computer-laptop"

        switch (sensor.category) {
        case "gpu":
            return "video-display"
        case "chipset":
            return "computer"
        case "storage":
            return "drive-harddisk"
        case "wifi":
            return "network-wireless"
        case "system":
            return "preferences-system"
        default:
            return "temperature-symbolic"
        }
    }

    function categoryPriority(category) {
        switch (category) {
        case "gpu": return 1
        case "chipset": return 2
        case "storage": return 3
        case "wifi": return 4
        case "system": return 5
        default: return 10
        }
    }

    function findPrimaryCpu(sensors) {
        for (let index = 0; index < sensors.length; index++) {
            if (sensors[index].category === "cpu")
                return sensors[index]
        }
        return null
    }

    function prepareVisibleTemperatures(sensors) {
        const candidates = []
        const duplicateKeys = {}

        for (let index = 0; index < sensors.length; index++) {
            const sensor = sensors[index]
            const category = sensor.category || "temperature"
            const value = numericValue(sensor.value)

            if (!Number.isFinite(value))
                continue
            if (category === "cpu" || category === "cpu_core")
                continue
            if (category.endsWith("_detail"))
                continue

            const duplicateKey = category + "|" + (sensor.label || "") + "|" + value
            if (duplicateKeys[duplicateKey])
                continue

            duplicateKeys[duplicateKey] = true
            candidates.push({
                id: sensor.id || ("sensor-" + index),
                category: category,
                label: sensor.label || "Temperatura",
                value: value,
                critical: numericValue(sensor.critical),
                device: sensor.device || ""
            })
        }

        candidates.sort(function(left, right) {
            const difference = categoryPriority(left.category)
                    - categoryPriority(right.category)
            if (difference !== 0)
                return difference
            return left.label.localeCompare(right.label)
        })

        const totals = {}
        const occurrences = {}

        for (let index = 0; index < candidates.length; index++) {
            const label = candidates[index].label
            totals[label] = (totals[label] || 0) + 1
        }

        for (let index = 0; index < candidates.length; index++) {
            const sensor = candidates[index]
            const originalLabel = sensor.label
            occurrences[originalLabel] = (occurrences[originalLabel] || 0) + 1

            if (totals[originalLabel] > 1)
                sensor.label = originalLabel + " " + occurrences[originalLabel]
        }

        return candidates
    }

    function processOutput(output) {
        try {
            const values = JSON.parse(output.trim())

            hostName = values.hostname || "Equipo"
            modelName = values.model || ""

            const discoveredTemperatures = Array.isArray(values.temperatures)
                    ? values.temperatures : []
            const discoveredFans = Array.isArray(values.fans)
                    ? values.fans : []

            temperatureSensors = discoveredTemperatures
            fanSensors = discoveredFans
            coreSensors = discoveredTemperatures.filter(function(sensor) {
                return sensor.category === "cpu_core"
            })

            const primaryCpu = findPrimaryCpu(discoveredTemperatures)

            if (primaryCpu !== null) {
                cpu = numericValue(primaryCpu.value)
                cpuCritical = numericValue(primaryCpu.critical)
            } else {
                cpu = numericValue(values.cpu)
                cpuCritical = NaN
            }

            visibleTemperatures = prepareVisibleTemperatures(discoveredTemperatures)

            if (Number.isFinite(cpu)) {
                if (!Number.isFinite(maximumCpu) || cpu > maximumCpu)
                    maximumCpu = cpu

                let updatedHistory = history.slice()
                updatedHistory.push(cpu / 1000)
                if (updatedHistory.length > 60)
                    updatedHistory.shift()
                history = updatedHistory
            }

            lastUpdate = Qt.formatTime(new Date(), "HH:mm:ss")
            errorMessage = ""
        } catch (error) {
            errorMessage = "No se pudieron interpretar los sensores"
            console.error("Sensores:", error)
        }
    }

    implicitWidth: 350
    implicitHeight: Math.max(
        510,
        330
        + visibleTemperatures.length * 35
        + Math.max(1, fanSensors.length) * 47
        + (cpuExpanded ? 16 + coreSensors.length * 29 : 0)
    )

    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                PlasmaComponents.Label {
                    text: "Sensores · " + root.hostName
                    font.pixelSize: 21
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: (root.modelName !== "" ? root.modelName + " · " : "")
                          + "Actualizado " + root.lastUpdate
                    font.pixelSize: 11
                    color: Kirigami.Theme.disabledTextColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }

            Rectangle {
                implicitWidth: statusLabel.implicitWidth + 22
                implicitHeight: 28
                radius: 14
                color: Qt.rgba(
                    root.temperatureColor(root.cpu, root.cpuCritical).r,
                    root.temperatureColor(root.cpu, root.cpuCritical).g,
                    root.temperatureColor(root.cpu, root.cpuCritical).b,
                    0.16
                )

                PlasmaComponents.Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    text: root.statusText(root.cpu, root.cpuCritical)
                    color: root.temperatureColor(root.cpu, root.cpuCritical)
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        Rectangle {
            id: cpuCard
            Layout.fillWidth: true
            Layout.preferredHeight: 154
                    + (root.cpuExpanded ? 16 + root.coreSensors.length * 29 : 0)
            radius: 12
            color: cpuMouseArea.containsMouse
                   ? Qt.rgba(1, 1, 1, 0.075)
                   : Qt.rgba(1, 1, 1, 0.055)
            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)

            Behavior on color {
                ColorAnimation { duration: 120 }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: "CPU"
                        font.pixelSize: 17
                        font.weight: Font.Medium
                        Layout.fillWidth: true
                    }

                    Kirigami.Icon {
                        visible: root.coreSensors.length > 0
                        source: root.cpuExpanded ? "go-up-symbolic" : "go-down-symbolic"
                        implicitWidth: 16
                        implicitHeight: 16
                        color: Kirigami.Theme.disabledTextColor
                    }

                    PlasmaComponents.Label {
                        text: root.temperature(root.cpu)
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        color: root.temperatureColor(root.cpu, root.cpuCritical)
                    }
                }

                HistoryGraph {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    values: root.history
                    lineColor: root.temperatureColor(root.cpu, root.cpuCritical)
                }

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: root.coreSensors.length > 0
                              ? (root.cpuExpanded ? "Ocultar núcleos" : "Ver núcleos")
                              : "60 segundos"
                        font.pixelSize: 10
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: "Máximo " + root.temperature(root.maximumCpu)
                        font.pixelSize: 11
                        color: Kirigami.Theme.disabledTextColor
                    }
                }

                ColumnLayout {
                    visible: root.cpuExpanded && root.coreSensors.length > 0
                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        Layout.topMargin: 6
                        Layout.bottomMargin: 5
                        color: Qt.rgba(1, 1, 1, 0.12)
                    }

                    Repeater {
                        model: root.coreSensors

                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 28

                            PlasmaComponents.Label {
                                text: modelData.label
                                font.pixelSize: 13
                                Layout.fillWidth: true
                            }

                            PlasmaComponents.Label {
                                text: root.temperature(Number(modelData.value))
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                color: root.temperatureColor(
                                    Number(modelData.value),
                                    root.numericValue(modelData.critical)
                                )
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: cpuMouseArea
                anchors.fill: parent
                enabled: root.coreSensors.length > 0
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.cpuExpanded = !root.cpuExpanded
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            Repeater {
                model: root.visibleTemperatures

                delegate: SensorRow {
                    required property var modelData
                    iconName: root.iconForSensor(modelData)
                    label: modelData.label
                    value: root.temperature(modelData.value)
                    valueColor: root.temperatureColor(
                        modelData.value, modelData.critical)
                }
            }
        }

        Rectangle {
            visible: root.fanSensors.length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 1 : 0
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        ColumnLayout {
            visible: root.fanSensors.length > 0
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: root.fanSensors

                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    spacing: 10

                    FanIcon {
                        implicitWidth: 23
                        implicitHeight: 23
                        rpm: Number(modelData.rpm)
                        color: Kirigami.Theme.disabledTextColor
                    }

                    PlasmaComponents.Label {
                        text: modelData.label || "Ventilador"
                        font.pixelSize: 15
                        Layout.fillWidth: true
                    }

                    ColumnLayout {
                        spacing: 0

                        PlasmaComponents.Label {
                            text: root.rpm(Number(modelData.rpm))
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            Layout.alignment: Qt.AlignRight
                        }

                        PlasmaComponents.Label {
                            text: "Control automático"
                            font.pixelSize: 10
                            color: Kirigami.Theme.highlightColor
                            Layout.alignment: Qt.AlignRight
                        }
                    }
                }
            }
        }

        PlasmaComponents.Label {
            visible: root.fanSensors.length === 0
            text: "RPM del ventilador no disponibles"
            color: Kirigami.Theme.disabledTextColor
            font.pixelSize: 11
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        PlasmaComponents.Label {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: "#ef5350"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }
    }

    Plasma5Support.DataSource {
        id: sensorSource
        engine: "executable"
        connectedSources: [root.command]
        interval: 2000

        onNewData: function(sourceName, data) {
            if (data.stdout)
                root.processOutput(data.stdout)
            if (data.stderr)
                console.warn("Sensores:", data.stderr)
        }
    }
}
