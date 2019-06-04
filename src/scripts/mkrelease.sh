#!/bin/bash
if [ -z $QT_STATIC ]; then 
    echo "QT_STATIC is not set. Please set it to the base directory of a statically compiled Qt"; 
    exit 1; 
fi

if [ -z $APP_VERSION ]; then echo "APP_VERSION is not set"; exit 1; fi
if [ -z $PREV_VERSION ]; then echo "PREV_VERSION is not set"; exit 1; fi

if [ -z $YCASH_DIR ]; then
    echo "YCASH_DIR is not set. Please set it to the base directory of a Ycash project with built Ycash binaries."
    exit 1;
fi

if [ ! -f $YCASH_DIR/artifacts/ycashd ]; then
    echo "Couldn't find ycashd in $YCASH_DIR/artifacts/. Please build ycashd."
    exit 1;
fi

if [ ! -f $YCASH_DIR/artifacts/ycash-cli ]; then
    echo "Couldn't find ycash-cli in $YCASH_DIR/artifacts/. Please build ycashd."
    exit 1;
fi

# Ensure that ycashd is the right build
echo -n "ycashd version........."
if grep -q "YcashCpp" $YCASH_DIR/artifacts/ycashd && ! readelf -s $YCASH_DIR/artifacts/ycashd | grep -q "GLIBC_2\.25"; then 
    echo "[OK]"
else
    echo "[ERROR]"
    echo "ycashd doesn't seem to be a YcashCpp build or ycashd is built with libc 2.25"
    exit 1
fi

echo -n "ycashd.exe version....."
if grep -q "YcashCpp" $YCASH_DIR/artifacts/ycashd.exe; then 
    echo "[OK]"
else
    echo "[ERROR]"
    echo "ycashd doesn't seem to be a YcashCpp build"
    exit 1
fi

echo -n "Version files.........."
# Replace the version number in the .pro file so it gets picked up everywhere
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" yecwallet.pro > /dev/null

# Also update it in the README.md
sed -i "s/${PREV_VERSION}/${APP_VERSION}/g" README.md > /dev/null
echo "[OK]"

