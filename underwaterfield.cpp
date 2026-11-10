#include "underwaterfield.h"

#include <algorithm>

namespace {

QVector<double> uniqueSorted(QVector<double> v, double tol)
{
    std::sort(v.begin(), v.end());

    QVector<double> out;

    for (double x : v) {
        if (out.isEmpty() || x - out.last() > tol) {
            out.append(x);
        }
    }

    return out;
}

int nearestIndex(const QVector<double> &v, double x)
{
    const int hi = static_cast<int>(
        std::lower_bound(v.begin(), v.end(), x) - v.begin());

    if (hi == 0) {
        return 0;
    }

    if (hi == v.size()) {
        return v.size() - 1;
    }

    return (x - v[hi - 1] <= v[hi] - x) ? hi - 1 : hi;
}


void locate(const QVector<double> &v, double x, int &i0, int &i1, double &t)
{
    const int n = v.size();

    if (n == 1 || x <= v.first()) {
        i0 = i1 = 0;
        t = 0.0;
        return;
    }

    if (x >= v.last()) {
        i0 = i1 = n - 1;
        t = 0.0;
        return;
    }

    i1 = static_cast<int>(
        std::upper_bound(v.begin(), v.end(), x) - v.begin());
    i0 = i1 - 1;
    t = (x - v[i0]) / (v[i1] - v[i0]);
}

}

bool UnderwaterField::build(const UnderwaterCurrentData &data)
{
    m_ready = false;

    if (data.points.isEmpty()) {
        return false;
    }

    QVector<double> lats;
    QVector<double> lons;
    QVector<double> depths;

    lats.reserve(data.points.size());
    lons.reserve(data.points.size());
    depths.reserve(data.points.size());

    for (const UnderwaterCurrentPoint &p : data.points) {
        lats.append(p.latitude);
        lons.append(p.longitude);
        depths.append(p.depth);
    }

    m_lats = uniqueSorted(lats, 1e-3);
    m_lons = uniqueSorted(lons, 1e-3);
    m_depths = uniqueSorted(depths, 1e-3);

    if (m_lats.size() < 2 || m_lons.size() < 2 || m_depths.isEmpty()) {
        return false;
    }

    const qint64 total =
        static_cast<qint64>(m_lats.size()) * m_lons.size() * m_depths.size();

    if (total > 50000000) {
        return false;
    }

    m_u.fill(0.0f, static_cast<int>(total));
    m_v.fill(0.0f, static_cast<int>(total));
    m_valid.fill(0, static_cast<int>(total));

    for (const UnderwaterCurrentPoint &p : data.points) {
        const int i = nearestIndex(m_lats, p.latitude);
        const int j = nearestIndex(m_lons, p.longitude);
        const int k = nearestIndex(m_depths, p.depth);

        const int idx = index(k, i, j);

        m_u[idx] = p.u;
        m_v[idx] = p.v;
        m_valid[idx] = p.valid ? 1 : 0;
    }

    m_ready = true;
    return true;
}

CurrentSample UnderwaterField::sample(double latitude,
                                      double longitude,
                                      double depth) const
{
    CurrentSample out;

    if (!m_ready) {
        return out;
    }

    if (latitude < m_lats.first() || latitude > m_lats.last() ||
        longitude < m_lons.first() || longitude > m_lons.last()) {
        return out;
    }

    const int nk = nearestIndex(m_depths, depth);
    const int ni = nearestIndex(m_lats, latitude);
    const int nj = nearestIndex(m_lons, longitude);

    if (!m_valid[index(nk, ni, nj)]) {
        return out;
    }

    int i0, i1, j0, j1, k0, k1;
    double ty, tx, tz;

    locate(m_lats, latitude, i0, i1, ty);
    locate(m_lons, longitude, j0, j1, tx);
    locate(m_depths, depth, k0, k1, tz);

    const int ks[2] = { k0, k1 };
    const int is[2] = { i0, i1 };
    const int js[2] = { j0, j1 };

    const double wk[2] = { 1.0 - tz, tz };
    const double wi[2] = { 1.0 - ty, ty };
    const double wj[2] = { 1.0 - tx, tx };

    double sumW = 0.0;
    double u = 0.0;
    double v = 0.0;

    for (int a = 0; a < 2; ++a) {
        for (int b = 0; b < 2; ++b) {
            for (int c = 0; c < 2; ++c) {
                const double w = wk[a] * wi[b] * wj[c];

                if (w <= 0.0) {
                    continue;
                }

                const int idx = index(ks[a], is[b], js[c]);

                if (m_valid[idx]) {
                    sumW += w;
                    u += w * m_u[idx];
                    v += w * m_v[idx];
                }
            }
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
