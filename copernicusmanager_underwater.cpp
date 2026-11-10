#include "CopernicusManager.h"
#include "oceanparsers.h"

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QProcess>
#include <QTimeZone>
#include <QtMath>

#include <cmath>
#include <memory>

static const QString kUnderwaterMinDepth =
    "0.49402499198913574";

static const QString kBathymetryDataset =
    "cmems_mod_glo_phy_anfc_0.083deg_static";

static const QString kUnderwaterDataset =
    "cmems_mod_glo_phy-cur_anfc_0.083deg_PT6H-i";


static const double kAreaRadiusKm = 25.0;

static QDateTime parseUtc(const QString &text)
{
    QDateTime dt = QDateTime::fromString(text, Qt::ISODate);

    if (dt.isValid()) {
        dt.setTimeZone(QTimeZone::utc());
    }

    return dt;
}

static QString resolveCsv(const QString &basePath)
{
    if (QFile::exists(basePath)) {
        return basePath;
    }

    if (QFile::exists(basePath + ".csv")) {
        return basePath + ".csv";
    }

    return QString();
}

double CopernicusManager::seabedDepthAt(double latitude, double longitude) const
{
    double depth = 0.0;

    if (BathymetryParser::depthAt(m_bathymetryData, latitude, longitude, &depth)) {
        return depth;
    }

    return -1.0;
}


void CopernicusManager::runSubset(
    const QStringList &args,
    std::function<void(bool, const QString &)> done)
{
    const QString appDir =
        QCoreApplication::applicationDirPath();

    auto *process = new QProcess(this);

    process->setWorkingDirectory(appDir);

    connect(
        process,
        &QProcess::readyReadStandardOutput,
        this,
        [this, process]() {
            emit logMessage(
                QString::fromUtf8(process->readAllStandardOutput())
                );
        }
        );

    connect(
        process,
        &QProcess::readyReadStandardError,
        this,
        [this, process]() {
            emit logMessage(
                QString::fromUtf8(process->readAllStandardError())
                );
        }
        );

    auto handled = std::make_shared<bool>(false);

    connect(
        process,
        &QProcess::errorOccurred,
        this,
        [process, handled, done](QProcess::ProcessError error) {
            if (error != QProcess::FailedToStart || *handled) {
                return;
            }

            *handled = true;

            const QString message =
                "Nie można uruchomić copernicusmarine.exe: "
                + process->errorString();

            process->deleteLater();

            done(false, message);
        }
        );

    connect(
        process,
        QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
        this,
        [process, handled, done](int exitCode,
                                 QProcess::ExitStatus status) {
            Q_UNUSED(status);

            if (*handled) {
                return;
            }

            *handled = true;

            process->deleteLater();

            if (exitCode != 0) {
                done(false,
                     QString("Kod wyjścia: %1.").arg(exitCode));
                return;
            }

            done(true, QString());
        }
        );

    process->start(
        QDir(appDir).filePath("copernicusmarine.exe"),
        args
        );
}

