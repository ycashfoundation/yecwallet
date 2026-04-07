#include "logger.h"

Logger::Logger(QObject *parent, QString fileName) : QObject(parent) {
    m_showDate = true;

    if (!fileName.isEmpty()) {
        file = new QFile;
        file->setFileName(fileName);
        file->open(QIODevice::Append | QIODevice::Text);
    }

    write("=========Startup==========");
}

void Logger::write(const QString &value) {
    if (!file)
        return;

    QString text = value;
    text = QDateTime::currentDateTime().toString("dd.MM.yyyy hh:mm:ss ") + text;
    QTextStream out(file);
    out.setEncoding(QStringConverter::Utf8);
    if (file != nullptr) {
        out << text << Qt::endl;
    }
}

Logger::~Logger() {
    if (file != nullptr)
        file->close();
}
