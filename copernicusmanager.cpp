#include "CopernicusManager.h"
#include "SurfaceCurrentParser.h"

#include <QDebug>
#include <QCoreApplication>
#include <QFile>
#include <QTextStream>
#include <QProcess>
#include <QDir>
#include <QFutureWatcher>
#include <QtMath>

#include <QtConcurrentRun>
#include <QFileInfo>
#include <cmath>
#include <memory>


static const QString kSurfaceDepth =
    "0.49402499198913574";


struct SurfaceParseResult
{
    bool success = false;
    SurfaceCurrentData data;
    QString error;
};


CopernicusManager::CopernicusManager(QObject *parent)
    : QObject(parent)
{
}

int CopernicusManager::progress() const
{
    return m_progress;
}

bool CopernicusManager::isDownloading() const
{
    return m_isDownloading;
}

void CopernicusManager::setProgress(int value)
{
    if (m_progress != value) {
        m_progress = value;
        emit progressChanged();
    }
}

void CopernicusManager::setDownloading(bool value)
{
    if (m_isDownloading != value) {
        m_isDownloading = value;
        emit isDownloadingChanged();
    }
}

bool CopernicusManager::loadCredentials()
{
    QFile file(
        QCoreApplication::applicationDirPath()
        + "/credentials.txt"
        );

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "Nie można otworzyć credentials.txt:"
                 << file.errorString();

        return false;
    }

    QTextStream in(&file);

    m_username = in.readLine().trimmed();
    m_password = in.readLine().trimmed();

    file.close();

    return !m_username.isEmpty()
           && !m_password.isEmpty();
}


void CopernicusManager::prepareSurfaceData(
    const QString &startStr,
    const QString &endStr,
    int hoursStep)
{
    if (m_isDownloading) {
        emit initialSurfaceDataLoaded(
            false,
            "Pobieranie lub wczytywanie danych już trwa."
            );

        return;
    }

    m_timeQueue.clear();
    m_surfaceData = SurfaceCurrentData{};

    m_initialLoadPending = false;

    setProgress(0);

    if (!loadCredentials()) {
        emit initialSurfaceDataLoaded(
            false,
            "Nie udało się wczytać danych logowania."
            );

        return;
    }

    QDateTime start = QDateTime::fromString(
        startStr,
        Qt::ISODate
        );

    QDateTime end = QDateTime::fromString(
        endStr,
        Qt::ISODate
        );

    if (!start.isValid() ||
        !end.isValid() ||
        start > end ||
        hoursStep <= 0) {

        emit initialSurfaceDataLoaded(
            false,
            "Nieprawidłowy zakres dat lub krok czasowy."
            );

        return;
    }

    if (start.time().minute() != 0 ||
        start.time().second() != 0 ||
        end.time().minute() != 0 ||
        end.time().second() != 0) {

        emit initialSurfaceDataLoaded(
            false,
            "Podaj pełne godziny, np. 2026-10-11T20:00:00."
            );

        return;
    }

    QDateTime current = start;

    while (current <= end) {
        m_timeQueue.enqueue(current);

        current = current.addSecs(
            static_cast<qint64>(hoursStep) * 3600
            );
    }

    if (m_timeQueue.isEmpty()) {
        emit initialSurfaceDataLoaded(
            false,
            "Nie znaleziono terminów do pobrania."
            );

        return;
    }

    m_totalTasks = m_timeQueue.size();
    m_completedTasks = 0;

    m_initialLoadPending = true;

    emit logMessage(
        QString("Przygotowano %1 terminów. Pobieram pierwszy plik.")
            .arg(m_totalTasks)
        );


    downloadNext();
}



void CopernicusManager::startBatchDownload(
    const QString &startStr,
    const QString &endStr,
    int hoursStep)
{
    prepareSurfaceData(
        startStr,
        endStr,
        hoursStep
        );
}


void CopernicusManager::downloadNext()
{
    if (m_isDownloading) {
        emit logMessage(
            "Pobieranie lub parsowanie już trwa."
            );

        return;
    }

    if (m_timeQueue.isEmpty()) {
        emit downloadFinished(
            true,
            "Brak kolejnych terminów do pobrania."
            );

        return;
    }

    if (m_username.isEmpty() || m_password.isEmpty()) {
        if (!loadCredentials()) {
            const QString message =
                "Nie udało się wczytać danych logowania.";

            handleDownloadFailure(
                m_timeQueue.dequeue(),
                m_initialLoadPending,
                message
                );

            return;
        }
    }

    processCurrentDownload();
}



void CopernicusManager::handleDownloadFailure(
    const QDateTime &time,
    bool isInitialLoad,
    const QString &message)
{
    setDownloading(false);

    emit logMessage(message);

    if (isInitialLoad) {
        m_initialLoadPending = false;
        m_timeQueue.clear();

        emit initialSurfaceDataLoaded(
            false,
            message
            );
    } else {
        m_timeQueue.prepend(time);

        emit surfaceDataLoaded(
            time,
            false,
            message
            );
    }

    emit downloadFinished(
        false,
        message
        );
}



