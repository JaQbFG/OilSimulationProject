#include "SurfaceCurrentParser.h"

#include <QFile>
#include <QTextStream>
#include <QStringList>
#include <QtMath>
#include <QTimeZone>
#include <cmath>
using namespace std;

bool SurfaceCurrentParser::loadCsv(
    const QString &filePath,
    SurfaceCurrentData &result,
    QString *errorMessage)
{
    result = SurfaceCurrentData{};

    QFile file(filePath);

    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        if (errorMessage) {
            *errorMessage = "Nie można otworzyć pliku: " + filePath;
        }

        return false;
    }

    QTextStream in(&file);

    if (in.atEnd()) {
        if (errorMessage) {
            *errorMessage = "Plik CSV jest pusty.";
        }

        return false;
    }
    in.readLine();

    bool firstPoint = true;
    int validPoints = 0;
    int lineNumber = 1;

    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        lineNumber++;

        if (line.isEmpty()) {
            continue;
        }

        QStringList columns = line.split(',');

        if (columns.size() != 6) {
            if (errorMessage) {
                *errorMessage = QString(
                                    "Nieprawidłowa liczba kolumn w wierszu %1."
                                    ).arg(lineNumber);
            }

            return false;
        }

        QString timeText = columns[0].trimmed();

        QDateTime pointTime = QDateTime::fromString(
            timeText,
            "yyyy-MM-dd HH:mm:ss"
            );

        if (!pointTime.isValid()) {

            if (errorMessage) {
                *errorMessage = QString(
                                    "Nieprawidłowy czas w wierszu %1."
                                    ).arg(lineNumber);
            }

            return false;
        }
        pointTime.setTimeZone(QTimeZone::utc());

        bool depthOk = false;

        double depth = columns[1].trimmed().toDouble(&depthOk);

        if (!depthOk || !isfinite(depth)) {
            if (errorMessage) {
                *errorMessage = QString(
                                    "Nieprawidłowa głębokość w wierszu %1."
                                    ).arg(lineNumber);
            }

            return false;
        }

        bool latitudeOk = false;

        double latitude =
            columns[2].trimmed().toDouble(&latitudeOk);

        bool longitudeOk = false;

        double longitude =
            columns[3].trimmed().toDouble(&longitudeOk);

        if (!latitudeOk || !longitudeOk ||
            !isfinite(latitude) ||
            !isfinite(longitude) ||
            latitude < -90.0 || latitude > 90.0 ||
            longitude < -180.0 || longitude > 180.0) {

            if (errorMessage) {
                *errorMessage = QString(
                                    "Nieprawidłowe współrzędne w wierszu %1."
                                    ).arg(lineNumber);
            }

            return false;
        }

        bool uOk = false;

        double u = columns[4].trimmed().toDouble(&uOk);

        bool vOk = false;

        double v = columns[5].trimmed().toDouble(&vOk);

        bool currentValid =
            uOk && vOk &&
            isfinite(u) &&
            isfinite(v);

        if (firstPoint) {
            result.time = pointTime;
            result.depth = depth;

            firstPoint = false;
        } else {
            if (pointTime != result.time ||
                qAbs(depth - result.depth) > 0.0001) {

                if (errorMessage) {
                    *errorMessage =
                        "CSV zawiera wiele terminów lub poziomów "
                        "głębokości. Oczekiwano jednego czasu "
                        "i jednego poziomu.";
                }

                return false;
            }
        }

        SurfaceCurrentPoint point;

        point.latitude = latitude;
        point.longitude = longitude;

        point.u = currentValid
                      ? static_cast<float>(u)
                      : 0.0f;

        point.v = currentValid
                      ? static_cast<float>(v)
                      : 0.0f;

        point.valid = currentValid;

        result.points.append(point);

        if (currentValid) {
            validPoints++;
        }
    }

    file.close();

    if (result.points.isEmpty()) {
        if (errorMessage) {
            *errorMessage = "Plik nie zawiera żadnych punktów.";
        }

        return false;
    }

    if (validPoints == 0) {
        if (errorMessage) {
            *errorMessage =
                "Nie znaleziono żadnych poprawnych wartości prądu.";
        }

        return false;
    }

    return true;
}