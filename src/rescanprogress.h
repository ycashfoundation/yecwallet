#ifndef RESCANPROGRESS_H
#define RESCANPROGRESS_H

#include "mainwindow.h"
#include "precompiled.h"

class RescanProgress {
public:
    RescanProgress(MainWindow* _main);
    ~RescanProgress();

    void updateProgress(int value);
    void closeProgress();

private:
    MainWindow* main;
    QProgressDialog* progress;
};


#endif
