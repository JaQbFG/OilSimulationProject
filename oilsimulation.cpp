#include "oilsimulation.h"

#include <QtMath>
#include <cmath>

namespace {
constexpr double kEarthRadius = 6371000.0; // [m]
constexpr double kRadToDeg = 180.0 / M_PI;
}

OilSimulation::OilSimulation(QObject *parent)
    : QObject(parent)
    , m_rng(std::random_device{}())
{
    m_timer.setInterval(33); // ~30 steps per second (real time)

    connect(&m_timer, &QTimer::timeout, this, &OilSimulation::step);
}

bool OilSimulation::setCurrentData(const SurfaceCurrentData &data)
{
    const bool ok = m_field.build(data);

    emit logMessage(ok ? "Siatka prądów gotowa dla symulacji."
                       : "Nie udało się zbudować siatki prądów.");

    if (ok) {
        // A fresh file always starts a fresh data interval.
        m_dataElapsed = 0.0;

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

    // Never step past the end of the current data file.
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
    // Continuous release; the fractional part carries to the next step.
    m_releaseCarry += m_releaseRate * dt / 3600.0;

    int count = static_cast<int>(m_releaseCarry);
    m_releaseCarry -= count;

    count = qMin(count, m_maxParticles - m_particles.size());

    for (int i = 0; i < count; ++i) {
        OilParticle p;
        p.latitude = m_spillLat;
        p.longitude = m_spillLon;
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
    p.age += dt;

    // --- RK2 (midpoint) advection by the total surface current ---
    const CurrentSample s1 = m_field.sample(p.latitude, p.longitude);

    if (!s1.valid) {
        p.state = m_field.contains(p.latitude, p.longitude)
                      ? OilParticle::Beached
                      : OilParticle::Left;
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

    // --- Turbulent diffusion (random walk) ---
    // sigma = sqrt(2 K dt) per axis
    const double sigma = std::sqrt(2.0 * m_diffusivity * dt);

    moveMeters(newLat, newLon,
               m_normal(m_rng) * sigma,
               m_normal(m_rng) * sigma);

    // --- Boundary handling ---
    const CurrentSample target = m_field.sample(newLat, newLon);

    if (!target.valid) {
        if (m_field.contains(newLat, newLon)) {
            // Hit the coast: stay at last water position, mark beached.
            p.state = OilParticle::Beached;
        } else {
            p.latitude = newLat;
            p.longitude = newLon;
            p.state = OilParticle::Left;
        }
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
        list.append(m);
    }

    return list;
}
