import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Identificación del equipo
    property string hostName: "Equipo"
    property string modelName: ""

    // Sensores
    property real cpu: NaN
    property real chipset: NaN
    property real nvme: NaN
    property real wifi: NaN
    property real fan: NaN

    // Estado de la interfaz
    property real maximumCpu: NaN
    property var history: []
    property string lastUpdate: "--:--:--"
    property string errorMessage: ""

    // Lector de sensores
    property string scriptPath: {
        const url = Qt.resolvedUrl("../scripts/read-sensors.sh").toString()
        return url.replace("file://", "")
    }

    property string command:
        "/usr/bin/env bash \"" + scriptPath + "\""

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

    function temperatureColor(value) {
        if (!Number.isFinite(value))
            return Kirigami.Theme.disabledTextColor

        if (value >= 95000)
            return "#ef5350"

        if (value >= 85000)
            return "#ff7043"

        if (value >= 75000)
            return "#ffb300"

        return "#45c45a"
    }

    function statusText(value) {
        if (!Number.isFinite(value))
            return "Sin datos"

        if (value >= 95000)
            return "Crítico"

        if (value >= 85000)
            return "Alto"

        if (value >= 75000)
            return "Elevado"

        return "Normal"
    }

    function processOutput(output) {
        try {
            const values = JSON.parse(output.trim())

            // Datos dinámicos del equipo
            hostName = values.hostname || "Equipo"
            modelName = values.model || ""

            // Sensores
            cpu = numericValue(values.cpu)
            chipset = numericValue(values.chipset)
            nvme = numericValue(values.nvme)
            wifi = numericValue(values.wifi)
            fan = numericValue(values.fan)

            // Máximo de CPU durante la sesión
            if (Number.isFinite(cpu)) {
                if (!Number.isFinite(maximumCpu) || cpu > maximumCpu)
                    maximumCpu = cpu

                // Histórico de los últimos 60 valores
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
    implicitHeight: 510

    fullRepresentation: ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        // Encabezado
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
                    text: (root.modelName !== ""
                           ? root.modelName + " · "
                           : "")
                          + "Actualizado "
                          + root.lastUpdate

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
                    root.temperatureColor(root.cpu).r,
                    root.temperatureColor(root.cpu).g,
                    root.temperatureColor(root.cpu).b,
                    0.16
                )

                PlasmaComponents.Label {
                    id: statusLabel
                    anchors.centerIn: parent

                    text: root.statusText(root.cpu)
                    color: root.temperatureColor(root.cpu)

                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
            }
        }

        // Tarjeta principal de CPU
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 154

            radius: 12
            color: Qt.rgba(1, 1, 1, 0.055)

            border.width: 1
            border.color: Qt.rgba(1, 1, 1, 0.07)

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

                    PlasmaComponents.Label {
                        text: root.temperature(root.cpu)
                        font.pixelSize: 34
                        font.weight: Font.DemiBold
                        color: root.temperatureColor(root.cpu)
                    }
                }

                HistoryGraph {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    values: root.history
                    lineColor: root.temperatureColor(root.cpu)
                }

                RowLayout {
                    Layout.fillWidth: true

                    PlasmaComponents.Label {
                        text: "60 segundos"
                        font.pixelSize: 10
                        color: Kirigami.Theme.disabledTextColor
                        Layout.fillWidth: true
                    }

                    PlasmaComponents.Label {
                        text: "Máximo "
                              + root.temperature(root.maximumCpu)

                        font.pixelSize: 11
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }
        }

        // Sensores secundarios
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            SensorRow {
                iconName: "computer"
                label: "Chipset"
                value: root.temperature(root.chipset)
                valueColor: root.temperatureColor(root.chipset)
            }

            SensorRow {
                iconName: "drive-harddisk"
                label: "NVMe"
                value: root.temperature(root.nvme)
                valueColor: root.temperatureColor(root.nvme)
            }

            SensorRow {
                iconName: "network-wireless"
                label: "Wi-Fi"
                value: root.temperature(root.wifi)
                valueColor: root.temperatureColor(root.wifi)
            }
        }

        // Separador
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        // Ventilador
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 46
            spacing: 10

            FanIcon {
                implicitWidth: 23
                implicitHeight: 23

                rpm: root.fan
                color: Kirigami.Theme.disabledTextColor
            }

            PlasmaComponents.Label {
                text: "Ventilador CPU"
                font.pixelSize: 15
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: 0

                PlasmaComponents.Label {
                    text: root.rpm(root.fan)
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

        // Error de lectura
        PlasmaComponents.Label {
            visible: root.errorMessage !== ""
            text: root.errorMessage
            color: "#ef5350"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        Item {
            Layout.fillHeight: true
        }
    }

    // Ejecución periódica del lector
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