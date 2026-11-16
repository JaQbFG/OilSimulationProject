import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtLocation
import QtPositioning

ApplicationWindow {
    id: window
    width: 850
    height: 550
    minimumWidth: 200
    minimumHeight: 250
    visible: true
    title: qsTr("Oil Simulation")
    property real lastLoggedTime: -1
    property bool lightMode: Application.styleHints.colorScheme === Qt.Light
    property bool checking: false
    property bool pointChecked: false
    property bool pointConfirmed: false
    property real spillVolumeML: 0
    property real leakRateM3h: 0
    
    property bool datesLocked: false
    property bool loadingInitialData: false
    property bool initialDataLoaded: false
    property bool pointLocked: false
    
    property color reallyDark: "#1f1f1f"
    property color dark: "#262626"
    property color reallyLight: "#e7e7e7"
    property color light: "#e0e0e0"

    property color error: "red"
    property color warning: "#c97a00"
    property color success: "#2e8b57"

    property string statusText: ""

    Timer {
        id: liveTimer
        interval: 1000
        repeat: true
        running: oilSimulation.running
        onTriggered: map.finalPositions = oilSimulation.particlePositions()
    }

    Connections {
        target: copernicusManager

        function onLocationCheckFinished(success, isLand, message) {
            errorToast.hideBusy()
            console.log("locationCheckFinished:", success, isLand, message)
            window.checking = false

            if (!success) {
                errorToast.hideBusy()
                window.pointChecked = false
                rectangle1.showError(message, window.error)
                return
            }

            if (isLand) {
                window.pointChecked = false
                rectangle1.showError(message, window.warning)
                return
            }

            window.pointChecked = true
            window.statusText = "Wybrano wodę. Podaj ilość ropy i potwierdź punkt."
            rectangle1.showError("Punkt znajduje się na wodzie.", window.success)
        }

        function onProgressChanged() {
            if (copernicusManager.isDownloading)
                errorToast.showBusy("Pobieranie danych... " + copernicusManager.progress + "%", true)
        }

        function onDownloadFinished(success, message) {
            errorToast.hideBusy()
            console.log("Download:", success, message)
            errorToast.show(message, success ? window.success : window.error)
        }
        function onInitialSurfaceDataLoaded(success, message) {
            errorToast.hideBusy()
            console.log(
                "[INITIAL DATA]",
                "success =", success,
                "message =", message
            )

            window.loadingInitialData = false

            if (!success) {
                window.datesLocked = false
                window.initialDataLoaded = false

                rectangle1.showError(message, "red")
                return
            }

            window.datesLocked = true
            window.initialDataLoaded = true

            console.log(
                "[INITIAL DATA] Gotowe. Można wybierać punkt."
            )

            rectangle1.showError(
                message,
                "#2e8b57"
            )
        }
        function onLogMessage(message) {
            console.log("[CopernicusManager]", message)
        }
        function onBathymetryLoaded(success, seabedDepth, message) {
            if (!success) {
                window.pointLocked = false
                window.statusText = "Nie udało się pobrać batymetrii."
                rectangle1.showError(message, window.error)
                return
            }
        }

        function onUnderwaterDataLoaded(time, success, message) {
            errorToast.hideBusy()
            if (!success) {
                if (!window.pointConfirmed)
                    window.pointLocked = false
                rectangle1.showError(message, window.error)
                return
            }
            if (window.pointConfirmed)
                return
            window.pointConfirmed = true
            rectangle1.showError("Punkt potwierdzony. Start symulacji.", window.success)

            oilSimulation.reset()
            map.finalPositions = []


            var runSeconds = (Date.parse(endDateInput.text + "Z")
                              - Date.parse(startDateInput.text + "Z")) / 1000 + 3600

            oilSimulation.spillLatitude = map.markerCoordinate.latitude
            oilSimulation.spillLongitude = map.markerCoordinate.longitude
            oilSimulation.spillVolumeLiters = window.spillVolumeML * 1000000
            oilSimulation.leakRateLitersPerHour = window.leakRateM3h * 1000
            oilSimulation.blobVolumeLiters = 1000
            oilSimulation.releaseDuration = runSeconds
            oilSimulation.timeStep = 900
            oilSimulation.releaseDepth = copernicusManager.seabedDepth()
            oilSimulation.riseSpeed = 0.2
            oilSimulation.start()
        }

    }
    Connections {
        target: oilSimulation

        function onFinished() {
            map.finalPositions = oilSimulation.particlePositions()
            rectangle1.showError("Symulacja zakończona. Cząsteczek: " + map.finalPositions.length,
                                 window.success)
        }
    }
    Connections {
        target: oilSimulation
        function onParticleEvent(id, lat, lon, simSeconds, timeUtc, state) {
            console.log("Cząsteczka #" + id,
                        state === 1 ? "osiadła na brzegu" : "opuściła obszar",
                        "| lat", lat.toFixed(5), "lon", lon.toFixed(5),
                        "|", timeUtc, "UTC | t =", Math.round(simSeconds / 60), "min")
        }
        function onLogMessage(message) {
            console.log("[Simulation]", message)
        }
        function onStepped() {
            window.statusText = "Symulacja: " + (oilSimulation.elapsedSeconds / 3600).toFixed(2)
                                  + " h | cząsteczek: " + oilSimulation.particleCount
                                  + " / " + oilSimulation.totalParticles
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
                        enabled: window.initialDataLoaded && !window.pointLocked
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
                        enabled: window.initialDataLoaded && !window.pointLocked
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
                        text: "Ilość ropy [mln]:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 11
                    }
                    TextField {
                        id: volumeInput
                        placeholderText: "Np. 1.5"
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        padding: 8
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        enabled: window.pointChecked && !window.pointLocked
                        opacity: enabled ? 1.0 : 0.5
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
                        text: "Wyciek [m³/h]:"
                        color: window.lightMode ? window.dark : window.light
                        font.pixelSize: 11
                    }
                    TextField {
                        id: leakInput
                        placeholderText: "Np. 100"
                        Layout.fillWidth: true
                        font.pixelSize: 11
                        padding: 8
                        inputMethodHints: Qt.ImhFormattedNumbersOnly
                        enabled: window.pointChecked && !window.pointLocked
                        opacity: enabled ? 1.0 : 0.5
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
                    enabled: window.initialDataLoaded && !window.pointLocked
                    background: Rectangle {
                        radius: 6
                        color: window.lightMode ? "white" : "#333333"
                        border.color: window.lightMode ? "#cccccc" : "#444444"
                        border.width: 1
                    }

                    onClicked: {
                        if (latInput.text.trim() === "" || lonInput.text.trim() === "") {
                            rectangle1.showError("Pola nie mogą być puste!", window.error)
                            return
                        }

                        var latitude = Number(latInput.text.replace(",", "."))
                        var longitude = Number(lonInput.text.replace(",", "."))

                        if (!isFinite(latitude) || !isFinite(longitude)) {
                            rectangle1.showError("Podaj prawidłowe współrzędne!", window.error)
                            return
                        }

                        if (latitude < mapMouseArea.southLimit ||
                            latitude > mapMouseArea.northLimit ||
                            longitude < mapMouseArea.westLimit ||
                            longitude > mapMouseArea.eastLimit) {
                            rectangle1.showError("Marker jest poza dozwolonym obszarem!", window.error)
                            return
                        }

                        var current = map.markerCoordinate

                        if (current !== null &&
                            Math.abs(current.latitude - latitude) < 0.00001 &&
                            Math.abs(current.longitude - longitude) < 0.00001) {
                            return   // same point: keep the check result
                        }

                        map.markerCoordinate = QtPositioning.coordinate(latitude, longitude)
                    }
                }

                Button {
                    text: window.checking ? "Sprawdzanie..." : window.pointConfirmed ? "Punkt potwierdzony" : window.pointChecked ? "Potwierdź punkt" : "Sprawdź punkt"
                    enabled: window.initialDataLoaded
                             && !window.checking
                             && !copernicusManager.isDownloading
                             && !window.pointLocked
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
                        console.log("Kliknięto Zatwierdź | pointChecked =", window.pointChecked,
                                    "| volume =", volumeInput.text)

                        if (map.markerCoordinate === null) {
                            rectangle1.showError("Najpierw wybierz lokalizację!", window.error)
                            return
                        }
                        if (window.pointChecked) {
                        var volume = Number(volumeInput.text.replace(",", "."))
                        if (volumeInput.text.trim() === "" || !isFinite(volume) || volume <= 0) {
                            rectangle1.showError("Podaj prawidłową ilość ropy (mln litrów)!", window.error)
                            return
                        }
                            var leak = Number(leakInput.text.replace(",", "."))
                            if (leakInput.text.trim() === "" || !isFinite(leak) || leak <= 0) {
                                rectangle1.showError("Podaj prawidłowy wyciek (m³/h)!", window.error)
                                return
                            }
                            window.leakRateM3h = leak
                            window.spillVolumeML = volume

                            errorToast.showBusy("Pobieranie batymetrii...", false)
                            copernicusManager.prepareUnderwaterData(
                                map.markerCoordinate.latitude, map.markerCoordinate.longitude,
                                startDateInput.text, endDateInput.text)
                        } else {
                            window.checking = true
                            errorToast.showBusy("Sprawdzanie lokalizacji...", false)
                            copernicusManager.checkLocation(
                                map.markerCoordinate.latitude, map.markerCoordinate.longitude)
                        }
                    }
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
                        enabled: !window.datesLocked && !window.loadingInitialData
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
                        enabled: !window.datesLocked && !window.loadingInitialData
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
                    text: window.loadingInitialData
                          ? "Pobieranie i wczytywanie..."
                          : window.initialDataLoaded
                            ? "Dane gotowe"
                            : "Zatwierdź daty i pobierz pierwszy plik"

                    enabled: !window.loadingInitialData
                             && !window.initialDataLoaded
                             && !copernicusManager.isDownloading
                             && !window.checking

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
                        var startText = startDateInput.text.trim()
                        var endText = endDateInput.text.trim()

                        var pattern =
                            /^\d{4}-\d{2}-\d{2}T\d{2}:00:00$/

                        if (!pattern.test(startText) ||
                            !pattern.test(endText)) {
                            rectangle1.showError(
                                "Podaj daty w formacie YYYY-MM-DDTHH:00:00.",
                                "red"
                            )
                            return
                        }

                        var startMs = Date.parse(startText)
                        var endMs = Date.parse(endText)

                        if (!isFinite(startMs) ||
                            !isFinite(endMs) ||
                            startMs > endMs) {
                            rectangle1.showError(
                                "Nieprawidłowy zakres dat.",
                                "red"
                            )
                            return
                        }

                        window.datesLocked = true
                        window.loadingInitialData = true
                        errorToast.showBusy("Pobieranie danych...", false)
                        copernicusManager.prepareSurfaceData(
                            startText,
                            endText,
                            1
                        )
                    }
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
                    PluginParameter
                    {
                    name: "osm.mapping.custom.host"
                    value: "https://tile.openstreetmap.org/"
                    }
                }
                activeMapType: map.supportedMapTypes [map.supportedMapTypes.length-1]

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
                property real maxZoom: 16

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
                property var finalPositions: []

                MapItemView {
                    model: map.finalPositions

                    delegate: MapQuickItem {
                        coordinate: QtPositioning.coordinate(modelData.lat, modelData.lon)
                        anchorPoint.x: 3
                        anchorPoint.y: 3

                        sourceItem: Rectangle {
                            width: 6
                            height: 6
                            radius: 3
                            border.width: 1
                            color: modelData.state === 1 ? "#e03131"
                                 : modelData.state === 2 ? "#868e96"
                                 : modelData.depth > 0.494 ? "#339af0"
                                 : "#212529"
                        }
                    }
                }
                onMarkerCoordinateChanged: {
                    console.log("[MARKER] changed ->",
                                markerCoordinate ? markerCoordinate.latitude + ", " + markerCoordinate.longitude : "null")
                    if (markerCoordinate !== null) {
                        latInput.text = markerCoordinate.latitude.toFixed(5)
                        lonInput.text = markerCoordinate.longitude.toFixed(5)
                    }
                    window.pointChecked = false
                    window.statusText = ""
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
                           if (window.pointLocked) return
                           if (!window.initialDataLoaded) {
                               rectangle1.showError(
                                   "Najpierw zatwierdź daty i pobierz dane.",
                                   "red"
                               )
                               return
                           }
                            var coordinate = map.toCoordinate(Qt.point(mouse.x, mouse.y))
                                       console.log(
                                           "[MAP] Kliknięto:",
                                           coordinate.latitude,
                                           coordinate.longitude
                                       )

                                       if (isInsideBounds(coordinate)) {
                                           map.markerCoordinate = coordinate

                                           console.log("[MAP] Ustawiono marker")
                                       } else {
                                           rectangle1.showError(
                                               "Kliknięty punkt jest poza dozwolonym obszarem mapy.",
                                               "#c97a00"
                                           )
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
                id: statusBar
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(Math.max(200, Math.ceil(statusMetrics.advanceWidth) + 24),
                                parent.width - 16)
                height: statusLabel.implicitHeight + 12
                radius: 8
                color: window.dark
                visible: window.statusText !== ""

                TextMetrics {
                    id: statusMetrics
                    font: statusLabel.font
                    text: window.statusText
                }

                Label {
                    id: statusLabel
                    anchors.centerIn: parent
                    width: parent.width - 24
                    text: window.statusText
                    color: "white"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }
            }

            ListModel { id: toastModel }

            Column {
                id: errorToast
                clip: false
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0

                readonly property int maxToasts: 5

                function makeRoom() {
                    var normal = 0
                    for (var i = 0; i < toastModel.count; i++) {
                        if (!toastModel.get(i).busy)
                            normal++
                    }
                    if (normal < maxToasts)
                        return
                    for (var j = 0; j < toastModel.count; j++) {
                        if (!toastModel.get(j).busy) {
                            toastModel.remove(j)
                            return
                        }
                    }
                }

                function show(message, color) {
                    makeRoom()
                    toastModel.append({ message: message, dotColor: String(color),
                                        busy: false, showProgress: false })
                }

                function showBusy(message, withProgress) {
                    for (var i = 0; i < toastModel.count; i++) {
                        if (toastModel.get(i).busy) {
                            toastModel.setProperty(i, "message", message)
                            toastModel.setProperty(i, "showProgress", withProgress === true)
                            return
                        }
                    }
                    toastModel.append({ message: message, dotColor: "white",
                                        busy: true, showProgress: withProgress === true })
                }

                function hideBusy() {
                    for (var i = toastModel.count - 1; i >= 0; i--) {
                        if (toastModel.get(i).busy)
                            toastModel.remove(i)
                    }
                }

                Repeater {
                    model: toastModel

                    delegate: Item {
                        id: row
                        required property int index
                        required property string message
                        required property string dotColor
                        required property bool busy
                        required property bool showProgress

                        property real collapse: 0

                        width: errorToast.width
                        height: (toast.height + 6) * collapse

                        Component.onCompleted: growIn.start()

                        NumberAnimation {
                            id: growIn
                            target: row
                            property: "collapse"
                            to: 1
                            duration: 250
                            easing.type: Easing.OutCubic
                        }

                        Rectangle {
                            id: toast
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            width: msg.width + 34
                            height: Math.max(msg.implicitHeight, 14) + 12 + (row.showProgress ? 9 : 0)
                            radius: 8
                            color: window.dark
                            opacity: 0

                            Component.onCompleted: opacity = 1
                            Behavior on opacity { NumberAnimation { duration: 100 } }

                            Timer {
                                interval: 5000
                                running: !row.busy
                                onTriggered: fadeOut.start()
                            }

                            SequentialAnimation {
                                id: fadeOut

                                NumberAnimation {
                                    target: toast
                                    property: "opacity"
                                    to: 0
                                    duration: 500
                                    easing.type: Easing.InOutQuad
                                }
                                NumberAnimation {
                                    target: row
                                    property: "collapse"
                                    to: 0
                                    duration: 250
                                    easing.type: Easing.OutCubic
                                }
                                ScriptAction {
                                    script: toastModel.remove(row.index)
                                }
                            }

                            TextMetrics {
                                id: metrics
                                font: msg.font
                                text: row.message
                            }

                            Item {
                                id: indicator
                                width: 14
                                height: 14
                                anchors.left: parent.left
                                anchors.leftMargin: 8
                                anchors.top: parent.top
                                anchors.topMargin: 6.5

                                Rectangle {
                                    width: 10
                                    height: 10
                                    radius: 5
                                    anchors.centerIn: parent
                                    color: row.dotColor
                                    visible: !row.busy
                                }

                                Item {
                                    id: spinner
                                    anchors.fill: parent
                                    visible: row.busy

                                    Canvas {
                                        anchors.fill: parent
                                        antialiasing: true
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            ctx.lineWidth = 2
                                            ctx.lineCap = "round"
                                            var cx = width / 2
                                            var cy = height / 2
                                            var r = width / 2 - 1.5

                                            ctx.strokeStyle = "rgba(255, 255, 255, 0.2)"
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, 0, Math.PI * 2)
                                            ctx.stroke()

                                            ctx.strokeStyle = "white"
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, 0, Math.PI * 0.75)
                                            ctx.stroke()
                                        }
                                    }

                                    RotationAnimator {
                                        target: spinner
                                        from: 0
                                        to: 360
                                        duration: 800
                                        loops: Animation.Infinite
                                        running: row.busy
                                    }
                                }
                            }

                            Label {
                                id: msg
                                text: row.message
                                color: "white"
                                anchors.left: indicator.right
                                anchors.leftMargin: 6
                                anchors.top: parent.top
                                anchors.topMargin: 6
                                width: Math.min(Math.ceil(metrics.advanceWidth) + 4,
                                                Math.max(120, rectangle2.width - 200))
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignLeft
                                font.pixelSize: 11
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                anchors.bottomMargin: 6
                                height: 3
                                radius: 1.5
                                color: "#444444"
                                visible: row.showProgress

                                Rectangle {
                                    height: parent.height
                                    radius: parent.radius
                                    width: parent.width * Math.min(1, copernicusManager.progress / 100.0)
                                    color: "#2e8b57"
                                    Behavior on width {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}