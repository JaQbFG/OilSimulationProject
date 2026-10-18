#include "CopernicusManager.h"
#include <QDebug>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QProcessEnvironment>

static const QString kSurfaceDepth = "0.49402499198913574";

CopernicusManager::CopernicusManager(QObject *parent)
    : QObject(parent), m_progress(0), m_isDownloading(false) {}

int CopernicusManager::progress() const { return m_progress; }
bool CopernicusManager::isDownloading() const { return m_isDownloading; }

bool CopernicusManager::loadCredentials()
{
    QFile file(QCoreApplication::applicationDirPath() + "/credentials.txt");
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qDebug() << "Nie można otworzyć credentials.txt:" << file.errorString();
        return false;
    }
    QTextStream in(&file);
    m_username = in.readLine().trimmed();
    m_password = in.readLine().trimmed();
    return !m_username.isEmpty() && !m_password.isEmpty();
}

void CopernicusManager::setProgress(int val) {
    if (m_progress != val) {
        m_progress = val;
        emit progressChanged();
    }
}

void CopernicusManager::setDownloading(bool val) {
    if (m_isDownloading != val) {
        m_isDownloading = val;
        emit isDownloadingChanged();
    }
}

void CopernicusManager::checkLocation(double latitude, double longitude, const QString &timeStr)
{
    if (!loadCredentials()) {
        emit locationCheckFinished(false, false, "Nie udało się wczytać danych logowania.");
        return;
    }
    if (m_isDownloading) {
        emit locationCheckFinished(false, false, "Poczekaj na zakończenie pobierania.");
        return;
    }

    QDateTime dt = QDateTime::fromString(timeStr, "yyyy-MM-dd'T'HH:mm:ss");
    if (!dt.isValid()) {
        emit locationCheckFinished(false, false, "Nieprawidłowa data.");
        return;
    }

    const QString appDir = QCoreApplication::applicationDirPath();
    const QString fileName = "location_check.csv";
    const QString filePath = appDir + "/" + fileName;
    QFile::remove(filePath);

    const QString t = dt.toString("yyyy-MM-dd'T'HH:mm:ss");
    const QString lon = QString::number(longitude, 'f', 6);
    const QString lat = QString::number(latitude, 'f', 6);

    QStringList args;
    args << "subset"
         << "--username" << m_username << "--password" << m_password
         << "-i" << "cmems_mod_glo_phy_anfc_merged-uv_PT1H-i"
         << "-v" << "utotal" << "-v" << "vtotal"
         << "-t" << t << "-T" << t
         << "-x" << lon << "-X" << lon
         << "-y" << lat << "-Y" << lat
         << "-z" << kSurfaceDepth << "-Z" << kSurfaceDepth
         << "--file-format" << "csv"
         << "-o" << appDir
         << "-f" << fileName
         << "--overwrite";

    auto *process = new QProcess(this);
    process->setWorkingDirectory(appDir);

    connect(process, &QProcess::readyReadStandardError, this, [this, process]() {
        emit logMessage(QString::fromUtf8(process->readAllStandardError()));
    });
    connect(process, &QProcess::readyReadStandardOutput, this, [this, process]() {
        emit logMessage(QString::fromUtf8(process->readAllStandardOutput()));
    });

    connect(process, &QProcess::errorOccurred, this,
            [this, process](QProcess::ProcessError err) {
                qDebug() << "Błąd QProcess:" << err << process->errorString();
                if (err == QProcess::FailedToStart) {
                    emit locationCheckFinished(false, false,
                                               "Nie można uruchomić copernicusmarine.exe: " + process->errorString());
                    process->deleteLater();
                }
            });

    connect(process, &QProcess::finished, this,
            [this, process, filePath](int exitCode, QProcess::ExitStatus) {
                process->deleteLater();
                qDebug() << "checkLocation finished, exit code:" << exitCode;

                if (exitCode != 0) {
                    emit locationCheckFinished(false, false, "Nie udało się pobrać danych dla lokalizacji.");
                    return;
                }

                QString actualPath = filePath;
                if (!QFile::exists(actualPath) && QFile::exists(filePath + ".csv"))
                    actualPath += ".csv";

                QFile csv(actualPath);
                if (!csv.open(QIODevice::ReadOnly | QIODevice::Text)) {
                    emit locationCheckFinished(false, false,
                                               "Nie można odczytać pliku: " + actualPath);
                    return;
                }

                QTextStream in(&csv);
                int uIdx = -1, vIdx = -1;
                bool foundData = false, isLand = false;

                while (!in.atEnd()) {
                    const QString line = in.readLine().trimmed();
                    if (line.isEmpty()) continue;
                    const QStringList f = line.split(',', Qt::KeepEmptyParts);

                    if (uIdx < 0 && line.contains("utotal")) {
                        uIdx = f.indexOf("utotal");
                        vIdx = f.indexOf("vtotal");
                        continue;
                    }
                    if (f.size() < 3) continue;

                    if (uIdx < 0) { uIdx = f.size() - 2; vIdx = f.size() - 1; }

                    auto val = [&](int i) { return i < f.size() ? f[i].trimmed() : QString(); };
                    auto empty = [](const QString &s) {
                        return s.isEmpty() || s.compare("nan", Qt::CaseInsensitive) == 0;
                    };

                    isLand = empty(val(uIdx)) && empty(val(vIdx));
                    foundData = true;
                    break;
                }

                csv.close();
                QFile::remove(actualPath);

                if (!foundData) {
                    emit locationCheckFinished(false, false, "Plik nie zawiera danych do sprawdzenia.");
                    return;
                }
                emit locationCheckFinished(true, isLand,
                                           isLand ? "Lokalizacja znajduje się na lądzie."
                                                  : "Lokalizacja znajduje się na wodzie.");
            });

    qDebug() << "Uruchamiam:" << appDir + "/copernicusmarine.exe" << args;
    process->start(appDir + "/copernicusmarine.exe", args);
}

