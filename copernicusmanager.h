#ifndef COPERNICUSMANAGER_H
#define COPERNICUSMANAGER_H

#pragma once
#include <QObject>
#include <QProcess>
#include <QDateTime>
#include <QStringList>
#include <QQueue>

class CopernicusManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)

    public:
        explicit CopernicusManager(QObject *parent = nullptr);

        int progress() const;
        bool isDownloading() const;

        Q_INVOKABLE void startBatchDownload(const QString &startStr, const QString &endStr, int hoursStep = 1);

    signals:
        void progressChanged();
        void isDownloadingChanged();
        void downloadFinished(bool success, QString message);
        void logMessage(QString message);

    private:
        void setProgress(int val);
        void setDownloading(bool val);
        void processNextInQueue();

        QQueue<QDateTime> m_timeQueue;
        int m_totalTasks = 0;
        int m_completedTasks = 0;
        int m_progress;
        bool m_isDownloading;
};

#endif // COPERNICUSMANAGER_H