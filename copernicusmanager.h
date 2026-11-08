#ifndef COPERNICUSMANAGER_H
#define COPERNICUSMANAGER_H

#include <QObject>
#include <QString>
#include <QDateTime>
#include <QQueue>

#include "OceanData.h"

class CopernicusManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(bool isDownloading READ isDownloading NOTIFY isDownloadingChanged)

public:
    explicit CopernicusManager(QObject *parent = nullptr);

    int progress() const;
    bool isDownloading() const;
    const SurfaceCurrentData &surfaceData() const { return m_surfaceData; }
    bool hasPending() const { return !m_timeQueue.isEmpty(); }

    Q_INVOKABLE void prepareSurfaceData(
        const QString &startStr,
        const QString &endStr,
        int hoursStep
        );

    Q_INVOKABLE void startBatchDownload(
        const QString &startStr,
        const QString &endStr,
        int hoursStep
        );

    Q_INVOKABLE void checkLocation(
        double latitude,
        double longitude
        );

    Q_INVOKABLE void downloadNext();

signals:
    void progressChanged();
    void isDownloadingChanged();

    void logMessage(const QString &message);

    void downloadFinished(
        bool success,
        const QString &message
        );

    void locationCheckFinished(
        bool success,
        bool isLand,
        const QString &message
        );

    void initialSurfaceDataLoaded(
        bool success,
        const QString &message
        );

    void surfaceDataLoaded(
        QDateTime time,
        bool success,
        QString message
        );

private:
    bool loadCredentials();

    void setProgress(int value);
    void setDownloading(bool value);

    void processCurrentDownload();

    void handleDownloadFailure(
        const QDateTime &time,
        bool isInitialLoad,
        const QString &message
        );

    QString m_username;
    QString m_password;

    int m_progress = 0;
    int m_completedTasks = 0;
    int m_totalTasks = 0;

    bool m_isDownloading = false;
    bool m_initialLoadPending = false;

    QQueue<QDateTime> m_timeQueue;

    SurfaceCurrentData m_surfaceData;
};

#endif