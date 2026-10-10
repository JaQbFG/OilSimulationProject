#include "CopernicusManager.h"
#include <QDebug>
#include <QCoreApplication>
#include <QDir>

CopernicusManager::CopernicusManager(QObject *parent)
    : QObject(parent), m_progress(0), m_isDownloading(false) {}

int CopernicusManager::progress() const { return m_progress; }
bool CopernicusManager::isDownloading() const { return m_isDownloading; }

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
void CopernicusManager::startBatchDownload(const QString &startStr, const QString &endStr, int hoursStep) {
    if (m_isDownloading) return;

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
            [=](int exitCode, QProcess::ExitStatus) {
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