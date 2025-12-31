#!/usr/bin/env bash
set -e

sudo raspi-config nonint do_i2c 0

cd $HOME
git clone https://github.com/SequentMicrosystems/16relind-rpi.git
cd $HOME/16relind-rpi
sudo make install

echo "Installation complete. Rebooting…"
sudo reboot