void CopernicusManager::processCurrentDownload()
{
    if (m_timeQueue.isEmpty()) {
        setDownloading(false);

        emit downloadFinished(
            true,
            "Wszystkie terminy zostały przetworzone."
            );

        return;
    }

    const QDateTime dt = m_timeQueue.dequeue();

    const bool isInitialLoad = m_initialLoadPending;

    const QString timeFormatted =
        dt.toString("yyyy-MM-dd'T'HH:mm:ss");

    const QString fileSuffix =
        dt.toString("yyyyMMdd_HHmmss");


    const QString outputFileName =
        QString("surface_%1").arg(fileSuffix);

    const QString appDir =
        QCoreApplication::applicationDirPath();

    const QString outputBasePath =
        QDir(appDir).filePath(outputFileName);

    QFile::remove(outputBasePath);
    QFile::remove(outputBasePath + ".csv");

    QStringList args;

    args << "subset"
         << "--username" << m_username
         << "--password" << m_password

         << "--dataset-id"
         << "cmems_mod_glo_phy_anfc_merged-uv_PT1H-i"

         << "--variable" << "utotal"
         << "--variable" << "vtotal"

         << "--start-datetime" << timeFormatted
         << "--end-datetime" << timeFormatted


         << "--minimum-longitude" << "-11.0"
         << "--maximum-longitude" << "42.4"

         << "--minimum-latitude" << "29.9"
         << "--maximum-latitude" << "71.8"

         << "--minimum-depth" << kSurfaceDepth
         << "--maximum-depth" << kSurfaceDepth

         << "--coordinates-selection-method"
         << "outside"

         << "--file-format" << "csv"
         << "--output-directory" << appDir
         << "--output-filename" << outputFileName
         << "--overwrite";

    auto *process = new QProcess(this);

    process->setWorkingDirectory(appDir);

    connect(
        process,
        &QProcess::readyReadStandardOutput,
        this,
        [this, process]() {
            emit logMessage(
                QString::fromUtf8(
                    process->readAllStandardOutput()
                    )
                );
        }
        );

    connect(
        process,
        &QProcess::readyReadStandardError,
        this,
        [this, process]() {
            emit logMessage(
                QString::fromUtf8(
                    process->readAllStandardError()
                    )
                );
        }
        );

    setDownloading(true);

    emit logMessage(
        QString("Pobieranie danych dla: %1")
            .arg(timeFormatted)
        );

    const QString exePath =
        QDir(appDir).filePath("copernicusmarine.exe");
\
    auto processHandled =
        std::make_shared<bool>(false);

    connect(
        process,
        &QProcess::errorOccurred,
        this,
        [this, process, dt, isInitialLoad, processHandled](
            QProcess::ProcessError error) {

            if (error != QProcess::FailedToStart) {
                emit logMessage(
                    "Błąd procesu: " + process->errorString()
                    );

                return;
            }

            if (*processHandled) {
                return;
            }

            *processHandled = true;

            const QString message =
                "Nie można uruchomić copernicusmarine.exe: "
                + process->errorString();

            handleDownloadFailure(
                dt,
                isInitialLoad,
                message
                );

            process->deleteLater();
        }
        );

    connect(
        process,
        QOverload<int, QProcess::ExitStatus>::of(
            &QProcess::finished
            ),
        this,
        [this, process, dt, timeFormatted,
         outputBasePath, isInitialLoad, processHandled](
            int exitCode,
            QProcess::ExitStatus exitStatus) {

            Q_UNUSED(exitStatus);

            if (*processHandled) {
                return;
            }

            *processHandled = true;

            process->deleteLater();

            if (exitCode != 0) {
                handleDownloadFailure(
                    dt,
                    isInitialLoad,
                    QString(
                        "Pobieranie nie powiodło się dla %1. "
                        "Kod wyjścia: %2."
                        ).arg(timeFormatted).arg(exitCode)
                    );

                return;
            }

            QString actualPath = outputBasePath;

            if (!QFile::exists(actualPath) &&
                QFile::exists(outputBasePath + ".csv")) {

                actualPath += ".csv";
            }

            if (!QFile::exists(actualPath)) {
                handleDownloadFailure(
                    dt,
                    isInitialLoad,
                    "Copernicus zakończył pobieranie, ale nie "
                    "znaleziono pliku CSV: " + outputBasePath
                    );

                return;
            }
            qDebug() << "[CSV] Istnieje:" << QFile::exists(actualPath);
            qDebug() << "[CSV] Ścieżka:" << actualPath;
            qDebug() << "[CSV] Rozmiar:"
                     << QFileInfo(actualPath).size()
                     << "bajtów";
            emit logMessage(
                QString("Pobrano %1. Rozpoczynam parsowanie w tle.")
                    .arg(actualPath)
                );


            auto *watcher =
                new QFutureWatcher<SurfaceParseResult>(this);

            connect(
                watcher,
                &QFutureWatcher<SurfaceParseResult>::finished,
                this,
                [this, watcher, dt, timeFormatted,
                 isInitialLoad]() {

                    const SurfaceParseResult result =
                        watcher->result();
                    qDebug() << "[PARSER] Success:" << result.success;
                    qDebug() << "[PARSER] Liczba punktów:"
                             << result.data.points.size();
                    qDebug() << "[PARSER] Błąd:"
                             << result.error;

                    watcher->deleteLater();

                    if (!result.success) {
                        handleDownloadFailure(
                            dt,
                            isInitialLoad,
                            "Nie udało się sparsować CSV: "
                                + result.error
                            );

                        return;
                    }


                    m_surfaceData = result.data;

                    setDownloading(false);

                    m_completedTasks++;

                    int progressPercent = 100;

                    if (m_totalTasks > 0) {
                        progressPercent =
                            static_cast<int>(
                                (static_cast<double>(
                                     m_completedTasks
                                     ) / m_totalTasks) * 100.0
                                );
                    }

                    setProgress(progressPercent);

                    emit logMessage(
                        QString(
                            "Wczytano %1 punktów dla %2."
                            ).arg(
                                m_surfaceData.points.size()
                                ).arg(
                                timeFormatted
                                )
                        );

                    if (isInitialLoad) {
                        m_initialLoadPending = false;

                        emit initialSurfaceDataLoaded(
                            true,
                            QString(
                                "Dane wczytane dla %1. "
                                "Możesz wybrać punkt na mapie."
                                ).arg(timeFormatted)
                            );
                    } else {
                        emit surfaceDataLoaded(
                            m_surfaceData.time,
                            true,
                            "Dane powierzchniowe zostały wczytane."
                            );
                    }


                    if (m_timeQueue.isEmpty()) {
                        emit downloadFinished(
                            true,
                            "Pobieranie i parsowanie zakończone."
                            );
                    } else {
                        emit logMessage(
                            QString(
                                "Pozostało terminów: %1. "
                                "Oczekiwanie na downloadNext()."
                                ).arg(m_timeQueue.size())
                            );
                    }
                }
                );

            const QString csvPath = actualPath;

            watcher->setFuture(
                QtConcurrent::run([csvPath]() {

                    SurfaceParseResult result;

                    result.success =
                        SurfaceCurrentParser::loadCsv(
                            csvPath,
                            result.data,
                            &result.error
                            );

                    return result;
                })
                );
        }
        );

    emit logMessage(
        QString("Uruchamiam pobieranie: %1")
            .arg(timeFormatted)
        );

    process->start(exePath, args);
}


