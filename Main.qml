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
    property color reallyDark: "#1f1f1f"
    property color dark: "#262626"
    property color reallyLight: "#e7e7e7"
    property color light: "#e0e0e0"

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

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter

                    Label {
                        id: latLabel
                        text: "Sz.:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 16
                        fontSizeMode: Text.Fit
                        Layout.preferredWidth: 20
                        Layout.fillHeight: true
                        Layout.margins: 8
                        horizontalAlignment: Text.AlignHLeft
                        verticalAlignment: Text.AlignVCenter

                    }
                    TextField {
                        id: latInput
                        placeholderText: "Podaj szerokośc..."

                        Layout.fillWidth: true
                        font.pixelSize: 12

                        padding: 10

                        background: Rectangle {
                            radius: 6
                            color: window.lightMode ? "white" : "#111111"
                            border.color: window.lightMode ? "#cccccc" : "#444444"
                            border.width: 1
                        }
                    }
                }

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter

                    Label {
                        id: lonLabel
                        text: "Dł.:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 16
                        fontSizeMode: Text.Fit
                        Layout.preferredWidth: 20
                        Layout.fillHeight: true
                        Layout.margins: 8
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    TextField {
                        id: lonInput
                        placeholderText: "Podaj długość..."

                        Layout.fillWidth: true
                        font.pixelSize: 12

                        padding: 10

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
                    Layout.topMargin: 2
                    Layout.bottomMargin: 8
                    padding: 10

                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }

                    onClicked: {
                        if (latInput.text.trim() === "" ||
                            lonInput.text.trim() === "") {

                            rectangle1.showError("Pola nie mogą być puste!")
                            return
                        }

                        var latitude = Number(latInput.text.replace(",", "."))
                        var longitude = Number(lonInput.text.replace(",", "."))

                        if (!isFinite(latitude) || !isFinite(longitude)) {
                            rectangle1.showError("Podaj prawidłowe współrzędne!")
                            return
                        }

                        if (latitude < mapMouseArea.southLimit ||
                            latitude > mapMouseArea.northLimit ||
                            longitude < mapMouseArea.westLimit ||
                            longitude > mapMouseArea.eastLimit) {

                            rectangle1.showError("Marker jest poza dozwolonym obszarem!")
                            return
                        }

                        map.markerCoordinate = QtPositioning.coordinate(latitude, longitude)
                    }
                }
            }

            Label {
                id: errorMessage

                text: ""

                width: parent.width - 32

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                wrapMode: Text.WordWrap

                color: "red"
                font.pixelSize: 10

                visible: false
                opacity: 0
            }

            Timer {
                id: errorTimer
                interval: 2500
                repeat: false

                onTriggered: {
                    errorFade.start()
                }
            }

            NumberAnimation {
                id: errorFade

                target: errorMessage
                property: "opacity"
                to: 0
                duration: 500
                easing.type: Easing.InOutQuad

                onFinished: {
                    errorMessage.visible = false
                }
            }

            function showError(message) {
                errorFade.stop()
                errorTimer.stop()

                errorMessage.text = message
                errorMessage.opacity = 1
                errorMessage.visible = true

                errorTimer.start()
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
                copyrightsVisible : false

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

                    onPressed: {
                        pressX = mouse.x
                        pressY = mouse.y

                        hasDragged = false

                        lastX = mouse.x
                        lastY = mouse.y
                    }

                    onPositionChanged: {
                        if (!pressed)
                            return

                        if (Math.abs(mouse.x - pressX) > 5 || Math.abs(mouse.y - pressY) > 5) {
                            hasDragged = true
                        }

                        var dx = lastX - mouse.x
                        var dy = lastY - mouse.y

                        map.pan(dx, dy)

                        var center = map.center

                        keepInsideBounds()

                        lastX = mouse.x
                        lastY = mouse.y
                    }

                    onReleased: {
                        if (!hasDragged) {
                            var coordinate = map.toCoordinate(
                                Qt.point(mouse.x, mouse.y)
                            )

                            if (isInsideBounds(coordinate)){
                                map.markerCoordinate = coordinate
                            }
                        }
                    }
                }

                Button {
                    id:zoomIn
                    text: "+"
                    width: 30
                    height: 30
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 42
                    anchors.margins: 8

                    onClicked: {
                        map.targetZoom += 1
                    }

                    background: Rectangle {
                        radius: 8
                        color: window.lightMode ? window.light : window.dark
                    }
                }

                Button {
                    id: zoomOut
                    text: "−"
                    width: 30
                    height: 30
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.rightMargin: 8

                    onClicked: {
                        map.targetZoom -= 1
                    }

                    background: Rectangle {
                        radius: 8
                        color: window.lightMode ? window.light : window.dark
                    }
                }

                Label {
                    id: zoom
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Przybliżenie: " + map.targetZoom.toFixed(1) / 4 + "x"
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.rightMargin: 46
                }

                Label {
                    id: latitude
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Sz.: " + map.center.latitude.toFixed(5) + ""
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
                    text: "Dł.: " + map.center.longitude.toFixed(5) + ""
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.leftMargin: 10
                }
            }

            // Nie wiem czy będziesz chcial ten przycisk mieć, więc komentuje na razie :DD

            // ColumnLayout {
            //     anchors.fill: parent
            //     Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

            //     Button {
            //         id: button1
            //         text: window.lightMode ? qsTr("\u263D  Dark mode")
            //                                : qsTr("\u263C  Light mode")
            //         Layout.bottomMargin: 16
            //         Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom

            //         contentItem: Text {
            //             text: button1.text
            //             color: window.lightMode ? window.light : window.dark
            //             font: button1.font
            //             horizontalAlignment: Text.AlignHCenter
            //             verticalAlignment: Text.AlignVCenter
            //         }

            //         background: Rectangle {
            //             implicitWidth: 120
            //             implicitHeight: 36
            //             radius: 8
            //             color: window.lightMode ? window.dark : window.light
            //         }

            //         onClicked: window.lightMode = !window.lightMode
            //     }
            // }
        }
    }

}
