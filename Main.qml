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
            Layout.preferredWidth: 3

            ColumnLayout {
                anchors.fill: parent
                Layout.alignment: Qt.AlignHCenter | Qt.AlignTop

                Label {
                    visible: map.markerCoordinate == null

                    id: text1
                    text: qsTr("Pick a location")
                    color: window.lightMode ? window.dark : window.light

                    font.pixelSize: 24
                    fontSizeMode: Text.Fit
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                Label {
                    visible: map.markerCoordinate !== null

                    id: markerInfo
                    text: map.markerCoordinate === null ? "" : "Dł: " + map.markerCoordinate.longitude.toFixed(5) + "\nSz: " + map.markerCoordinate.latitude.toFixed(5)
                    color: window.lightMode ? window.dark : window.light

                    font.pixelSize: 24
                    fontSizeMode: Text.Fit
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Rectangle {
            id: rectangle2
            color: window.lightMode ? window.light : window.dark
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.preferredWidth: 7

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
                    id: longitude
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Dł: " + map.center.longitude.toFixed(5) + ""
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 24
                    anchors.leftMargin: 10
                }

                Label {
                    id: latitude
                    color: window.lightMode ? window.light : window.dark
                    font.pixelSize: 12
                    fontSizeMode: Text.Fit
                    text: "Sz: " + map.center.latitude.toFixed(5) + ""
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