echo -n "Cleaning..............."
rm -rf bin/*
rm -rf artifacts/*
make distclean >/dev/null 2>&1
echo "[OK]"

echo ""
echo "[Building on" `lsb_release -r`"]"

echo -n "Configuring............"
QT_STATIC=$QT_STATIC bash src/scripts/dotranslations.sh >/dev/null
$QT_STATIC/bin/qmake yecwallet.pro -spec linux-clang CONFIG+=release > /dev/null
echo "[OK]"


echo -n "Building..............."
rm -rf bin/yecwallet* > /dev/null
rm -rf bin/yecwallet* > /dev/null
make clean > /dev/null
make -j$(nproc) > /dev/null
echo "[OK]"


# Test for Qt
echo -n "Static link............"
if [[ $(ldd yecwallet | grep -i "Qt") ]]; then
    echo "FOUND QT; ABORT"; 
    exit 1
fi
echo "[OK]"


echo -n "Packaging.............."
mkdir bin/yecwallet-v$APP_VERSION > /dev/null
strip yecwallet

cp yecwallet                      bin/yecwallet-v$APP_VERSION > /dev/null
cp $YCASH_DIR/artifacts/ycashd    bin/yecwallet-v$APP_VERSION > /dev/null
cp $YCASH_DIR/artifacts/ycash-cli bin/yecwallet-v$APP_VERSION > /dev/null
#cp README.md                      bin/yecwallet-v$APP_VERSION > /dev/null
cp LICENSE                        bin/yecwallet-v$APP_VERSION > /dev/null

cd bin && tar czf linux-yecwallet-v$APP_VERSION.tar.gz yecwallet-v$APP_VERSION/ > /dev/null
cd .. 

mkdir artifacts >/dev/null 2>&1
cp bin/linux-yecwallet-v$APP_VERSION.tar.gz ./artifacts/linux-binaries-yecwallet-v$APP_VERSION.tar.gz
echo "[OK]"


if [ -f artifacts/linux-binaries-yecwallet-v$APP_VERSION.tar.gz ] ; then
    echo -n "Package contents......."
    # Test if the package is built OK
    if tar tf "artifacts/linux-binaries-yecwallet-v$APP_VERSION.tar.gz" | wc -l | grep -q "6"; then 
        echo "[OK]"
    else
        echo "[ERROR]"
        exit 1
    fi    
else
    echo "[ERROR]"
    exit 1
fi

# echo -n "Building deb..........."
# debdir=bin/deb/yecwallet-v$APP_VERSION
# mkdir -p $debdir > /dev/null
# mkdir    $debdir/DEBIAN
# mkdir -p $debdir/usr/local/bin

# cat src/scripts/control | sed "s/RELEASE_VERSION/$APP_VERSION/g" > $debdir/DEBIAN/control

# cp yecwallet                   $debdir/usr/local/bin/
# cp $YCASH_DIR/artifacts/ycashd $debdir/usr/local/bin/zqw-ycashd

# mkdir -p $debdir/usr/share/pixmaps/
# cp res/yecwallet.xpm           $debdir/usr/share/pixmaps/

# mkdir -p $debdir/usr/share/applications
# cp src/scripts/desktopentry    $debdir/usr/share/applications/yecwallet.desktop

# dpkg-deb --build $debdir >/dev/null
# cp $debdir.deb                 artifacts/linux-deb-yecwallet-v$APP_VERSION.deb
# echo "[OK]"



echo ""
echo "[Windows]"

if [ -z $MXE_PATH ]; then 
    echo "MXE_PATH is not set. Set it to ~/github/mxe/usr/bin if you want to build Windows"
    echo "Not building Windows"
    exit 0; 
fi

if [ ! -f $YCASH_DIR/artifacts/ycashd.exe ]; then
    echo "Couldn't find ycashd.exe in $YCASH_DIR/artifacts/. Please build ycashd.exe"
    exit 1;
fi


if [ ! -f $YCASH_DIR/artifacts/ycash-cli.exe ]; then
    echo "Couldn't find ycash-cli.exe in $YCASH_DIR/artifacts/. Please build ycashd.exe"
    exit 1;
fi

export PATH=$MXE_PATH:$PATH

echo -n "Configuring............"
make clean  > /dev/null
rm -f yecwallet-mingw.pro
rm -rf release/
#Mingw seems to have trouble with precompiled headers, so strip that option from the .pro file
cat yecwallet.pro | sed "s/precompile_header/release/g" | sed "s/PRECOMPILED_HEADER.*//g" > yecwallet-mingw.pro
echo "[OK]"


echo -n "Building..............."
x86_64-w64-mingw32.static-qmake-qt5 yecwallet-mingw.pro CONFIG+=release > /dev/null
make -j32 > /dev/null
echo "[OK]"


echo -n "Packaging.............."
mkdir release/yecwallet-v$APP_VERSION  
cp release/yecwallet.exe          release/yecwallet-v$APP_VERSION 
cp $YCASH_DIR/artifacts/ycashd.exe    release/yecwallet-v$APP_VERSION > /dev/null
cp $YCASH_DIR/artifacts/ycash-cli.exe release/yecwallet-v$APP_VERSION > /dev/null
#cp README.md                          release/yecwallet-v$APP_VERSION 
cp LICENSE                            release/yecwallet-v$APP_VERSION 
cd release && zip -r Windows-binaries-yecwallet-v$APP_VERSION.zip yecwallet-v$APP_VERSION/ > /dev/null
cd ..

mkdir artifacts >/dev/null 2>&1
cp release/Windows-binaries-yecwallet-v$APP_VERSION.zip ./artifacts/
echo "[OK]"

if [ -f artifacts/Windows-binaries-yecwallet-v$APP_VERSION.zip ] ; then
    echo -n "Package contents......."
    if unzip -l "artifacts/Windows-binaries-yecwallet-v$APP_VERSION.zip" | wc -l | grep -q "11"; then 
        echo "[OK]"
    else
        echo "[ERROR]"
        exit 1
    fi
else
    echo "[ERROR]"
    exit 1
fi