void CopernicusManager::prepareUnderwaterData(
    double latitude,
    double longitude,
    const QString &startStr,
    const QString &endStr)
{
    if (m_isDownloading) {
        emit logMessage("Pobieranie danych już trwa.");
        return;
    }

    if (!std::isfinite(latitude) ||
        !std::isfinite(longitude) ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude < -180.0 ||
        longitude > 180.0) {

        emit bathymetryLoaded(
            false,
            0.0,
            "Nieprawidłowe współrzędne."
            );

        return;
    }

    m_underwaterStartDate = parseUtc(startStr);
    m_underwaterEndDate = parseUtc(endStr);

    if (!m_underwaterStartDate.isValid() ||
        !m_underwaterEndDate.isValid() ||
        m_underwaterStartDate > m_underwaterEndDate) {

        emit bathymetryLoaded(
            false,
            0.0,
            "Nieprawidłowy zakres dat."
            );

        return;
    }

    if (!loadCredentials()) {
        emit bathymetryLoaded(
            false,
            0.0,
            "Nie udało się wczytać danych logowania."
            );

        return;
    }

    m_startLatitude = latitude;
    m_startLongitude = longitude;

    const double latOffset = kAreaRadiusKm / 111.0;

    const double lonOffset =
        kAreaRadiusKm /
        (111.0 * qMax(0.1, qCos(qDegreesToRadians(latitude))));

    m_minLatitude = qMax(-90.0, latitude - latOffset);
    m_maxLatitude = qMin(90.0, latitude + latOffset);

    m_minLongitude = qMax(-180.0, longitude - lonOffset);
    m_maxLongitude = qMin(180.0, longitude + lonOffset);

    emit logMessage(
        QString("Obszar podwodny: lat %1 - %2, lon %3 - %4")
            .arg(m_minLatitude)
            .arg(m_maxLatitude)
            .arg(m_minLongitude)
            .arg(m_maxLongitude)
        );

    downloadBathymetry();
}


void CopernicusManager::downloadBathymetry()
{
    const QString appDir =
        QCoreApplication::applicationDirPath();

    const QString outputFileName =
        QString("bathymetry_%1_%2")
            .arg(QString::number(m_startLatitude, 'f', 4))
            .arg(QString::number(m_startLongitude, 'f', 4));

    const QString outputBasePath =
        QDir(appDir).filePath(outputFileName);

    QFile::remove(outputBasePath);
    QFile::remove(outputBasePath + ".csv");

    // deptho is a static 2D field: no time and no depth arguments
    QStringList args;

    args << "subset"
         << "--username" << m_username
         << "--password" << m_password

         << "--dataset-id" << kBathymetryDataset
         << "--dataset-part" << "bathy"

         << "--variable" << "deptho"

         << "--minimum-longitude" << QString::number(m_minLongitude, 'f', 6)
         << "--maximum-longitude" << QString::number(m_maxLongitude, 'f', 6)
         << "--minimum-latitude" << QString::number(m_minLatitude, 'f', 6)
         << "--maximum-latitude" << QString::number(m_maxLatitude, 'f', 6)

         << "--coordinates-selection-method" << "outside"

         << "--file-format" << "csv"
         << "--output-directory" << appDir
         << "--output-filename" << outputFileName
         << "--overwrite";

    setDownloading(true);

    emit logMessage("Pobieranie batymetrii...");

    runSubset(
        args,
        [this, outputBasePath](bool ok, const QString &error) {

            auto fail = [this](const QString &message) {
                setDownloading(false);
                emit logMessage(message);
                emit bathymetryLoaded(false, 0.0, message);
            };

            if (!ok) {
                fail("Nie udało się pobrać batymetrii. " + error);
                return;
            }

            const QString path = resolveCsv(outputBasePath);

            if (path.isEmpty()) {
                fail("Nie znaleziono pliku batymetrii.");
                return;
            }

            BathymetryData data;
            QString parseError;

            if (!BathymetryParser::loadCsv(path, data, &parseError)) {
                fail("Błąd parsowania batymetrii: " + parseError);
                return;
            }

            double depth = 0.0;

            if (!BathymetryParser::depthAt(
                    data, m_startLatitude, m_startLongitude, &depth)) {
                fail("Brak głębokości dna w tym punkcie.");
                return;
            }

            m_bathymetryData = data;
            m_seabedDepth = depth;

            setDownloading(false);

            emit logMessage(
                QString("Głębokość dna: %1 m (%2 punktów siatki)")
                    .arg(m_seabedDepth)
                    .arg(m_bathymetryData.points.size())
                );

            emit bathymetryLoaded(
                true,
                m_seabedDepth,
                "Batymetria została pobrana."
                );

            prepareUnderwaterQueue();

            if (m_underwaterTimeQueue.isEmpty()) {
                emit underwaterDataLoaded(
                    QDateTime(),
                    false,
                    "Brak terminów podwodnych w podanym zakresie dat."
                    );

                return;
            }
            processCurrentUnderwaterDownload(false);
        }
        );
}


