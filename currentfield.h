#ifndef CURRENTFIELD_H
#define CURRENTFIELD_H

#include "OceanData.h"

#include <QVector>

struct CurrentSample
{
    double u = 0.0;// east
    double v = 0.0;// north
    bool valid = false;//land or water
};


class CurrentField
{
public:
    bool build(const SurfaceCurrentData &data);
    bool isReady() const { return m_ready; }

    bool contains(double latitude, double longitude) const;

    CurrentSample sample(double latitude, double longitude) const;

private:
    int index(int latIdx, int lonIdx) const
    {
        return latIdx * m_nLon + lonIdx;
    }

    bool m_ready = false;

    double m_minLat = 0.0;
    double m_minLon = 0.0;
    double m_dLat = 0.0;
    double m_dLon = 0.0;

    int m_nLat = 0;
    int m_nLon = 0;

    QVector<float> m_u;
    QVector<float> m_v;
    QVector<quint8> m_valid;
};

#endif
