#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include "copernicusmanager.h"
#include "oilsimulation.h"

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;

    CopernicusManager copernicusManager;
    OilSimulation oilSimulation;

    // every loaded file (first one and all following) goes into the simulation
    QObject::connect(&copernicusManager, &CopernicusManager::initialSurfaceDataLoaded,
                     &oilSimulation,
                     [&](bool success, const QString &) {
                         if (success)
                             oilSimulation.setCurrentData(copernicusManager.surfaceData());
                     });

    QObject::connect(&copernicusManager, &CopernicusManager::surfaceDataLoaded,
                     &oilSimulation,
                     [&](QDateTime, bool success, QString) {
                         if (success)
                             oilSimulation.setCurrentData(copernicusManager.surfaceData());
                     });

    // simulation used up its hour: fetch the next one, or finish
    QObject::connect(&oilSimulation, &OilSimulation::dataExhausted,
                     &copernicusManager,
                     [&]() {
                         if (copernicusManager.hasPending())
                             copernicusManager.downloadNext();
                         else
                             oilSimulation.stop();
                     });
    engine.rootContext()->setContextProperty("copernicusManager", &copernicusManager);
    engine.rootContext()->setContextProperty("oilSimulation", &oilSimulation);

    engine.loadFromModule("OilSpillProject", "Main");

    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}