void CopernicusManager::checkLocation(
    double latitude,
    double longitude)
{
    if (m_isDownloading) {
        emit locationCheckFinished(
            false,
            false,
            "Poczekaj na zakończenie pobierania i parsowania."
            );

        return;
    }

    if (!std::isfinite(latitude) ||
        !std::isfinite(longitude) ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {

        emit locationCheckFinished(
            false,
            false,
            "Nieprawidłowe współrzędne."
            );

        return;
    }

    if (m_surfaceData.points.isEmpty()) {
        emit locationCheckFinished(
            false,
            false,
            "Najpierw pobierz i wczytaj dane powierzchniowe."
            );

        return;
    }

    const SurfaceCurrentPoint *nearestPoint = nullptr;

    double bestDistance =
        std::numeric_limits<double>::max();

    for (const SurfaceCurrentPoint &point
         : m_surfaceData.points) {

        const double deltaLat =
            point.latitude - latitude;

        const double deltaLon =
            (point.longitude - longitude)
            * qCos(qDegreesToRadians(latitude));

        const double distance =
            deltaLat * deltaLat
            + deltaLon * deltaLon;

        if (distance < bestDistance) {
            bestDistance = distance;
            nearestPoint = &point;
        }
    }

    if (nearestPoint == nullptr) {
        emit locationCheckFinished(
            false,
            false,
            "Nie znaleziono odpowiedniego punktu siatki."
            );

        return;
    }

    emit logMessage(
        QString(
            "Najbliższy punkt: lat=%1, lon=%2, "
            "u=%3, v=%4, valid=%5"
            )
            .arg(nearestPoint->latitude, 0, 'f', 5)
            .arg(nearestPoint->longitude, 0, 'f', 5)
            .arg(nearestPoint->u)
            .arg(nearestPoint->v)
            .arg(nearestPoint->valid)
        );

    const bool isLand = !nearestPoint->valid;

    if (isLand) {
        emit locationCheckFinished(
            true,
            true,
            "Lokalizacja znajduje się na lądzie."
            );
    } else {
        emit locationCheckFinished(
            true,
            false,
             "Lokalizacja znajduje się na wodzie."
            );
    }
}