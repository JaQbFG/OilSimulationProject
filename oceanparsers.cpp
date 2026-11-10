#include "oceanparsers.h"

#include <QFile>
#include <QTextStream>
#include <QStringList>
#include <QDateTime>
#include <QTimeZone>
#include <QtMath>

#include <cmath>
#include <limits>

namespace {

bool parseUtcTime(const QString &text, QDateTime &out)
{
    QDateTime dt = QDateTime::fromString(
        QString(text).replace(' ', 'T'),
        Qt::ISODate
        );

    if (!dt.isValid()) {
        return false;
    }

    dt.setTimeZone(QTimeZone::utc());
    out = dt;
    return true;
}

}

bool BathymetryParser::loadCsv(
    const QString &filePath,
    BathymetryData &result,
    QString *errorMessage)
{
    result = BathymetryData{};

    auto fail = [&](const QString &message) {
        if (errorMessage) {
            *errorMessage = message;
        }
        return false;
    };

    QFile file(filePath);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return fail("Nie można otworzyć pliku: " + filePath);
    }

    QTextStream in(&file);

    if (in.atEnd()) {
        return fail("Pusty plik batymetrii.");
    }

    const QStringList header =
        in.readLine().trimmed().toLower().split(',');

    const int latIndex = header.indexOf("latitude");
    const int lonIndex = header.indexOf("longitude");

    int depthIndex = header.indexOf("deptho");
    if (depthIndex < 0) {
        depthIndex = header.indexOf("depth");
    }

    if (latIndex < 0 || lonIndex < 0 || depthIndex < 0) {
        return fail("Nie znaleziono kolumn latitude, longitude lub deptho.");
    }

    const int required =
        qMax(latIndex, qMax(lonIndex, depthIndex)) + 1;

    int validPoints = 0;

    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();

        if (line.isEmpty()) {
            continue;
        }

        const QStringList c = line.split(',');

        if (c.size() < required) {
            continue;
        }

        bool latOk = false;
        bool lonOk = false;
        bool depthOk = false;

        const double lat = c[latIndex].trimmed().toDouble(&latOk);
        const double lon = c[lonIndex].trimmed().toDouble(&lonOk);
        const double depth = c[depthIndex].trimmed().toDouble(&depthOk);

        if (!latOk || !lonOk ||
            !std::isfinite(lat) || !std::isfinite(lon)) {
            continue;
        }

        BathymetryPoint p;
        p.latitude = lat;
        p.longitude = lon;
        p.valid = depthOk && std::isfinite(depth) && depth != 0.0;
        p.depth = p.valid ? std::abs(depth) : 0.0;

        result.points.append(p);

        if (p.valid) {
            ++validPoints;
        }
    }

    if (validPoints == 0) {
        return fail("Nie znaleziono prawidłowej głębokości dna.");
    }

    return true;
}

bool BathymetryParser::depthAt(
    const BathymetryData &data,
    double latitude,
    double longitude,
    double *depth,
    double maxDistanceDeg)
{
    const double cosLat = qMax(0.01, qCos(qDegreesToRadians(latitude)));

    double best = std::numeric_limits<double>::max();
    const BathymetryPoint *bestPoint = nullptr;

    for (const BathymetryPoint &p : data.points) {
        if (!p.valid) {
            continue;
        }

        const double dLat = p.latitude - latitude;
        const double dLon = (p.longitude - longitude) * cosLat;
        const double d = dLat * dLat + dLon * dLon;

        if (d < best) {
            best = d;
            bestPoint = &p;
        }
    }

    if (!bestPoint || best > maxDistanceDeg * maxDistanceDeg) {
        return false;
    }

    if (depth) {
        *depth = bestPoint->depth;
    }

    return true;
}

bool UnderwaterCurrentParser::loadCsv(
    const QString &filePath,
    UnderwaterCurrentData &result,
    QString *errorMessage)
{
    result = UnderwaterCurrentData{};

    auto fail = [&](const QString &message) {
        if (errorMessage) {
            *errorMessage = message;
        }
        return false;
    };

    QFile file(filePath);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return fail("Nie można otworzyć pliku: " + filePath);
    }

    QTextStream in(&file);

    if (in.atEnd()) {
        return fail("Plik CSV jest pusty.");
    }

    const QStringList header =
        in.readLine().trimmed().toLower().split(',');

    const int timeIndex  = header.indexOf("time");
    const int depthIndex = header.indexOf("depth");
    const int latIndex   = header.indexOf("latitude");
    const int lonIndex   = header.indexOf("longitude");
    const int uIndex     = header.indexOf("uo");
    const int vIndex     = header.indexOf("vo");

    if (timeIndex < 0 || depthIndex < 0 || latIndex < 0 ||
        lonIndex < 0 || uIndex < 0 || vIndex < 0) {
        return fail("Nieoczekiwany nagłówek CSV: " + header.join(','));
    }

    const int required =
        qMax(qMax(qMax(timeIndex, depthIndex), qMax(latIndex, lonIndex)),
             qMax(uIndex, vIndex)) + 1;

    QString firstTimeText;
    int validPoints = 0;
    int lineNumber = 1;

    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        ++lineNumber;

        if (line.isEmpty()) {
            continue;
        }

        const QStringList c = line.split(',');

        if (c.size() < required) {
            return fail(QString("Za mało kolumn w wierszu %1.")
                            .arg(lineNumber));
        }

        const QString timeText = c[timeIndex].trimmed();

        if (result.points.isEmpty()) {
            if (!parseUtcTime(timeText, result.time)) {
                return fail(QString("Nieprawidłowy czas w wierszu %1.")
                                .arg(lineNumber));
            }

            firstTimeText = timeText;
        } else if (timeText != firstTimeText) {
            return fail("CSV zawiera wiele terminów. Oczekiwano jednego.");
        }

        bool depthOk = false;
        bool latOk = false;
        bool lonOk = false;

        const double depth = c[depthIndex].trimmed().toDouble(&depthOk);
        const double lat = c[latIndex].trimmed().toDouble(&latOk);
        const double lon = c[lonIndex].trimmed().toDouble(&lonOk);

        if (!depthOk || !latOk || !lonOk ||
            !std::isfinite(depth) ||
            !std::isfinite(lat) || !std::isfinite(lon)) {
            return fail(QString("Nieprawidłowe dane w wierszu %1.")
                            .arg(lineNumber));
        }

        bool uOk = false;
        bool vOk = false;

        const double u = c[uIndex].trimmed().toDouble(&uOk);
        const double v = c[vIndex].trimmed().toDouble(&vOk);

        const bool valid =
            uOk && vOk && std::isfinite(u) && std::isfinite(v);

        UnderwaterCurrentPoint p;
        p.latitude = lat;
        p.longitude = lon;
        p.depth = depth;
        p.u = valid ? static_cast<float>(u) : 0.0f;
        p.v = valid ? static_cast<float>(v) : 0.0f;
        p.valid = valid;

        result.points.append(p);

        if (valid) {
            ++validPoints;
        }
    }

    if (result.points.isEmpty()) {
        return fail("Plik nie zawiera żadnych punktów.");
    }

    if (validPoints == 0) {
        return fail("Nie znaleziono żadnych poprawnych wartości prądu.");
    }

    return true;
}
