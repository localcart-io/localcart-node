#!/bin/bash

# Detecteer Brother-printer via lsusb
PRINTER_INFO=$(lsusb | grep -i "Brother")

if [ -z "$PRINTER_INFO" ]; then
    echo "No printers found"
    exit 1
fi

# Vendor en Product ID ophalen
VENDOR_ID=$(echo "$PRINTER_INFO" | awk '{print $6}' | cut -d':' -f1)
PRODUCT_ID=$(echo "$PRINTER_INFO" | awk '{print $6}' | cut -d':' -f2)

# Exact model extraheren zoals QL-1100 of QL-1110NWB
MODEL=$(echo "$PRINTER_INFO" | grep -o -E 'QL-[0-9]+[A-Z]*' | head -1)

# Printer URI automatisch genereren
PRINTER_URI="usb://$VENDOR_ID:$PRODUCT_ID"

TMP_DIR=$(mktemp -d /tmp/myapp.XXXXXX)
URL="$1"
PDF="labels.pdf"

mkdir -p "$TMP_DIR"
cd "$TMP_DIR" || exit 1

echo "Fetching labels from $URL"

# PDF downloaden
wget -O labels.pdf "$URL"

# PDF naar PNG
convert -density 300 "$PDF" labels.png

# Print alle pagina's met gedetecteerde printer
for f in labels-*.png; do
    /usr/local/bin/brother_ql -b pyusb -m "$MODEL" -p "$PRINTER_URI" print -l 62 "$f"
    sleep 2
done

# Opruimen
rm -rf "$TMP_DIR"

echo "Printjob done"