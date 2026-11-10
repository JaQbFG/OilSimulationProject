#ifndef UNDERWATERFIELD_H
#define UNDERWATERFIELD_H

#include "currentfield.h"
#include "OceanData.h"

#include <QVector>

class UnderwaterField
{
public:
    bool build(const UnderwaterCurrentData &data);
    bool isReady() const { return m_ready; }


    CurrentSample sample(double latitude, double longitude, double depth) const;

private:
    int index(int k, int i, int j) const
    {
        return (k * m_lats.size() + i) * m_lons.size() + j;
    }

    bool m_ready = false;

    QVector<double> m_lats;
    QVector<double> m_lons;
    QVector<double> m_depths;

    QVector<float> m_u;
    QVector<float> m_v;
    QVector<quint8> m_valid;
};

#endif
