#include "rescanprogress.h"

#include "precompiled.h"

RescanProgress::RescanProgress(MainWindow* _main) 
    : main(_main) {
    // Set up the progress dialog
    progress = new QProgressDialog(
                    QObject::tr("Your wallet is rescanning. This will take a long time. Please wait..."), 
                    QString(), 0, 100, main);
    progress->setWindowTitle(QObject::tr("Rescanning"));
    progress->setWindowModality(Qt::WindowModal);
}

RescanProgress::~RescanProgress() {
    progress->setValue(100);
    delete progress;
}

void RescanProgress::updateProgress(int tick) {
    if (tick >= 0 && tick < 100)
        progress->setValue(tick);
}