#ifndef SURFACECURRENTPARSER_H
#define SURFACECURRENTPARSER_H

#include "OceanData.h"

#include <QString>

class SurfaceCurrentParser
{
public:
    static bool loadCsv(
        const QString &filePath,
        SurfaceCurrentData &result,
        QString *errorMessage = nullptr
        );
};

#endif