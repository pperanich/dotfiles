# MacBook Pro (T2) NixOS Installation Guide

This guide will help you install NixOS on your MacBook Pro with T2 security chip, keeping your existing macOS installation intact.

## Prerequisites

- Existing macOS installation (to create partitions and download firmware)
- USB drive (8GB+) for the NixOS installer
- Internet connection (preferably wired, as WiFi requires firmware installation)

## Step 1: Prepare Partitions in macOS

1. Boot into macOS
2. Open Disk Utility
3. Select the internal drive (likely named "Apple SSD...")
4. Click "Partition" (not "Volume")
5. Create a new partition for NixOS:
   - Give it a name like "NixOS"
   - Size: Allocate at least 50GB
   - Format: APFS (this will be reformatted later)
6. Apply changes
7. Before proceeding, run `diskutil list` to verify your partition layout:
   - Should see EFI partition (usually disk0s1)
   - macOS APFS container (usually disk0s2/disk2)
   - NixOS APFS container (usually disk0s3/disk1)
   - Note these device names for later use

## Step 2: Download WiFi/Bluetooth Firmware

The firmware needs to be extracted from macOS. In macOS, run:

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install required tools
brew install python3 git

# Clone the T2 Linux repo
git clone https://github.com/t2linux/wiki.git ~/t2linux-wiki

# Run the firmware extraction script
bash ~/t2linux-wiki/docs/tools/firmware.sh
```

This will create a `firmware.zip` file. Transfer this to a USB drive or cloud storage for later use.

## Step 3: Create NixOS Installation Media

On any computer with Nix installed:

```bash
# Build the ISO
nix build .#nixosConfigurations.macbook-pro-iso.config.system.build.isoImage

# The ISO will be in ./result/iso/
# Write it to a USB drive (replace sdX with your drive)
sudo dd if=./result/iso/nixos-macbook-pro-*.iso of=/dev/sdX bs=4M status=progress
```

## Step 4: Boot from the NixOS USB

1. Insert the USB drive
2. Restart your MacBook and hold the Option (⌥) key during boot
3. Select "EFI Boot" (the USB drive)
4. Select the NixOS installer from the boot menu

## Step 5: Install the WiFi/Bluetooth Firmware

Once the live environment is running:

1. Connect your firmware USB drive or download the firmware file
2. Install the firmware:

```bash
# Copy firmware.zip to /tmp
cp /path/to/firmware.zip /tmp/

# Extract and install the firmware
unzip /tmp/firmware.zip -d /tmp/firmware
mkdir -p /lib/firmware/brcm
cp /tmp/firmware/brcmfmac4364* /lib/firmware/brcm/
cp -r /tmp/firmware/BT* /lib/firmware/brcm/
```

3. Test WiFi and Bluetooth:

```bash
# For WiFi
nmcli device wifi rescan
nmcli device wifi list

# For Bluetooth
bluetoothctl
# Inside bluetoothctl:
power on
scan on
# You should see devices appear
```

## Step 6: Verify Disk Layout

Before proceeding with formatting, verify your disk layout:

```bash
# List all disks and partitions
lsblk
# or
fdisk -l
# or
parted -l
```

You should see:

- EFI partition (probably /dev/nvme0n1p1 or /dev/disk0s1)
- macOS partition (/dev/nvme0n1p2 or /dev/disk0s2)
- NixOS partition (/dev/nvme0n1p3 or /dev/disk0s3)

Make note of these device paths for the next step.

## Step 7: Format and Mount Partitions

Now we'll format the NixOS partition and mount everything:

```bash
# Format the NixOS APFS volume with ext4
# Replace /dev/disk1s1 with your actual NixOS volume
sudo mkfs.ext4 -F /dev/disk1s1

# Mount the root partition
sudo mount /dev/disk1s1 /mnt

# Create and mount the boot directory (EFI partition)
sudo mkdir -p /mnt/boot
sudo mount /dev/disk0s1 /mnt/boot
```

## Step 8: Generate a Hardware Configuration

```bash
# Generate hardware configuration for your specific hardware
sudo nixos-generate-config --root /mnt

# The generated configuration will be in /mnt/etc/nixos/
# You may want to review the hardware-configuration.nix file
sudo nano /mnt/etc/nixos/hardware-configuration.nix

# Copy the generated hardware-configuration.nix to your config repo if needed
cp /mnt/etc/nixos/hardware-configuration.nix /path/to/your/repo/hosts/macbook-pro/
```

## Step 9: Install NixOS

```bash
# Install NixOS with your configuration
sudo nixos-install --flake .#macbook-pro

# Set the root password when prompted
```

## Step 10: Reboot

```bash
# Reboot into your new NixOS installation
sudo reboot
```

## Post-Installation Steps

### Fixing Boot Issues

If you have issues with the boot loader:

1. Boot back into the live USB
2. Mount your installation:
   ```bash
   sudo mount /dev/disk1s1 /mnt
   sudo mount /dev/disk0s1 /mnt/boot
   ```
3. Chroot into your installation:
   ```bash
   sudo nixos-enter --root /mnt
   ```
4. Reinstall the bootloader:
   ```bash
   nixos-rebuild boot
   ```

### Device Path Issues

If device paths change between boots and your system doesn't boot properly:

1. Edit the filesystem entries in `/etc/nixos/hardware-configuration.nix`
2. Consider using persistent labels or UUIDs instead of device paths:
   ```nix
   fileSystems."/" = {
     device = "/dev/disk/by-label/nixos";  # Use labels instead of /dev/disk1s1
     fsType = "ext4";
   };
   ```
3. Rebuild your system configuration

### Apple T2 Specific Settings

Your NixOS configuration already includes optimizations for the T2 chip, but you might want to:

1. Adjust keyboard/trackpad settings
2. Fine-tune power management
3. Configure sound/microphone settings

### Dual Boot Considerations

- The macOS bootloader has priority
- To boot into NixOS, hold the Option (⌥) key during startup and select "EFI Boot"
- Consider installing rEFInd for a better dual-boot experience

## Troubleshooting

### WiFi/Bluetooth Issues

If WiFi or Bluetooth don't work after installation:

1. Verify the firmware files are present:

   ```bash
   ls -la /lib/firmware/brcm/brcmfmac4364*
   ls -la /lib/firmware/brcm/BT*
   ```

2. Reinstall the firmware and reboot

### Screen Brightness Control

If brightness control doesn't work:

1. Add the following to your configuration:
   ```nix
   boot.kernelParams = [ "acpi_osi=Darwin" ];
   ```

### Keyboard/Trackpad Issues

If keyboard or trackpad aren't working properly:

1. Check that the apple-t2 module is loaded
2. Verify the applespi module is loaded:
   ```bash
   lsmod | grep applespi
   ```

## Additional Resources

- [T2Linux Wiki](https://wiki.t2linux.org/)
- [NixOS MacBook Pro Guide](https://nixos.wiki/wiki/Apple_Macbook_Pro)
