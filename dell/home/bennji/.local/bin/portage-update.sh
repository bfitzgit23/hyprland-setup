#!/usr/bin/env bash
echo "=== Syncing Gentoo & Overlays ==="
sudo emaint sync -a
echo "=== Updating @world ==="
sudo emerge --ask --verbose --update --deep --newuse @world
echo "=== Cleaning Unused Dependencies ==="
sudo emerge --ask --depclean
echo "=== Done! Press Enter to close ==="
read -r
