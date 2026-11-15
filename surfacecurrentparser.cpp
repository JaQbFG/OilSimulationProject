#include "SurfaceCurrentParser.h"
#include <QByteArray>
#include <QFile>
#include <QtMath>
#include <QTimeZone>
#include <cmath>
#include <charconv>
#include <cstring>

namespace {

inline bool parseNumber(const char *b, const char *e, double &out)
{
    while (b < e && (*b == ' ' || *b == '\t')) ++b;
    while (e > b && (e[-1] == ' ' || e[-1] == '\t' || e[-1] == '\r')) --e;

    if (b == e) return false;
    if (*b == '+') ++b;

    const auto r = std::from_chars(b, e, out);
    return r.ec == std::errc() && r.ptr == e;
}

}
using namespace std;

bool SurfaceCurrentParser::loadCsv(
    const QString &filePath,
    SurfaceCurrentData &result,
    QString *errorMessage)
{
    result = SurfaceCurrentData{};

    auto fail = [&](const QString &message) {
        if (errorMessage) {
            *errorMessage = message;
        }
        return false;
    };

    QFile file(filePath);

    if (!file.open(QIODevice::ReadOnly)) {
        return fail("Nie można otworzyć pliku: " + filePath);
    }

    const QByteArray raw = file.readAll();
    file.close();

    const char *p = raw.constData();
    const char *const end = p + raw.size();

    if (p == end) {
        return fail("Plik CSV jest pusty.");
    }

    const char *headerEnd =
        static_cast<const char *>(memchr(p, '\n', end - p));

    if (!headerEnd) {
        return fail("Plik nie zawiera żadnych punktów.");
    }

    p = headerEnd + 1;

    result.points.reserve(static_cast<int>(raw.size() / 50));

    QByteArray firstTime;
    bool firstPoint = true;
    int validPoints = 0;
    int lineNumber = 1;

    while (p < end) {
        const char *lineEnd =
            static_cast<const char *>(memchr(p, '\n', end - p));

        if (!lineEnd) {
            lineEnd = end;
        }

        const char *line = p;
        p = (lineEnd < end) ? lineEnd + 1 : end;
        ++lineNumber;

        const char *le = lineEnd;
        while (le > line && (le[-1] == '\r' || le[-1] == ' ')) --le;

        if (le == line) {
            continue;
        }

        const char *fb[6];
        const char *fe[6];
        int n = 0;
        const char *s = line;

        while (n < 6) {
            const char *comma =
                static_cast<const char *>(memchr(s, ',', le - s));

            fb[n] = s;

            if (!comma) {
                fe[n] = le;
                ++n;
                break;
            }

            fe[n] = comma;
            ++n;
            s = comma + 1;
        }

        if (n != 6 || memchr(fb[5], ',', fe[5] - fb[5]) != nullptr) {
            return fail(QString("Nieprawidłowa liczba kolumn w wierszu %1.")
                            .arg(lineNumber));
        }

        const qsizetype timeLen = fe[0] - fb[0];

        if (firstPoint) {
            const QString timeText =
                QString::fromLatin1(fb[0], timeLen).trimmed();

            QDateTime t = QDateTime::fromString(
                timeText, "yyyy-MM-dd HH:mm:ss");

            if (!t.isValid()) {
                const QDate d = QDate::fromString(timeText, "yyyy-MM-dd");

                if (d.isValid()) {
                    t = QDateTime(d, QTime(0, 0), QTimeZone::utc());
                }
            }

            if (!t.isValid()) {
                return fail(QString("Nieprawidłowy czas w wierszu %1.")
                                .arg(lineNumber));
            }

            t.setTimeZone(QTimeZone::utc());
            result.time = t;
            firstTime = QByteArray(fb[0], timeLen);
        } else if (timeLen != firstTime.size() ||
                   memcmp(fb[0], firstTime.constData(), timeLen) != 0) {
            return fail("CSV zawiera wiele terminów lub poziomów "
                        "głębokości. Oczekiwano jednego czasu "
                        "i jednego poziomu.");
        }

        double depth = 0.0;

        if (!parseNumber(fb[1], fe[1], depth) || !isfinite(depth)) {
            return fail(QString("Nieprawidłowa głębokość w wierszu %1.")
                            .arg(lineNumber));
        }

        double latitude = 0.0;
        double longitude = 0.0;

        if (!parseNumber(fb[2], fe[2], latitude) ||
            !parseNumber(fb[3], fe[3], longitude) ||
            !isfinite(latitude) || !isfinite(longitude) ||
            latitude < -90.0 || latitude > 90.0 ||
            longitude < -180.0 || longitude > 180.0) {
            return fail(QString("Nieprawidłowe współrzędne w wierszu %1.")
                            .arg(lineNumber));
        }

        if (firstPoint) {
            result.depth = depth;
            firstPoint = false;
        } else if (qAbs(depth - result.depth) > 0.0001) {
            return fail("CSV zawiera wiele terminów lub poziomów "
                        "głębokości. Oczekiwano jednego czasu "
                        "i jednego poziomu.");
        }

        double u = 0.0;
        double v = 0.0;

        const bool currentValid =
            parseNumber(fb[4], fe[4], u) &&
            parseNumber(fb[5], fe[5], v) &&
            isfinite(u) && isfinite(v);

        SurfaceCurrentPoint point;
        point.latitude = latitude;
        point.longitude = longitude;
        point.u = currentValid ? static_cast<float>(u) : 0.0f;
        point.v = currentValid ? static_cast<float>(v) : 0.0f;
        point.valid = currentValid;

        result.points.append(point);

        if (currentValid) {
            ++validPoints;
        }
    }



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