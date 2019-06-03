#!/bin/bash

# Accept the variables as command line arguments as well
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -q|--qt_path)
    QT_PATH="$2"
    shift # past argument
    shift # past value
    ;;
    -z|--zcash_path)
    YCASH_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    -v|--version)
    APP_VERSION="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [ -z $QT_PATH ]; then 
    echo "QT_PATH is not set. Please set it to the base directory of Qt"; 
    exit 1; 
fi

if [ -z $YCASH_DIR ]; then
    echo "YCASH_DIR is not set. Please set it to the base directory of a compiled ycashd";
    exit 1;
fi

if [ -z $APP_VERSION ]; then
    echo "APP_VERSION is not set. Please set it to the current release version of the app";
    exit 1;
fi

if [ ! -f $YCASH_DIR/src/ycashd ]; then
    echo "Could not find compiled ycashd in $YCASH_DIR/src/.";
    exit 1;
fi

if ! cat src/version.h | grep -q "$APP_VERSION"; then
    echo "Version mismatch in src/version.h"
    exit 1
fi

export PATH=$PATH:/usr/local/bin

#Clean
echo -n "Cleaning..............."
make distclean >/dev/null 2>&1
rm -f artifacts/macOS-yecwallet-v$APP_VERSION.dmg
echo "[OK]"


echo -n "Configuring............"
# Build
QT_STATIC=$QT_PATH src/scripts/dotranslations.sh >/dev/null
$QT_PATH/bin/qmake yecwallet.pro CONFIG+=release >/dev/null
echo "[OK]"


echo -n "Building..............."
make -j4 >/dev/null
echo "[OK]"

#Qt deploy
echo -n "Deploying.............."
mkdir artifacts >/dev/null 2>&1
rm -f artifcats/yecwallet.dmg >/dev/null 2>&1
rm -f artifacts/rw* >/dev/null 2>&1
cp $YCASH_DIR/src/ycashd yecwallet.app/Contents/MacOS/
cp $YCASH_DIR/src/ycash-cli yecwallet.app/Contents/MacOS/
$QT_PATH/bin/macdeployqt yecwallet.app 
echo "[OK]"


echo -n "Building dmg..........."
create-dmg --volname "yecwallet-v$APP_VERSION" --volicon "res/logo.icns" --window-pos 200 120 --icon "yecwallet.app" 200 190  --app-drop-link 600 185 --hide-extension "yecwallet.app"  --window-size 800 400 --hdiutil-quiet --background res/dmgbg.png  artifacts/macOS-yecwallet-v$APP_VERSION.dmg yecwallet.app >/dev/null 2>&1

#mkdir bin/dmgbuild >/dev/null 2>&1
#sed "s/RELEASE_VERSION/${APP_VERSION}/g" res/appdmg.json > bin/dmgbuild/appdmg.json
#cp res/logo.icns bin/dmgbuild/
#cp res/dmgbg.png bin/dmgbuild/

#cp -r yecwallet.app bin/dmgbuild/

#appdmg --quiet bin/dmgbuild/appdmg.json artifacts/macOS-yecwallet-v$APP_VERSION.dmg >/dev/null
if [ ! -f artifacts/macOS-yecwallet-v$APP_VERSION.dmg ]; then
    echo "[ERROR]"
    exit 1
fi
echo  "[OK]"
