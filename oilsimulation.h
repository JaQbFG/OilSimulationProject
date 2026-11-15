#ifndef OILSIMULATION_H
#define OILSIMULATION_H

#include "currentfield.h"
#include "OceanData.h"

#include <QObject>
#include <QTimer>
#include <QVector>
#include <QVariantList>
#include <QDateTime>
#include <random>
#include "underwaterfield.h"

struct OilParticle
{
    enum State { Floating, Beached, Left };
    int id=0;
    double latitude = 0.0;
    double longitude = 0.0;
    double depth = 0.0;
    double age = 0.0;
    double mass = 1.0;   // liters of oil represented by this blob

    State state = Floating;
};
struct ParticleEvent
{
    int particleId = 0;
    OilParticle::State state = OilParticle::Beached;
    double latitude = 0.0;
    double longitude = 0.0;
    double simSeconds = 0.0;
    QDateTime time;
};
class OilSimulation : public QObject
{
    Q_OBJECT


    Q_PROPERTY(double spillLatitude  MEMBER m_spillLat  NOTIFY paramsChanged)
    Q_PROPERTY(double spillLongitude MEMBER m_spillLon  NOTIFY paramsChanged)
    Q_PROPERTY(double releaseDepth MEMBER m_releaseDepth NOTIFY paramsChanged) //m
    Q_PROPERTY(double riseSpeed    MEMBER m_riseSpeed    NOTIFY paramsChanged) //m/s
    Q_PROPERTY(double releaseRate    MEMBER m_releaseRate NOTIFY paramsChanged) //particles/hour
    Q_PROPERTY(int beachedCount READ beachedCount NOTIFY stepped)
    Q_PROPERTY(int leftCount READ leftCount NOTIFY stepped)

    // Spill size
    Q_PROPERTY(double spillVolumeLiters MEMBER m_spillVolumeLiters NOTIFY paramsChanged) //oil on board [l] = upper limit of what can leak
    Q_PROPERTY(double leakRateLitersPerHour MEMBER m_leakRate NOTIFY paramsChanged) //constant outflow [l/h]; 0 = whole spillVolume over releaseDuration
    Q_PROPERTY(double blobVolumeLiters  MEMBER m_blobVolumeLiters  NOTIFY paramsChanged) //oil per particle [l]
    Q_PROPERTY(double releaseDuration   MEMBER m_releaseDuration   NOTIFY paramsChanged) //s, length of the run the leak lasts; 0 = use releaseRate
    Q_PROPERTY(double spilledLiters READ spilledLiters NOTIFY paramsChanged)
    Q_PROPERTY(int totalParticles READ totalParticles NOTIFY paramsChanged)
    Q_PROPERTY(double effectiveBlobLiters READ effectiveBlobLiters NOTIFY paramsChanged)


    Q_PROPERTY(double diffusivity MEMBER m_diffusivity NOTIFY paramsChanged) //[m^2/s]


    Q_PROPERTY(double timeStep MEMBER m_timeStep NOTIFY paramsChanged) //simulated secs per step
    Q_PROPERTY(double dataInterval MEMBER m_dataInterval NOTIFY paramsChanged) //simulated secs covered by one data file
    Q_PROPERTY(bool waitingForData READ waitingForData NOTIFY waitingChanged)

    Q_PROPERTY(int particleCount READ particleCount NOTIFY stepped)
    Q_PROPERTY(double elapsedSeconds READ elapsedSeconds NOTIFY stepped)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit OilSimulation(QObject *parent = nullptr);

    bool setCurrentData(const SurfaceCurrentData &data);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void finish(); //stop + emit finished()
    Q_INVOKABLE void reset();
    Q_INVOKABLE void step(); //one step of timeStep seconds

    Q_INVOKABLE QVariantList particlePositions() const;

    const QVector<OilParticle> &particles() const { return m_particles; }

    int particleCount() const { return m_particles.size(); }
    double elapsedSeconds() const { return m_elapsed; }
    bool running() const { return m_active; }
    bool waitingForData() const { return m_waiting; }

    // Oil that actually leaves the ship during the run:
    // min(oil on board, leak rate * run length).
    double spilledLiters() const;
    // Number of blobs the spilled oil is split into.
    int totalParticles() const;
    // Oil per blob: blobVolumeLiters, or larger if the particle cap would be exceeded.
    double effectiveBlobLiters() const;

    Q_INVOKABLE QVariantList eventLog() const;
    Q_INVOKABLE QString currentTimeText() const;
    const QVector<ParticleEvent> &events() const { return m_events; }
    int beachedCount() const { return m_beachedCount; }
    int leftCount() const { return m_leftCount; }
    bool setUnderwaterData(const UnderwaterCurrentData &data);

signals:
    void dataExhausted();
    void waitingChanged();
    void paramsChanged();
    void stepped();
    void runningChanged();
    void finished();
    void logMessage(const QString &message);
    void particleEvent(int id, double latitude, double longitude,
                       double simSeconds, const QString &timeUtc, int state);

private:
    void release(double dt);
    void advect(OilParticle &p, double dt);

    static void moveMeters(double &lat, double &lon,
                           double east, double north);

    CurrentField m_field;
    QVector<OilParticle> m_particles;
    QTimer m_timer;

    double m_spillLat = 0.0;
    double m_spillLon = 0.0;
    double m_releaseRate = 3600.0;//particles per hour (used when releaseDuration == 0)

    double m_spillVolumeLiters = 0.0;//0 = unlimited (old behaviour)
    double m_blobVolumeLiters = 1000.0;
    double m_releaseDuration = 0.0;
    double m_leakRate = 0.0;//l/h, 0 = release everything over releaseDuration

    double m_diffusivity = 10.0; // m^2/s

    double m_timeStep = 600.0;//seconds per step

    double m_dataInterval = 3600.0;//seconds between files
    double m_dataElapsed = 0.0;//seconds spent on the current file
    bool m_waiting = false;//waiting for next file
    bool m_active = false;//user pressed start

    double m_elapsed = 0.0;
    double m_releaseCarry = 0.0;

    int m_maxParticles = 50000;
    void advectUnderwater(OilParticle &p, double dt);

    UnderwaterField m_underwater;
    double m_releaseDepth = 0.0;
    double m_riseSpeed = 0.2;
    bool m_surfacedLogged = false;

    std::mt19937_64 m_rng;
    std::normal_distribution<double> m_normal{0.0, 1.0};

    void recordEvent(const OilParticle &p, double dt);
    QDateTime timeAfter(double dt) const;

    QVector<ParticleEvent> m_events;
    QDateTime m_dataTime;
    int m_nextId = 0;
    int m_beachedCount = 0;
    int m_leftCount = 0;
};

#endif
