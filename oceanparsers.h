#ifndef OCEANPARSERS_H
#define OCEANPARSERS_H

#include "OceanData.h"

#include <QString>

class BathymetryParser
{
public:
    static bool loadCsv(
        const QString &filePath,
        BathymetryData &result,
        QString *errorMessage = nullptr
        );


    static bool depthAt(
        const BathymetryData &data,
        double latitude,
        double longitude,
        double *depth,
        double maxDistanceDeg = 0.2
        );
};

class UnderwaterCurrentParser
{
public:

    static bool loadCsv(
        const QString &filePath,
        UnderwaterCurrentData &result,
        QString *errorMessage = nullptr
        );
};

#endif
