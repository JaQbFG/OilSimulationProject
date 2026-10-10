#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "CopernicusManager.h"
int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    CopernicusManager copernicusManager;

    engine.rootContext()->setContextProperty("copernicusManager", &copernicusManager);

    engine.loadFromModule("OilSpillProject", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}