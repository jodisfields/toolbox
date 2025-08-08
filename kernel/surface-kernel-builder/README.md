# Surface Laptop Studio 1 - CachyOS Optimized Kernel for Fedora 42

**Complete kernel build solution with maximum performance and full hardware support**

Custom Fedora 42 kernel specifically optimized for the Surface Laptop Studio 1, combining:
- **CachyOS performance patches** for maximum system responsiveness
- **Complete Surface hardware support** for all device features  
- **Advanced optimizations** for desktop, gaming, and professional workloads

## Features

### Performance Enhancements (CachyOS)
- **BORE Scheduler**: Burst-Oriented Response Enhancer for better desktop responsiveness
- **BBR3 TCP**: Advanced congestion control for improved network performance
- **Memory Optimizations**: Multi-Gen LRU, optimized compaction, transparent hugepages
- **I/O Improvements**: BFQ scheduler, enhanced block layer, io_uring optimizations
- **Architecture Tuning**: x86-64-v3/v4 optimizations, LTO, PGO support
- **Crypto Acceleration**: ZSTD, LZ4, modern cipher optimizations
- **Async Shutdown**: Faster boot and shutdown times

### Surface Laptop Studio 1 Hardware Support
- **Multi-touch Display**: 10-point touch with proper gesture support
- **Surface Pen**: Full pressure sensitivity and palm rejection
- **Cameras**: Both front and rear cameras working
- **WiFi**: Enhanced mwifiex driver with stability improvements
- **Audio**: Proper sound with all speakers and microphone
- **Power Management**: Optimized battery life and thermal control
- **GPU Switching**: Intel integrated + NVIDIA discrete graphics
- **Keyboard/Trackpad**: All keys, trackpad, and haptic feedback
- **Bluetooth**: Stable connection with peripherals
- **USB-C/Thunderbolt**: Full port functionality
- **Surface Dock**: Complete compatibility

### Advanced System Features
- **Container Support**: Docker, Podman, LXC ready
- **Virtualization**: KVM, VFIO for GPU passthrough
- **Security**: Kernel hardening, KASLR, Spectre/Meltdown mitigations
- **Filesystems**: ZFS, Btrfs, F2FS support
- **Debugging**: Comprehensive debugging support for development

## What's Included

| File | Description |
|------|-------------|
| `build-surface-kernel.sh` | **Main launcher script** - Interactive build process |
| `build-complete-fedora42-surface-cachy-kernel.sh` | **Comprehensive build engine** - Does all the heavy lifting |
| `kernel-build-config.conf` | **Configuration file** - Customize all build options |
| `README.md` | **This documentation** - Complete usage guide |

## Quick Start

### Option 1: Recommended Settings (Fastest)
```bash
# Make scripts executable
chmod +x build-surface-kernel.sh
./build-surface-kernel.sh --recommended
```

### Option 2: Interactive Setup
```bash
chmod +x build-surface-kernel.sh
./build-surface-kernel.sh
```

### Option 3: High Performance Build
```bash
./build-surface-kernel.sh --performance
```

## Configuration Options

### Performance Presets

| Setting | Recommended | High Performance | Description |
|---------|-------------|------------------|-------------|
| CPU Architecture | x86-64-v3 | native | CPU optimization level |
| LTO | thin | full | Link Time Optimization |
| Timer Frequency | 1000Hz | 1000Hz | System responsiveness |
| Scheduler | BORE | BORE | CPU scheduler |
| Build Time | 2-3 hours | 4-6 hours | Typical build duration |

### Hardware Features (All Enabled)

| Feature | Status | Description |
|---------|--------|-------------|
| Surface SAM | Required | Surface Aggregator Module |
| Touch/Pen | Enabled | Multi-touch and pen input |
| Cameras | Enabled | IPU3 camera support |
| WiFi | Enhanced | mwifiex improvements |
| Audio | Optimized | SOF audio drivers |
| Power | Advanced | Intel P-State + Surface PM |
| Thermal | Smart | Intelligent thermal management |
| NVIDIA | Supported | Discrete GPU compatibility |

## System Requirements

### Minimum Requirements
- **OS**: Fedora 40+ (Fedora 42 recommended)
- **CPU**: 4+ cores
- **RAM**: 8GB
- **Storage**: 30GB free space
- **Internet**: Stable connection for patches

### Recommended Specifications
- **CPU**: 8+ cores (Intel/AMD)
- **RAM**: 16GB+
- **Storage**: SSD with 50GB+ free space
- **Internet**: High-speed connection

### Build Time Estimates
- **Fast system** (8+ cores, 16GB+ RAM): 2-3 hours
- **Moderate system** (4-8 cores, 8-16GB RAM): 3-4 hours  
- **Slower system** (<4 cores, <8GB RAM): 4-6 hours

## Installation

After successful build:

```bash
# Install all packages
sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel-surface-cachy-*.rpm

# Install Surface tools
sudo dnf copr enable linux-surface/linux-surface
sudo dnf install surface-firmware iptsd libwacom-surface

# Enable touchscreen daemon
sudo systemctl enable --now iptsd

# Configure GRUB for Surface
sudo nano /etc/default/grub
# Add: i915.enable_psr=0 mem_sleep_default=deep

# Update GRUB and reboot
sudo grub2-mkconfig -o /boot/grub2/grub.cfg
sudo reboot
```

## Testing Your New Kernel

After installation and reboot:

### Verify Kernel Version
```bash
uname -r
# Should show: [version]-surface-cachy
```

### Test Surface Hardware
```bash
evtest  # Select touchscreen device

# Cameras
lsusb | grep -i camera
v4l2-ctl --list-devices

# Surface modules
lsmod | grep surface

# WiFi performance
speedtest-cli
```

## Troubleshooting

### Common Issues

#### Build Fails
```bash
# Check logs in the build directory
less ~/surface-cachy-kernel-build/logs/build.log

# Check disk space
df -h

# Verify dependencies
sudo dnf grouplist installed | grep "Development Tools"
```

#### Touchscreen Not Working
```bash
# Restart IPTSD
sudo systemctl restart iptsd

# Check IPTSD status  
sudo systemctl status iptsd

# Verify device detection
ls /dev/input/by-path/*touch*
```

#### Boot Issues
- Select previous kernel from GRUB menu
- Remove problematic kernel: `sudo dnf remove kernel-surface-cachy-[version]`
- Always keep a working kernel as backup
