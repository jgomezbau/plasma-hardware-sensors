import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents

PlasmaComponents.ToolButton {
    id: button

    property string infoText: ""

    visible: infoText !== ""
    enabled: visible
    icon.name: "help-about"
    implicitWidth: 22
    implicitHeight: 22
    Layout.preferredWidth: 22
    Layout.preferredHeight: 22

    Accessible.name: infoText

    PlasmaComponents.ToolTip {
        text: button.infoText
    }
}
