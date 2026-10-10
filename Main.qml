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
                spacing: 6

                RowLayout {
                    Layout.alignment: Qt.AlignHCenter
                    Label {
                        text: "Sz.:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 16
                        Layout.preferredWidth: 20
                        Layout.fillHeight: true
                        Layout.margins: 8
                    }
                    TextField {
                        id: latInput
                        placeholderText: "Podaj szerokość..."
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
                        text: "Dł.:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 16
                        Layout.preferredWidth: 20
                        Layout.fillHeight: true
                        Layout.margins: 8
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
                    Layout.bottomMargin: 4
                    padding: 10
                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }
                    onClicked: {
                        if (latInput.text.trim() === "" || lonInput.text.trim() === "") {
                            rectangle1.showError("Pola nie mogą być puste!")
                            return
                        }
                        var latitude = Number(latInput.text.replace(",", "."))
                        var longitude = Number(lonInput.text.replace(",", "."))
                        if (!isFinite(latitude) || !isFinite(longitude)) {
                            rectangle1.showError("Podaj prawidłowe współrzędne!")
                            return
                        }
                        map.markerCoordinate = QtPositioning.coordinate(latitude, longitude)
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: window.lightMode ? "#cccccc" : "#444444"
                    Layout.topMargin: 8
                    Layout.bottomMargin: 8
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
                    text: CopernicusManager.isDownloading ? "Pobieranie..." : "Pobierz pliki CSV"
                    enabled: !CopernicusManager.isDownloading
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    padding: 10
                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }
                    onClicked: {
                        CopernicusManager.startBatchDownload(startDateInput.text, endDateInput.text, 1)
                    }
                }

                ProgressBar {
                    Layout.fillWidth: true
                    value: CopernicusManager.progress / 100.0
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
                onTriggered: errorFade.start()
            }

            NumberAnimation {
                id: errorFade
                target: errorMessage
                property: "opacity"
                to: 0
                duration: 500
                onFinished: errorMessage.visible = false
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
                copyrightsVisible: false
                plugin: Plugin { name: "osm" }
                center: QtPositioning.coordinate(50.0, 16.0)
                zoomLevel: 4

                property var markerCoordinate: null
                onMarkerCoordinateChanged: {
                    if (markerCoordinate !== null) {
                        latInput.text = markerCoordinate.latitude.toFixed(5)
                        lonInput.text = markerCoordinate.longitude.toFixed(5)
                    }
                }

                MapQuickItem {
                    coordinate: map.markerCoordinate
                    visible: map.markerCoordinate !== null
                    anchorPoint.x: markerImage.width / 2
                    anchorPoint.y: markerImage.height / 2
                    sourceItem: Rectangle {
                        id: markerImage
                        width: 16; height: 16; radius: 10
                        color: "white"; border.width: 1; border.color: "black"
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onReleased: (mouse) => {
                        var coordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y))
                        map.markerCoordinate = coordinate
                    }
                }
            }
        }
    }
}