#ifndef OILSIMULATION_H
#define OILSIMULATION_H

#include "currentfield.h"
#include "OceanData.h"

#include <QObject>
#include <QTimer>
#include <QVector>
#include <QVariantList>

#include <random>

struct OilParticle
{
    enum State { Floating, Beached, Left };

    double latitude = 0.0;
    double longitude = 0.0;

    double age = 0.0;   // [s]
    double mass = 1.0;  // arbitrary units for now

    State state = Floating;
};

class OilSimulation : public QObject
{
    Q_OBJECT

    // Spill source
    Q_PROPERTY(double spillLatitude  MEMBER m_spillLat  NOTIFY paramsChanged)
    Q_PROPERTY(double spillLongitude MEMBER m_spillLon  NOTIFY paramsChanged)
    Q_PROPERTY(double releaseRate    MEMBER m_releaseRate NOTIFY paramsChanged) // particles / hour

    // Physics
    Q_PROPERTY(double diffusivity MEMBER m_diffusivity NOTIFY paramsChanged)   // [m^2/s]

    // Time
    Q_PROPERTY(double timeStep MEMBER m_timeStep NOTIFY paramsChanged)         // simulated s per step
    Q_PROPERTY(double dataInterval MEMBER m_dataInterval NOTIFY paramsChanged) // simulated s covered by one data file (3600)
    Q_PROPERTY(bool waitingForData READ waitingForData NOTIFY waitingChanged)

    Q_PROPERTY(int particleCount READ particleCount NOTIFY stepped)
    Q_PROPERTY(double elapsedSeconds READ elapsedSeconds NOTIFY stepped)
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)

public:
    explicit OilSimulation(QObject *parent = nullptr);

    // Builds the lookup grid. Call after the surface data is loaded.
    bool setCurrentData(const SurfaceCurrentData &data);

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void reset();
    Q_INVOKABLE void step();   // one step of timeStep seconds

    // Handy for debugging from QML: [{lat, lon, state}, ...]
    Q_INVOKABLE QVariantList particlePositions() const;

    const QVector<OilParticle> &particles() const { return m_particles; }

    int particleCount() const { return m_particles.size(); }
    double elapsedSeconds() const { return m_elapsed; }
    bool running() const { return m_active; }
    bool waitingForData() const { return m_waiting; }

signals:
    // The current data file has been used up; load the next one with
    // setCurrentData() (or call stop() if there is none).
    void dataExhausted();
    void waitingChanged();
    void paramsChanged();
    void stepped();
    void runningChanged();
    void logMessage(const QString &message);

private:
    void release(double dt);
    void advect(OilParticle &p, double dt);

    static void moveMeters(double &lat, double &lon,
                           double east, double north);

    CurrentField m_field;   // total surface current (utotal/vtotal)
    QVector<OilParticle> m_particles;
    QTimer m_timer;

    double m_spillLat = 0.0;
    double m_spillLon = 0.0;
    double m_releaseRate = 3600.0;   // 1 particle / s of simulated time

    double m_diffusivity = 10.0;     // m^2/s, typical 1-100

    double m_timeStep = 600.0;       // 10 min per step

    double m_dataInterval = 3600.0;  // one hourly file
    double m_dataElapsed = 0.0;      // simulated s spent on the current file
    bool m_waiting = false;          // paused, waiting for next file
    bool m_active = false;           // user pressed start

    double m_elapsed = 0.0;
    double m_releaseCarry = 0.0;

    int m_maxParticles = 50000;

    std::mt19937_64 m_rng;
    std::normal_distribution<double> m_normal{0.0, 1.0};
};

#endif
