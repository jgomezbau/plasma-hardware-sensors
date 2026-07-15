import QtQuick
import org.kde.kirigami as Kirigami

Canvas {
    id: graph

    property var values: []
    property color lineColor: Kirigami.Theme.highlightColor

    implicitHeight: 54
    antialiasing: true

    onValuesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const context = getContext("2d")
        context.reset()

        if (!values || values.length < 2)
            return

        const padding = 2
        const usableWidth = width - padding * 2
        const usableHeight = height - padding * 2

        let minimum = Math.min.apply(null, values)
        let maximum = Math.max.apply(null, values)

        minimum = Math.min(minimum, 60)
        maximum = Math.max(maximum, 90)

        const range = Math.max(1, maximum - minimum)
        const step = usableWidth / (values.length - 1)

        function pointX(index) {
            return padding + index * step
        }

        function pointY(value) {
            return padding + usableHeight -
                    ((value - minimum) / range) * usableHeight
        }

        const fillGradient = context.createLinearGradient(0, 0, 0, height)
        fillGradient.addColorStop(0, Qt.rgba(
            lineColor.r, lineColor.g, lineColor.b, 0.28))
        fillGradient.addColorStop(1, Qt.rgba(
            lineColor.r, lineColor.g, lineColor.b, 0.01))

        context.beginPath()
        context.moveTo(pointX(0), height)

        for (let index = 0; index < values.length; index++)
            context.lineTo(pointX(index), pointY(values[index]))

        context.lineTo(pointX(values.length - 1), height)
        context.closePath()
        context.fillStyle = fillGradient
        context.fill()

        context.beginPath()
        context.moveTo(pointX(0), pointY(values[0]))

        for (let index = 1; index < values.length; index++)
            context.lineTo(pointX(index), pointY(values[index]))

        context.strokeStyle = lineColor
        context.lineWidth = 2
        context.lineJoin = "round"
        context.lineCap = "round"
        context.stroke()
    }
}