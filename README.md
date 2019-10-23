YecWallet is the official wallet for [Ycash](https://www.ycash.xyz) that runs on Linux, Windows and macOS.

# Installation

Head over to the releases page and grab the latest installers or binary. https://github.com/ycashfoundation/yecwallet/releases

### Linux

If you are on Debian/Ubuntu, please download the binaries
```
sudo dpkg -i linux-deb-yecwallet-v0.7.9.deb
sudo apt install -f
```

Or you can download and run the binaries directly.
```
tar -xvf yecwallet-v0.7.9.tar.gz
./yecwallet-v0.7.9/yecwallet
```

### Windows
Download the release binary, unzip it and double click on `yecwallet.exe` to start.

### macOS
Double-click on the `.dmg` file to open it, and drag `yecwallet` on to the Applications link to install.

## ycashd
YecWallet needs a Ycash node running ycashd. If you already have a ycashd node running, YecWallet will connect to it. 

If you don't have one, YecWallet will start its embedded ycashd node. 
