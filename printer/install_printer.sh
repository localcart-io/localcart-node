#!/bin/bash
# Automatisch installatie- en configuratiescript Brother QL

set -e  # stop bij fouten

# 1. Maak map eigenbodem aan
mkdir -p ~/eigenbodem

# 2. Installeer git
sudo apt update
sudo apt install git -y

# 3. Clone de brother_ql-inventree repo (als die nog niet bestaat)
cd ~/eigenbodem
if [ ! -d "brother_ql-inventree" ]; then
    git clone https://github.com/matmair/brother_ql-inventree.git
fi

# 4. Installeer python3-pip
sudo apt install python3-pip -y

# 5. Installeer Python dependencies
sudo pip3 install --ignore-installed --break-system-packages packbits
sudo pip3 install --break-system-packages --ignore-installed ~/eigenbodem/brother_ql-inventree

# 6. Installeer ImageMagick
sudo apt install imagemagick -y

# 7. Voeg PDF policy toe aan ImageMagick zonder iets te wissen
sudo bash -c 'echo "<policy domain=\"coder\" rights=\"read|write\" pattern=\"PDF\" />" >> /etc/ImageMagick-7/policy.xml'

# 8. Maak helper script voor brother_ql aan
sudo tee /usr/local/bin/brother_ql > /dev/null << 'EOF'
#!/bin/bash
python3 -m brother_ql.cli "$@"
EOF

sudo chmod +x /usr/local/bin/brother_ql

# 9. Voeg udev rules toe voor Brother printers
sudo tee /etc/udev/rules.d/99-brother-printer.rules > /dev/null << 'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="04f9", ATTR{idProduct}=="20a7", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="04f9", ATTR{idProduct}=="20a8", MODE="0666"
SUBSYSTEM=="usb", ATTR{idVendor}=="04f9", ATTR{idProduct}=="209b", MODE="0666"
EOF

# 10. Herlaad udev rules
sudo udevadm control --reload-rules

# 11. Voeg huidige gebruiker toe aan plugdev en lp groepen
sudo usermod -aG plugdev $USER
sudo usermod -aG lp $USER

echo "Installation complete. Rebooting…"
sudo reboot