import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtLocation
import QtPositioning

ApplicationWindow {
    id: window
    width: 800
    height: 480
    minimumWidth: 200
    minimumHeight: 250
    visible: true
    title: qsTr("Oil Simulation")
    property bool lightMode: Application.styleHints.colorScheme === Qt.Light
    property bool checking: false
    property color reallyDark: "#1f1f1f"
    property color dark: "#262626"
    property color reallyLight: "#e7e7e7"
    property color light: "#e0e0e0"

    Connections {
        target: copernicusManager

        function onLocationCheckFinished(success, isLand, message) {
            console.log("locationCheckFinished:", success, isLand, message)
            window.checking = false
            !success ? rectangle1.showError(message, "red") : (isLand ? rectangle1.showError(message, "#c97a00") : rectangle1.showError(message, "#2e8b57"))
        }
    }

    GridLayout {
        id: grid
        columns: width < 600 ? 1 : 2
        rowSpacing: 0
        columnSpacing: 0
        anchors.fill: parent

        Rectangle {
            id: rectangle1
            color: window.lightMode ? window.reallyLight : window.reallyDark

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 30

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 30, 300)
                spacing: 6

                Label {
                    text: "Ustaw wskaźnik"
                    color: window.lightMode ? window.dark : window.light
                    font.bold: true
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        id: latLabel
                        text: "Szerokość:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 11
                    }
                    TextField {
                        id: latInput
                        placeholderText: "Podaj szerokość..."
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        padding: 8
                        background: Rectangle {
                            radius: 6
                            color: window.lightMode ? "white" : "#111111"
                            border.color: window.lightMode ? "#cccccc" : "#444444"
                            border.width: 1
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        id: lonLabel
                        text: "Długość:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 11
                    }
                    TextField {
                        id: lonInput
                        placeholderText: "Podaj długość..."
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        padding: 8
                        background: Rectangle {
                            radius: 6
                            color: window.lightMode ? "white" : "#111111"
                            border.color: window.lightMode ? "#cccccc" : "#444444"
                            border.width: 1
                        }
                    }
                }

                Button {
                    text: "Postaw"
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    font.pixelSize: 11
                    padding: 10

                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }

                    onClicked: {
                        if (latInput.text.trim() === "" || lonInput.text.trim() === "") {
                            rectangle1.showError("Pola nie mogą być puste!", "red")
                            return
                        }

                        var latitude = Number(latInput.text.replace(",", "."))
                        var longitude = Number(lonInput.text.replace(",", "."))

                        if (!isFinite(latitude) || !isFinite(longitude)) {
                            rectangle1.showError("Podaj prawidłowe współrzędne!", "red")
                            return
                        }

                        if (latitude < mapMouseArea.southLimit ||
                            latitude > mapMouseArea.northLimit ||
                            longitude < mapMouseArea.westLimit ||
                            longitude > mapMouseArea.eastLimit) {
                            rectangle1.showError("Marker jest poza dozwolonym obszarem!", "red")
                            return
                        }

                        map.markerCoordinate = QtPositioning.coordinate(latitude, longitude)
                    }
                }

                Button {
                    text: window.checking ? "Sprawdzanie..." : "Zatwierdź"
                    enabled: !window.checking && !copernicusManager.isDownloading
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    font.pixelSize: 11
                    padding: 10

                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }

                    onClicked: {
                        console.log("Kliknięto Zatwierdź")

                        if (map.markerCoordinate === null) {
                            rectangle1.showError("Najpierw wybierz lokalizację!", "red")
                            return
                        }

                        window.checking = true
                        console.log("Marker:", map.markerCoordinate.latitude,
                                        map.markerCoordinate.longitude)

                        console.log("Data:", startDateInput.text)

                        copernicusManager.checkLocation(
                            map.markerCoordinate.latitude,
                            map.markerCoordinate.longitude,
                            startDateInput.text
                        )

                        console.log("Wywołano checkLocation")
                    }
                }

                Label {
                    id: locationStatus
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.pixelSize: 11
                    font.bold: true
                    visible: text !== ""
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: window.lightMode ? "#cccccc" : "#444444"
                    Layout.topMargin: 6
                    Layout.bottomMargin: 6
                }

                Label {
                    text: "Pobieranie danych Copernicus"
                    color: window.lightMode ? window.dark : window.light
                    font.bold: true
                    font.pixelSize: 13
                    Layout.alignment: Qt.AlignHCenter
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: "Data od:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 11
                    }
                    TextField {
                        id: startDateInput
                        text: "2026-10-11T20:00:00"
                        placeholderText: "np. 2026-10-11T20:00:00"
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        padding: 8
                        background: Rectangle {
                            radius: 6
                            color: window.lightMode ? "white" : "#111111"
                            border.color: window.lightMode ? "#cccccc" : "#444444"
                            border.width: 1
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        text: "Data do:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 11
                    }
                    TextField {
                        id: endDateInput
                        text: "2026-10-11T23:00:00"
                        placeholderText: "np. 2026-10-11T23:00:00"
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        padding: 8
                        background: Rectangle {
                            radius: 6
                            color: window.lightMode ? "white" : "#111111"
                            border.color: window.lightMode ? "#cccccc" : "#444444"
                            border.width: 1
                        }
                    }
                }

                Button {
                    id: downloadButton
                    text: copernicusManager.isDownloading ? "Pobieranie..." : "Pobierz pliki CSV"
                    enabled: !copernicusManager.isDownloading
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                    font.pixelSize: 11
                    padding: 10
                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }
                    onClicked: {
                        copernicusManager.startBatchDownload(startDateInput.text, endDateInput.text, 1)
                    }
                }

                ProgressBar {
                    Layout.fillWidth: true
                    value: copernicusManager.progress / 100.0
                }
            }

            function showError(message, color) {
                errorToast.show(message, color)
            }
        }

        Rectangle {
            id: rectangle2
            color: window.lightMode ? window.light : window.dark

            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: 50

            Map {
                id: map
                anchors.fill: parent
                copyrightsVisible: false

                plugin: Plugin {
                    name: "osm"
                }

                center: QtPositioning.coordinate(50.0, 16.0)

                property real targetZoom: 4
                zoomLevel: targetZoom

                Behavior on zoomLevel {
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                property real minZoom: 4
                property real maxZoom: 8

                onZoomLevelChanged: {
                    if (map.targetZoom < minZoom) {
                        map.targetZoom = minZoom
                    }
                    else if (map.targetZoom > maxZoom) {
                        map.targetZoom = maxZoom
                    }
                    mapMouseArea.keepInsideBounds()
                }

                property var markerCoordinate: null

                onMarkerCoordinateChanged: {
                    if (markerCoordinate !== null) {
                        latInput.text = markerCoordinate.latitude.toFixed(5)
                        lonInput.text = markerCoordinate.longitude.toFixed(5)
                    }
                }

                MapQuickItem {
                    id: marker
                    coordinate: map.markerCoordinate
                    visible: map.markerCoordinate !== null
                    anchorPoint.x: markerImage.width / 2
                    anchorPoint.y: markerImage.height / 2

                    sourceItem: Rectangle {
                        id: markerImage
                        width: 16
                        height: 16
                        radius: 10
                        color: "white"
                        border.width: 1
                        border.color: "black"
                    }
                }

                MouseArea {
                    id: mapMouseArea
                    anchors.fill: parent

                    property real lastX: 0
                    property real lastY: 0
                    property real pressX: 0
                    property real pressY: 0
                    property bool hasDragged: false

                    property real northLimit: 71.8
                    property real southLimit: 29.9
                    property real westLimit: -11.0
                    property real eastLimit: 42.4

                    function isInsideBounds(coordinate) {
                        return coordinate.latitude >= southLimit &&
                               coordinate.latitude <= northLimit &&
                               coordinate.longitude >= westLimit &&
                               coordinate.longitude <= eastLimit
                    }

                    function keepInsideBounds() {
                        var tl = map.toCoordinate(Qt.point(0, 0))
                        var br = map.toCoordinate(Qt.point(map.width, map.height))

                        var north = tl.latitude
                        var south = br.latitude
                        var west = tl.longitude
                        var east = br.longitude

                        var correctionLat = 0
                        var correctionLon = 0

                        if (north > northLimit && south < southLimit)
                            correctionLat = (northLimit + southLimit) / 2 - (north + south) / 2
                        else if (north > northLimit)
                            correctionLat = northLimit - north
                        else if (south < southLimit)
                            correctionLat = southLimit - south

                        if (east > eastLimit && west < westLimit)
                            correctionLon = (westLimit + eastLimit) / 2 - (west + east) / 2
                        else if (east > eastLimit)
                            correctionLon = eastLimit - east
                        else if (west < westLimit)
                            correctionLon = westLimit - west

                        if (correctionLat || correctionLon) {
                            var center = map.center
                            center.latitude += correctionLat
                            center.longitude += correctionLon
                            map.center = center
                        }
                    }

                    onWheel: function(event) {
                        if (event.angleDelta.y > 0) {
                            map.targetZoom += 0.25
                        } else {
                            map.targetZoom -= 0.25
                        }
                    }

                    onPressed:(mouse)=> {
                        pressX = mouse.x
                        pressY = mouse.y
                        hasDragged = false
                        lastX = mouse.x
                        lastY = mouse.y
                    }

                    onPositionChanged:(mouse)=> {
                        if (!pressed)
                            return

                        if (Math.abs(mouse.x - pressX) > 5 || Math.abs(mouse.y - pressY) > 5) {
                            hasDragged = true
                        }

                        var dx = lastX - mouse.x
                        var dy = lastY - mouse.y

                        map.pan(dx, dy)
                        keepInsideBounds()

                        lastX = mouse.x
                        lastY = mouse.y
                    }

                    onReleased:(mouse)=> {
                        if (!hasDragged) {
                            var coordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y))
                            if (isInsideBounds(coordinate)){
                                map.markerCoordinate = coordinate
                            }
                        }
                    }
                }

                Button {
                    id: zoomIn
                    text: "+"
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 32
                    anchors.rightMargin: 8

                    onClicked: {
                        map.targetZoom += 1
                    }

                    background: Rectangle {
                        topLeftRadius: 8
                        topRightRadius: 8
                        color: zoomIn.hovered
                               ? (window.lightMode ? "#c8c8c8" : "#3a3a3a")
                               : (window.lightMode ? window.light : window.dark)
                    }
                }

                Rectangle {
                    id: zoomDivider
                    width: 24 - 8
                    height: 2
                    anchors.right: parent.right
                    anchors.rightMargin: 8 + 4
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 32 - 1
                    color: window.lightMode ? "#cccccc" : "#444444"
                }

                Button {
                    id: zoomOut
                    text: "−"
                    width: 24
                    height: 24
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.rightMargin: 8

                    onClicked: {
                        map.targetZoom -= 1
                    }

                    background: Rectangle {
                        bottomLeftRadius: 8
                        bottomRightRadius: 8
                        color: zoomOut.hovered
                               ? (window.lightMode ? "#c8c8c8" : "#3a3a3a")
                               : (window.lightMode ? window.light : window.dark)
                    }
                }

                Label {
                    id: zoom
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Zoom: " + (map.targetZoom / 4).toFixed(2) + "x"
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 40
                    anchors.leftMargin: 10
                }

                Label {
                    id: latitude
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Lat.: " + map.center.latitude.toFixed(5)
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    anchors.leftMargin: 10
                }

                Label {
                    id: longitude
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Lon.: " + map.center.longitude.toFixed(5)
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.leftMargin: 10
                }
            }

            Rectangle {
                id: errorToast
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8

                width: errorMessage.width + 46
                height: Math.max(errorMessage.implicitHeight, 10) + 16

                radius: 8
                color: window.dark
                visible: false
                opacity: 0

                function show(message, color) {
                    errorFade.stop()
                    errorTimer.stop()

                    errorMessage.text = message
                    statusDot.color = color
                    errorToast.opacity = 1
                    errorToast.visible = true

                    errorTimer.start()
                }

                TextMetrics {
                    id: textMetrics
                    font: errorMessage.font
                    text: errorMessage.text
                }

                Rectangle {
                    id: statusDot
                    width: 10
                    height: 10
                    radius: 5
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    id: errorMessage
                    color: "white"
                    anchors.left: statusDot.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(Math.ceil(textMetrics.advanceWidth) + 4,
                                    Math.max(120, rectangle2.width - 200))
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 11
                }

                Timer {
                    id: errorTimer
                    interval: 2500
                    repeat: false
                    onTriggered: errorFade.start()
                }

                NumberAnimation {
                    id: errorFade
                    target: errorToast
                    property: "opacity"
                    to: 0
                    duration: 500
                    easing.type: Easing.InOutQuad
                    onFinished: errorToast.visible = false
                }
            }
        }
    }
}