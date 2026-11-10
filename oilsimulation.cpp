#include "oilsimulation.h"

#include <QtMath>
#include <cmath>
#include <QDateTime>

namespace {
constexpr double kEarthRadius = 6371000.0;
constexpr double kRadToDeg = 180.0 / M_PI;
double kSurfaceLevel = 0.494;
}

OilSimulation::OilSimulation(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
{
    m_timer.setInterval(33);

    connect(&m_timer, &QTimer::timeout, this, &OilSimulation::step);
}

bool OilSimulation::setCurrentData(const SurfaceCurrentData &data)
{
    const bool ok = m_field.build(data);

    emit logMessage(ok ? "Siatka prądów gotowa dla symulacji."
                       : "Nie udało się zbudować siatki prądów.");

    if (ok) {
        m_dataElapsed = 0.0;
        m_dataTime = data.time;

        if (m_waiting) {
            m_waiting = false;
            emit waitingChanged();

            if (m_active) {
                m_timer.start();
            }
        }
    }

    return ok;
}

void OilSimulation::start()
{
    if (!m_field.isReady()) {
        emit logMessage("Symulacja: brak danych o prądach.");
        return;
    }

    if (!m_active) {
        m_active = true;
        emit runningChanged();
    }

    if (!m_waiting && !m_timer.isActive()) {
        m_timer.start();
    }
}

void OilSimulation::stop()
{
    m_timer.stop();

    if (m_active) {
        m_active = false;
        emit runningChanged();
    }
}

void OilSimulation::reset()
{
    stop();

    m_particles.clear();
    m_elapsed = 0.0;
    m_releaseCarry = 0.0;
    m_dataElapsed = 0.0;
    m_events.clear();
    m_nextId = 0;
    m_beachedCount = 0;
    m_leftCount = 0;
    m_surfacedLogged = false;

    if (m_waiting) {
        m_waiting = false;
        emit waitingChanged();
    }

    emit stepped();
}

void OilSimulation::step()
{
    if (!m_field.isReady() || m_timeStep <= 0.0 || m_waiting) {
        return;
    }

    const double dt = qMin(m_timeStep, m_dataInterval - m_dataElapsed);

    if (dt <= 0.0) {
        return;
    }

    release(dt);

    for (OilParticle &p : m_particles) {
        if (p.state == OilParticle::Floating) {
            advect(p, dt);
        }
    }

    m_elapsed += dt;
    m_dataElapsed += dt;

    emit stepped();

    if (m_dataElapsed >= m_dataInterval - 1e-6) {
        m_waiting = true;
        m_timer.stop();

        emit waitingChanged();
        emit logMessage("Plik danych wykorzystany. Oczekiwanie na kolejny.");
        emit dataExhausted();
    }
}

void OilSimulation::release(double dt)
{
    m_releaseCarry += m_releaseRate * dt / 3600.0;

    int count = static_cast<int>(m_releaseCarry);
    m_releaseCarry -= count;

    count = qMin(count, m_maxParticles - m_particles.size());

    for (int i = 0; i < count; ++i) {
        OilParticle p;
        p.id = m_nextId++;
        p.latitude = m_spillLat;
        p.longitude = m_spillLon;
        p.depth = m_releaseDepth;
        m_particles.append(p);
    }
}

void OilSimulation::moveMeters(double &lat, double &lon,
                               double east, double north)
{
    const double cosLat = qMax(0.01, std::cos(qDegreesToRadians(lat)));

    lat += (north / kEarthRadius) * kRadToDeg;
    lon += (east / (kEarthRadius * cosLat)) * kRadToDeg;
}

void OilSimulation::advect(OilParticle &p, double dt)
{
    if (p.depth > kSurfaceLevel) {
        advectUnderwater(p, dt);
        return;
    }
    p.age += dt;

    const CurrentSample s1 = m_field.sample(p.latitude, p.longitude);

    if (!s1.valid) {
        p.state = m_field.contains(p.latitude, p.longitude)
                      ? OilParticle::Beached
                      : OilParticle::Left;
        recordEvent(p, dt);
        return;
    }

    const double u1 = s1.u;
    const double v1 = s1.v;

    double midLat = p.latitude;
    double midLon = p.longitude;
    moveMeters(midLat, midLon, u1 * dt * 0.5, v1 * dt * 0.5);

    const CurrentSample s2 = m_field.sample(midLat, midLon);

    const double u2 = s2.valid ? s2.u : u1;
    const double v2 = s2.valid ? s2.v : v1;

    double newLat = p.latitude;
    double newLon = p.longitude;
    moveMeters(newLat, newLon, u2 * dt, v2 * dt);

    const double sigma = std::sqrt(2.0 * m_diffusivity * dt);

    moveMeters(newLat, newLon,
               m_normal(m_rng) * sigma,
               m_normal(m_rng) * sigma);

    const CurrentSample target = m_field.sample(newLat, newLon);

    if (!target.valid) {
        if (m_field.contains(newLat, newLon)) {
            p.state = OilParticle::Beached;
        } else {
            p.latitude = newLat;
            p.longitude = newLon;
            p.state = OilParticle::Left;
        }
        recordEvent(p, dt);
        return;
    }

    p.latitude = newLat;
    p.longitude = newLon;
}

QVariantList OilSimulation::particlePositions() const
{
    QVariantList list;
    list.reserve(m_particles.size());

    for (const OilParticle &p : m_particles) {
        QVariantMap m;
        m["lat"] = p.latitude;
        m["lon"] = p.longitude;
        m["state"] = static_cast<int>(p.state);
        m["id"] = p.id;
        m["depth"] = p.depth;
        list.append(m);
    }

    return list;
}
QDateTime OilSimulation::timeAfter(double dt) const
{
    if (!m_dataTime.isValid())
        return QDateTime();
    return m_dataTime.addMSecs(static_cast<qint64>((m_dataElapsed + dt) * 1000.0));
}

QString OilSimulation::currentTimeText() const
{
    return timeAfter(0.0).toString("yyyy-MM-dd HH:mm:ss");
}

void OilSimulation::recordEvent(const OilParticle &p, double dt)
{
    ParticleEvent e;
    e.particleId = p.id;
    e.state = p.state;
    e.latitude = p.latitude;
    e.longitude = p.longitude;
    e.simSeconds = m_elapsed + dt;
    e.time = timeAfter(dt);
    m_events.append(e);

    if (p.state == OilParticle::Beached) ++m_beachedCount; else ++m_leftCount;

    const QString t = e.time.toString("yyyy-MM-dd HH:mm:ss");

    emit logMessage(QString("Cząsteczka #%1 %2: lat=%3, lon=%4, %5 UTC")
                        .arg(e.particleId)
                        .arg(p.state == OilParticle::Beached ? "osiadła na brzegu" : "opuściła obszar danych")
                        .arg(e.latitude, 0, 'f', 5)
                        .arg(e.longitude, 0, 'f', 5)
                        .arg(t));

    emit particleEvent(e.particleId, e.latitude, e.longitude,
                       e.simSeconds, t, static_cast<int>(e.state));
}

QVariantList OilSimulation::eventLog() const
{
    QVariantList list;
    for (const ParticleEvent &e : m_events) {
        QVariantMap m;
        m["id"] = e.particleId;
        m["lat"] = e.latitude;
        m["lon"] = e.longitude;
        m["t"] = e.simSeconds;
        m["time"] = e.time.toString("yyyy-MM-dd HH:mm:ss");
        m["state"] = static_cast<int>(e.state);
        list.append(m);
    }
    return list;
}
bool OilSimulation::setUnderwaterData(const UnderwaterCurrentData &data)
{
    const bool ok = m_underwater.build(data);

    emit logMessage(ok ? "Siatka prądów podwodnych gotowa."
                       : "Nie udało się zbudować siatki prądów podwodnych.");
    return ok;
}

void OilSimulation::advectUnderwater(OilParticle &p, double dt)
{
    p.age += dt;

    const double newDepth = qMax(0.0, p.depth - m_riseSpeed * dt);
    const double midDepth = 0.5 * (p.depth + newDepth);

    double newLat = p.latitude;
    double newLon = p.longitude;

    const CurrentSample s1 = m_underwater.sample(p.latitude, p.longitude, p.depth);

    if (s1.valid) {
        double midLat = p.latitude;
        double midLon = p.longitude;
        moveMeters(midLat, midLon, s1.u * dt * 0.5, s1.v * dt * 0.5);

        const CurrentSample s2 = m_underwater.sample(midLat, midLon, midDepth);

        const double u = s2.valid ? s2.u : s1.u;
        const double v = s2.valid ? s2.v : s1.v;

        moveMeters(newLat, newLon, u * dt, v * dt);
    }


    const double sigma = std::sqrt(2.0 * m_diffusivity * dt);
    moveMeters(newLat, newLon,
               m_normal(m_rng) * sigma,
               m_normal(m_rng) * sigma);


    if (m_underwater.isReady() &&
        !m_underwater.sample(newLat, newLon, newDepth).valid) {
        newLat = p.latitude;
        newLon = p.longitude;
    }

    p.latitude = newLat;
    p.longitude = newLon;
    p.depth = newDepth;

    if (p.depth <= kSurfaceLevel && !m_surfacedLogged) {
        m_surfacedLogged = true;
        emit logMessage(
            QString("Pierwsza cząsteczka (#%1) wypłynęła na powierzchnię: %2 UTC")
                .arg(p.id)
                .arg(timeAfter(dt).toString("yyyy-MM-dd HH:mm:ss")));
    }
}