void CopernicusManager::startBatchDownload(const QString &startStr, const QString &endStr, int hoursStep) {
    if (!loadCredentials()) {
        emit locationCheckFinished(
            false, false,
            "Nie udało się wczytać danych logowania."
            );
        return;
    }

    if (m_isDownloading) return;

    QString credsFilePath = QCoreApplication::applicationDirPath() + "/credentials.txt";
    QFile file(credsFilePath);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        emit downloadFinished(false, "Błąd: Nie można znaleźć pliku credentials.txt!");
        return;
    }

    QTextStream in(&file);
    m_username = in.readLine().trimmed();
    m_password = in.readLine().trimmed();
    file.close();

    if (m_username.isEmpty() || m_password.isEmpty()) {
        emit downloadFinished(false, "Błąd: Plik credentials.txt jest pusty lub niekompletny!");
        return;
    }

    QDir dir(QCoreApplication::applicationDirPath());
    QStringList oldFiles = dir.entryList(QStringList() << "test_*.csv", QDir::Files);
    for (const QString &filename : oldFiles) {
        dir.remove(filename);
    }

    QDateTime start = QDateTime::fromString(startStr, "yyyy-MM-ddTHH:mm:ss");
    QDateTime end = QDateTime::fromString(endStr, "yyyy-MM-ddTHH:mm:ss");

    if (!start.isValid() || !end.isValid() || start > end) {
        emit downloadFinished(false, "Nieprawidłowy zakres dat!");
        return;
    }

    m_timeQueue.clear();
    QDateTime current = start;
    while (current <= end) {
        m_timeQueue.enqueue(current);
        current = current.addSecs(hoursStep * 3600);
    }

    if (m_timeQueue.isEmpty()) {
        emit downloadFinished(false, "Brak dat do pobrania w podanym zakresie.");
        return;
    }

    m_totalTasks = m_timeQueue.size();
    m_completedTasks = 0;
    setDownloading(true);
    setProgress(0);

    processNextInQueue();
}

void CopernicusManager::processNextInQueue() {
    if (m_timeQueue.isEmpty()) {
        setDownloading(false);
        emit downloadFinished(true, "Pobieranie wszystkich plików zakończone sukcesem!");
        return;
    }

    QDateTime dt = m_timeQueue.dequeue();
    QString timeFormatted = dt.toString("yyyy-MM-dd'T'hh:mm:ss");
    QString fileSuffix = dt.toString("yyyyMMdd_hhmmss");
    QString outputFileName = QString("test_%1").arg(fileSuffix);

    QStringList args;
    args << "subset"
         << "--username" << m_username
         << "--password" << m_password
         << "-i" << "cmems_mod_glo_phy_anfc_merged-uv_PT1H-i"
         << "-v" << "utotal"
         << "-v" << "vtotal"
         << "-t" << timeFormatted
         << "-T" << timeFormatted
         << "-x" << "-11"
         << "-X" << "44"
         << "-y" << "30"
         << "-Y" << "72"
         << "-z" << "0.49402499198913574"
         << "-Z" << "0.49402499198913574"
         << "--file-format" << "csv"
         << "-f" << outputFileName
         << "--overwrite";

    QProcess *process = new QProcess(this);

    connect(process, &QProcess::readyReadStandardOutput, [this, process]() {
        emit logMessage(QString::fromUtf8(process->readAllStandardOutput()));
    });

    connect(process, &QProcess::readyReadStandardError, [this, process]() {
        emit logMessage(QString::fromUtf8(process->readAllStandardError()));
    });

    connect(process, QOverload<int, QProcess::ExitStatus>::of(&QProcess::finished),
            [=](int exitCode, QProcess::ExitStatus exitStatus) {

                qDebug() << "Proces zakończony!";
                qDebug() << "Kod wyjścia:" << exitCode;
                qDebug() << "Status:" << exitStatus;
                qDebug() << "Błąd procesu:" << process->errorString();

                process->deleteLater();

                if (exitCode == 0) {
                    m_completedTasks++;
                    int progressPercent = static_cast<int>((static_cast<double>(m_completedTasks) / m_totalTasks) * 100);
                    setProgress(progressPercent);
                    processNextInQueue();
                } else {
                    setDownloading(false);
                    emit downloadFinished(false, QString("Błąd podczas pobierania dla czasu: %1").arg(timeFormatted));
                }
            });

    emit logMessage(QString("Uruchamianie dla: %1").arg(timeFormatted));

    QString exePath = QCoreApplication::applicationDirPath() + "/copernicusmarine.exe";
    process->start(exePath, args);
}
