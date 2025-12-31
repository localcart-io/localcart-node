#!/usr/bin/env bash
set -e

cd $HOME/localcart-node
git fetch origin
git reset --hard origin/main
git clean -fd -e device-id.txt -e run.log

echo "Code pull complete. Rebooting…"
sudo reboot