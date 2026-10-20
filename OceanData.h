#ifndef OCEANDATA_H
#define OCEANDATA_H

#include <QDateTime>
#include <QVector>

struct SurfaceCurrentPoint
{
    double latitude = 0.0;
    double longitude = 0.0;

    float u = 0.0f;
    float v = 0.0f;

    bool valid = false;
};

struct SurfaceCurrentData
{
    QDateTime time;
    double depth = 0.0;

    QVector<SurfaceCurrentPoint> points;
};

#endif