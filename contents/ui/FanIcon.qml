import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: root

    property real rpm: 0
    property color color: Kirigami.Theme.disabledTextColor

    implicitWidth: 23
    implicitHeight: 23
    antialiasing: true

    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d")
        context.reset()
        context.globalAlpha = 0.62


        const size = Math.min(width, height)
        const unit = size * 0.245

        context.translate(width / 2, height / 2)
        context.strokeStyle = root.color
        context.lineWidth = Math.max(1.15, size * 0.06)
        context.lineCap = "round"
        context.lineJoin = "round"
        context.fillStyle = "transparent"

        /*
         * Tres aspas curvas.
         * Cada aspa es la misma figura rotada 120 grados.
         */
        for (let blade = 0; blade < 3; blade++) {
            context.save()
            context.rotate(blade * Math.PI * 2 / 3)
            context.scale(unit, unit)
            context.lineWidth = 0.21
            context.beginPath()

            // Inicio junto al eje central
            context.moveTo(-0.13, -0.13)

            // Curva exterior izquierda
            context.bezierCurveTo(
                -0.65, -0.28,
                -0.95, -0.82,
                -0.73, -1.31
            )

            // Parte superior redondeada
            context.bezierCurveTo(
                -0.51, -1.79,
                 0.18, -1.93,
                 0.70, -1.57
            )

            // Punta redondeada del aspa
            context.bezierCurveTo(
                 1.02, -1.35,
                 1.00, -0.93,
                 0.69, -0.78
            )

            // Curva interior hacia el centro
            context.bezierCurveTo(
                 0.48, -0.68,
                 0.35, -0.82,
                 0.17, -0.74
            )

            context.bezierCurveTo(
                -0.15, -0.60,
                -0.30, -0.30,
                -0.13, -0.13
            )

            context.closePath()
            context.stroke()
            context.restore()
        }

        // Eje central
        context.beginPath()
        context.arc(0, 0, size * 0.085, 0, Math.PI * 2)
        context.stroke()
    }
}