void CopernicusManager::prepareUnderwaterQueue()
{
    m_underwaterTimeQueue.clear();

    if (m_seabedDepth <= 0.0) {
        emit logMessage("Nieprawidłowa głębokość dna.");
        return;
    }


    QDateTime current = m_underwaterStartDate;

    const int hour = current.time().hour();

    current = QDateTime(
        current.date(),
        QTime(hour - hour % 6, 0),
        QTimeZone::utc()
        );

    while (current <= m_underwaterEndDate) {
        m_underwaterTimeQueue.enqueue(current);

        current = current.addSecs(6 * 3600);
    }

    emit logMessage(
        QString("Przygotowano %1 terminów podwodnych.")
            .arg(m_underwaterTimeQueue.size())
        );
}


void CopernicusManager::processCurrentUnderwaterDownload(bool continueWithSurface)
{
    if (m_underwaterTimeQueue.isEmpty()) {
        emit logMessage("Brak kolejnych terminów podwodnych.");
        return;
    }

    const QDateTime dt = m_underwaterTimeQueue.dequeue();

    const QString timeFormatted =
        dt.toString("yyyy-MM-dd'T'HH:mm:ss");

    const QString outputFileName =
        QString("underwater_%1").arg(dt.toString("yyyyMMdd_HHmmss"));

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

         << "--dataset-id" << kUnderwaterDataset

         << "--variable" << "uo"
         << "--variable" << "vo"

         << "--start-datetime" << timeFormatted
         << "--end-datetime" << timeFormatted

         << "--minimum-longitude" << QString::number(m_minLongitude, 'f', 6)
         << "--maximum-longitude" << QString::number(m_maxLongitude, 'f', 6)
         << "--minimum-latitude" << QString::number(m_minLatitude, 'f', 6)
         << "--maximum-latitude" << QString::number(m_maxLatitude, 'f', 6)

         << "--minimum-depth" << kUnderwaterMinDepth
         << "--maximum-depth" << QString::number(m_seabedDepth, 'f', 6)

         << "--coordinates-selection-method" << "outside"

         << "--file-format" << "csv"
         << "--output-directory" << appDir
         << "--output-filename" << outputFileName
         << "--overwrite";

    setDownloading(true);

    emit logMessage(
        QString("Pobieranie prądów podwodnych dla %1")
            .arg(timeFormatted)
        );

    runSubset(
        args,
        [this, dt, timeFormatted, outputBasePath, continueWithSurface](
            bool ok, const QString &error) {

            auto fail = [this, dt](const QString &message) {
                setDownloading(false);

                m_underwaterTimeQueue.prepend(dt);

                emit logMessage(message);
                emit underwaterDataLoaded(dt, false, message);
                emit downloadFinished(false, message);
            };

            if (!ok) {
                fail("Nie udało się pobrać danych podwodnych. " + error);
                return;
            }

            const QString path = resolveCsv(outputBasePath);

            if (path.isEmpty()) {
                fail("Nie znaleziono pliku danych podwodnych.");
                return;
            }

            UnderwaterCurrentData data;
            QString parseError;

            if (!UnderwaterCurrentParser::loadCsv(path, data, &parseError)) {
                fail("Błąd parsowania danych podwodnych: " + parseError);
                return;
            }

            m_underwaterData = data;

            setDownloading(false);

            emit logMessage(
                QString("Wczytano %1 punktów podwodnych dla %2.")
                    .arg(m_underwaterData.points.size())
                    .arg(timeFormatted)
                );

            emit underwaterDataLoaded(
                dt,
                true,
                QString("Dane podwodne wczytane dla %1.").arg(timeFormatted)
                );


            if (continueWithSurface && !m_timeQueue.isEmpty()) {
                downloadNext();
            }
        }
        );
}
