#!/usr/bin/env fish
# Post-dotfiles setup: services, firewall, and laptop hardware fixes.
# Run from a fresh shell after bootstrap.fish has restored the dotfiles.

# --- system + user services ---
echo "==> Enabling system services..."
for svc in NetworkManager bluetooth tlp ufw sshd
    sudo systemctl enable --now $svc
    echo "    $svc enabled"
end

echo "==> Enabling user services..."
for svc in pipewire pipewire-pulse wireplumber
    systemctl --user enable --now $svc
    echo "    $svc enabled"
end

echo "==> Enabling Hyprland monitor watcher..."
systemctl --user daemon-reload
systemctl --user enable hypr-monitor-watcher.service

# --- firewall ---
echo "==> Configuring UFW..."
sudo ufw default deny
sudo ufw allow from 192.168.0.0/24
sudo ufw limit ssh
sudo ufw --force enable
sudo ufw status verbose

# --- hardware: Apple Magic Keyboard A1843 (laptop 'aribook' only) ---
if test (cat /etc/hostname | string trim) = aribook
    echo "==> Applying Apple Magic Keyboard fixes (aribook)..."
    echo 'ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="05ac", ATTRS{idProduct}=="026c", TEST=="power/control", ATTR{power/control}="on"' \
        | sudo tee /etc/udev/rules.d/50-apple-keyboard-usb.rules > /dev/null
    sudo udevadm control --reload-rules
    sudo udevadm trigger
    echo 'options hid_apple fnmode=2' | sudo tee /etc/modprobe.d/hid_apple.conf > /dev/null
    echo 2 | sudo tee /sys/module/hid_apple/parameters/fnmode > /dev/null
    sudo mkinitcpio -P
    echo "    Unplug and replug the keyboard to apply the udev rule."
else
    echo "==> Not aribook — skipping Apple keyboard hardware fix."
end

echo "==> Post-install complete."
