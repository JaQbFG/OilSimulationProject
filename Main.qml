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
    property real lastLoggedTime: -1
    property bool lightMode: Application.styleHints.colorScheme === Qt.Light
    property bool checking: false
    property bool pointChecked: false
    property bool pointConfirmed: false
    
    property bool datesLocked: false
    property bool loadingInitialData: false
    property bool initialDataLoaded: false
    
    property color reallyDark: "#1f1f1f"
    property color dark: "#262626"
    property color reallyLight: "#e7e7e7"
    property color light: "#e0e0e0"

    property color error: "red"
    property color warning: "#c97a00"
    property color success: "#2e8b57"

    Connections {
        target: copernicusManager

        function onLocationCheckFinished(success, isLand, message) {
            console.log("locationCheckFinished:", success, isLand, message)
            window.checking = false

            if (!success) {
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
            locationStatus.text = "Wybrano wodę. Potwierdź punkt."
            rectangle1.showError("Punkt znajduje się na wodzie.", window.success)
        }

        function onProgressChanged() {
            if (copernicusManager.isDownloading)
                errorToast.showBusy("Pobieranie danych... " + copernicusManager.progress + "%", true)
        }

        function onDownloadFinished(success, message) {
            console.log("Download:", success, message)
            errorToast.show(message, success ? window.success : window.error)
        }
        function onInitialSurfaceDataLoaded(success, message) {
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
                locationStatus.text = "Nie udało się pobrać batymetrii."
                rectangle1.showError(message, window.error)
                return
            }
            locationStatus.text = "Głębokość dna: " + seabedDepth.toFixed(2) + " m"
        }

        function onUnderwaterDataLoaded(time, success, message) {
            if (!success) {
                rectangle1.showError(message, window.error)
                return
            }
            if (window.pointConfirmed)
                return
            window.pointConfirmed = true
            rectangle1.showError("Punkt potwierdzony. Start symulacji.", window.success)

            oilSimulation.reset()
            oilSimulation.spillLatitude = map.markerCoordinate.latitude
            oilSimulation.spillLongitude = map.markerCoordinate.longitude
            oilSimulation.timeStep = 450 //how often positions get updated
            oilSimulation.releaseRate = 60 //seconds for 1 particle
            oilSimulation.releaseDepth = copernicusManager.seabedDepth()
            oilSimulation.riseSpeed = 0.2 //how fast the oil rises
            oilSimulation.start()
        }

    }
    Connections {
        target: oilSimulation

        function onStepped() {
            var t = oilSimulation.elapsedSeconds

            if (t === 0) {
                window.lastLoggedTime = -1
                return
            }

            if (t - window.lastLoggedTime < 900)
                return

            window.lastLoggedTime = t

            var list = oilSimulation.particlePositions()
            var states = ["pływa", "osiadła", "poza obszarem"]
            var maxLogged = 20//logged particles

            console.log("=== t =", Math.round(t / 60), "min | cząsteczek:", list.length)

            for (var i = 0; i < Math.min(list.length, maxLogged); i++) {
                console.log("  #" + i,
                            list[i].lat.toFixed(5),
                            list[i].lon.toFixed(5),
                            states[list[i].state],
                            list[i].depth.toFixed(1) + " m")
            }
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
                        enabled: window.initialDataLoaded
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
                        enabled: window.initialDataLoaded
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
                    enabled: window.initialDataLoaded && !window.pointConfirmed
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

                        map.markerCoordinate = QtPositioning.coordinate(latitude, longitude)
                    }
                }

                Button {
                    text: window.checking ? "Sprawdzanie..." : window.pointConfirmed ? "Punkt potwierdzony" : window.pointChecked ? "Potwierdź punkt" : "Sprawdź punkt"
                    enabled: window.initialDataLoaded
                             && !window.checking
                             && !copernicusManager.isDownloading
                             && !window.pointConfirmed
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
                            rectangle1.showError("Najpierw wybierz lokalizację!", window.error)
                            return
                        }
                        if (window.pointChecked) {
                            locationStatus.text = "Pobieranie batymetrii..."
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
                        errorToast.showBusy("Pobieranie danych... 0%", true)
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
                    window.pointChecked = false
                    locationStatus.text = ""
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
                            if (window.pointConfirmed) return
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
                id: errorToast
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8

                property bool busy: false
                property bool showProgress: false

                width: Math.max(errorMessage.width + 34)
                height: Math.max(errorMessage.implicitHeight, 14) + 12 + (showProgress ? 9 : 0)

                radius: 8
                color: window.dark
                visible: false
                opacity: 0

                function show(message, color) {
                    errorFade.stop()
                    errorTimer.stop()

                    busy = false
                    showProgress = false
                    errorMessage.text = message
                    statusDot.color = color
                    errorToast.opacity = 1
                    errorToast.visible = true

                    errorTimer.start()
                }

                function showBusy(message, withProgress) {
                    errorFade.stop()
                    errorTimer.stop()

                    busy = true
                    showProgress = withProgress === true
                    errorMessage.text = message
                    errorToast.opacity = 1
                    errorToast.visible = true
                }

                TextMetrics {
                    id: textMetrics
                    font: errorMessage.font
                    text: errorMessage.text
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
                        id: statusDot
                        width: 10
                        height: 10
                        radius: 5
                        anchors.centerIn: parent
                        visible: !errorToast.busy
                    }

                    Item {
                        id: spinner
                        anchors.fill: parent
                        visible: errorToast.busy

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
                            running: errorToast.busy && errorToast.visible
                        }
                    }
                }

                Label {
                    id: errorMessage
                    color: "white"
                    anchors.left: indicator.right
                    anchors.leftMargin: 6
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    width: Math.min(Math.ceil(textMetrics.advanceWidth) + 4,
                                    Math.max(120, rectangle2.width - 200))
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignLeft
                    font.pixelSize: 11
                }

                Rectangle {
                    id: progressTrack
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.leftMargin: 6
                    anchors.rightMargin: 6
                    anchors.bottomMargin: 6
                    height: 3
                    radius: 1.5
                    color: "#444444"
                    visible: errorToast.showProgress

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