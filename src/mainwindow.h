#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include "precompiled.h"

#include "logger.h"

// Forward declare to break circular dependency.
class Controller;
class Settings;

using json = nlohmann::json;

// Struct used to hold destination info when sending a Tx. 
struct ToFields {
    QString addr;
    double  amount;
    QString txtMemo;
    QString encodedMemo;
};

// Struct used to represent a Transaction. 
struct Tx {
    QString         fromAddr;
    QList<ToFields> toAddrs;
    double          fee;
};

namespace Ui {
    class MainWindow;
}

class MainWindow : public QMainWindow
{
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

    void updateLabelsAutoComplete();
    Controller* getRPC() { return rpc; }

    QCompleter*         getLabelCompleter() { return labelCompleter; }
    QRegExpValidator*   getAmountValidator() { return amtValidator; }

    QString doSendTxValidations(Tx tx);
    void setDefaultPayFrom();

    void balancesReady();
    void payZcashURI(QString uri = "", QString myAddr = "");

    void validateAddress();
    void nullifierMigration();
    void rescanBlockchain();

    void updateLabels();
    void updateTAddrCombo(bool checked);
    void updateFromCombo();

    // Check whether the RPC is returned and payments are ready to be made
    bool isPaymentsReady() { return uiPaymentsReady; }

    Ui::MainWindow*     ui;

    QLabel*             statusLabel;
    QLabel*             statusIcon;
    QLabel*             loadingLabel;
    QWidget*            zcashdtab;

    Logger*      logger;

    void doClose();

public slots:
    void slot_change_theme(const QString& themeName);

private:    
    void closeEvent(QCloseEvent* event);

    void setupSendTab();
    void setupTransactionsTab();
    void setupReceiveTab();
    void setupBalancesTab();
    void setupZcashdTab();

    void setupTurnstileDialog();
    void setupSettingsModal();
    void setupStatusBar();
    
    void clearSendForm();

    Tx   createTxFromSendPage();
    bool confirmTx(Tx tx);

    void cancelButton();
    void sendButton();
    void inputComboTextChanged(int index);
    void addAddressSection();
    void maxAmountChecked(int checked);

    void editSchedule();

    void addressChanged(int number, const QString& text);
    void amountChanged (int number, const QString& text);

    void addNewZaddr(bool sapling);
    std::function<void(bool)> addZAddrsToComboList(bool sapling);

    void memoButtonClicked(int number, bool includeReplyTo = false);
    void setMemoEnabled(int number, bool enabled);
    void recalcFee();
    
    void donate();
    void addressBook();
    void importPrivKey(bool viewKey = false);
    void importFVK();
    void exportAllKeys();
    void exportAllViewKeys();
    void exportAllIVK();
    void exportKeys(QString addr = "", bool viewkey = false);
    void exportIVK(QString addr = "");
    void backupWalletDat();
    void exportTransactions();

    void doImport(QList<QString>* keys, int rescanHeight);
    void doImportFVK(QList<QString>* keys, int rescanHeight);

    void restoreSavedStates();
    bool eventFilter(QObject *object, QEvent *event);

    bool            uiPaymentsReady    = false;
    QString         pendingURIPayment;

    Controller*         rpc             = nullptr;
    QCompleter*         labelCompleter  = nullptr;
    QRegExpValidator*   amtValidator    = nullptr;
    QRegExpValidator*   feesValidator   = nullptr;

    QMovie*      loadingMovie;
};

#endif // MAINWINDOW_H
