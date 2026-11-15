#include "currentfield.h"

#include <QtMath>
#include <algorithm>
#include <cmath>

namespace {


}

bool CurrentField::build(const SurfaceCurrentData &data)
{
    m_ready = false;

    if (data.points.isEmpty()) {
        return false;
    }



    double maxLat = -1e9;
    double maxLon = -1e9;
    m_minLat = 1e9;
    m_minLon = 1e9;

    for (const SurfaceCurrentPoint &p : data.points) {

        m_minLat = std::min(m_minLat, p.latitude);
        maxLat   = std::max(maxLat,   p.latitude);
        m_minLon = std::min(m_minLon, p.longitude);
        maxLon   = std::max(maxLon,   p.longitude);
    }

    m_dLat = 1.0 / 12.0;
    m_dLon = 1.0 / 12.0;

    if (m_dLat <= 0.0 || m_dLon <= 0.0) {
        return false;
    }

    m_nLat = qRound((maxLat - m_minLat) / m_dLat) + 1;
    m_nLon = qRound((maxLon - m_minLon) / m_dLon) + 1;

    if (m_nLat < 2 || m_nLon < 2
        || static_cast<qint64>(m_nLat) * m_nLon > 50000000) {
        return false;
    }

    const int total = m_nLat * m_nLon;

    m_u.fill(0.0f, total);
    m_v.fill(0.0f, total);
    m_valid.fill(0, total);

    for (const SurfaceCurrentPoint &p : data.points) {
        const int i = qBound(0,
            qRound((p.latitude - m_minLat) / m_dLat), m_nLat - 1);
        const int j = qBound(0,
            qRound((p.longitude - m_minLon) / m_dLon), m_nLon - 1);

        const int idx = index(i, j);

        m_u[idx] = p.u;
        m_v[idx] = p.v;
        m_valid[idx] = p.valid ? 1 : 0;
    }

    m_ready = true;
    return true;
}

bool CurrentField::contains(double latitude, double longitude) const
{
    if (!m_ready) {
        return false;
    }

    return latitude  >= m_minLat
        && latitude  <= m_minLat + (m_nLat - 1) * m_dLat
        && longitude >= m_minLon
        && longitude <= m_minLon + (m_nLon - 1) * m_dLon;
}

CurrentSample CurrentField::sample(double latitude, double longitude) const
{
    CurrentSample out;

    if (!contains(latitude, longitude)) {
        return out;
    }

    const double fy = (latitude  - m_minLat) / m_dLat;
    const double fx = (longitude - m_minLon) / m_dLon;

    const int ni = qBound(0, qRound(fy), m_nLat - 1);
    const int nj = qBound(0, qRound(fx), m_nLon - 1);

    if (!m_valid[index(ni, nj)]) {
        return out;
    }

    const int i0 = qBound(0, static_cast<int>(fy), m_nLat - 2);
    const int j0 = qBound(0, static_cast<int>(fx), m_nLon - 2);

    const double ty = fy - i0;
    const double tx = fx - j0;

    const double weights[4] = {
        (1.0 - ty) * (1.0 - tx),
        (1.0 - ty) * tx,
        ty * (1.0 - tx),
        ty * tx
    };

    const int cells[4] = {
        index(i0,     j0),
        index(i0,     j0 + 1),
        index(i0 + 1, j0),
        index(i0 + 1, j0 + 1)
    };

    double sumW = 0.0;
    double u = 0.0;
    double v = 0.0;


    for (int k = 0; k < 4; ++k) {
        if (m_valid[cells[k]]) {
            sumW += weights[k];
            u += weights[k] * m_u[cells[k]];
            v += weights[k] * m_v[cells[k]];
        }
    }

    if (sumW <= 0.0) {
        return out;
    }

    out.u = u / sumW;
    out.v = v / sumW;
    out.valid = true;

    return out;
}
