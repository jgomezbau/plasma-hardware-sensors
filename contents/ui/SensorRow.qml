import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents

RowLayout {
    id: row

    property string iconName: "temperature-symbolic"
    property string label: ""
    property string value: ""
    property string infoText: ""
    property color valueColor: Kirigami.Theme.textColor

    Layout.fillWidth: true
    Layout.preferredHeight: 34
    spacing: 10

    Kirigami.Icon {
        source: row.iconName
        implicitWidth: 20
        implicitHeight: 20
        color: Kirigami.Theme.disabledTextColor
    }

    PlasmaComponents.Label {
        text: row.label
        font.pixelSize: 15
        color: Kirigami.Theme.textColor
        Layout.fillWidth: true
    }

    PlasmaComponents.Label {
        text: row.value
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: row.valueColor
    }

    InfoButton {
        infoText: row.infoText
        Layout.alignment: Qt.AlignVCenter
    }
}
