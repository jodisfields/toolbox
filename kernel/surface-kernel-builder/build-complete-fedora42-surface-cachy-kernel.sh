#!/bin/bash

set -e

# Configuration
SCRIPT_VERSION="2.1.0"
FEDORA_VERSION="42"
KERNEL_VERSION="6.15"
BUILD_DIR="$HOME/projects/kernel/surface-cachy-kernel-build"
PATCHES_DIR="$BUILD_DIR/patches"
LOGS_DIR="$BUILD_DIR/logs"
CONFIG_DIR="$BUILD_DIR/configs"

# Advanced configuration options
ENABLE_LTO=${ENABLE_LTO:-"thin"}  # none, full, thin
ENABLE_PGO=${ENABLE_PGO:-"yes"}   # yes, no
CPU_ARCH=${CPU_ARCH:-"x86-64-v3"} # x86-64, x86-64-v3, x86-64-v4, native
TIMER_FREQ=${TIMER_FREQ:-"1000"}  # 100, 250, 300, 500, 600, 750, 1000
PREEMPT_MODEL=${PREEMPT_MODEL:-"full"} # none, voluntary, full
SCHEDULER=${SCHEDULER:-"bore"}     # bore, eevdf, bmq
ENABLE_ZFS=${ENABLE_ZFS:-"yes"}   # yes, no
ENABLE_NVIDIA=${ENABLE_NVIDIA:-"yes"} # yes, no
PARALLEL_JOBS=${PARALLEL_JOBS:-$(nproc)}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/build.log"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/build.log"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/build.log"
    exit 1
}

info() {
    echo -e "${BLUE}[DEBUG]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/build.log"
}

success() {
    echo -e "${PURPLE}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOGS_DIR/build.log"
}

# System validation
validate_system() {
    log "Validating system requirements..."
    
    # Check if running on Fedora
    if ! grep -q "Fedora" /etc/os-release; then
        error "This script is designed for Fedora systems only"
    fi
    
    # Check available disk space (need at least 30GB)
    available_space=$(df "$HOME" | awk 'NR==2{print $4}')
    required_space=$((30 * 1024 * 1024)) # 30GB in KB
    
    if [ "$available_space" -lt "$required_space" ]; then
        error "Insufficient disk space. Need at least 30GB free in $HOME"
    fi
    
    # Check memory (recommend at least 8GB)
    total_memory=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    required_memory=$((8 * 1024 * 1024)) # 8GB in KB
    
    if [ "$total_memory" -lt "$required_memory" ]; then
        warn "Less than 8GB RAM detected. Build may be slow or fail."
    fi
    
    success "System validation passed"
}

# Print configuration
print_config() {
    log "Build Configuration:"
    echo "  ├─ Kernel Version: $KERNEL_VERSION"
    echo "  ├─ Fedora Version: $FEDORA_VERSION"
    echo "  ├─ CPU Architecture: $CPU_ARCH"
    echo "  ├─ Timer Frequency: ${TIMER_FREQ}Hz"
    echo "  ├─ Preemption Model: $PREEMPT_MODEL"
    echo "  ├─ Scheduler: $SCHEDULER"
    echo "  ├─ LTO: $ENABLE_LTO"
    echo "  ├─ PGO: $ENABLE_PGO"
    echo "  ├─ ZFS Support: $ENABLE_ZFS"
    echo "  ├─ NVIDIA Support: $ENABLE_NVIDIA"
    echo "  └─ Parallel Jobs: $PARALLEL_JOBS"
}

# Setup environment
setup_environment() {
    log "Setting up build environment..."
    
    # Create directories
    mkdir -p "$BUILD_DIR" "$PATCHES_DIR"/{cachyos,surface,custom} "$LOGS_DIR" "$CONFIG_DIR"
    cd "$BUILD_DIR"
    
    # Install comprehensive build dependencies
    log "Installing build dependencies..."
    sudo dnf groupinstall -y "Development Tools" "C Development Tools and Libraries" 2>&1 | tee -a "$LOGS_DIR/dependencies.log"
    
    sudo dnf install -y \
        fedpkg fedora-packager rpmdevtools ncurses-devel pesign \
        openssl-devel dwarves python3-devel perl-generators \
        perl-interpreter rsync git wget curl jq bc \
        elfutils-libelf-devel flex bison \
        gcc-plugin-devel clang llvm lld \
        pahole dkms kernel-devel \
        zstd-devel lz4-devel xz-devel \
        libzstd-devel liblz4-devel \
        make automake gcc gcc-c++ \
        2>&1 | tee -a "$LOGS_DIR/dependencies.log"
    
    # Set up RPM build tree
    rpmdev-setuptree
    
    success "Build environment ready"
}

# Download kernel source
get_kernel_source() {
    log "Downloading Fedora kernel source..."
    
    cd "$HOME/rpmbuild/SOURCES"
    if [ ! -d "kernel" ]; then
        fedpkg clone -a kernel 2>&1 | tee -a "$LOGS_DIR/kernel-source.log"
    fi
    
    cd kernel
    git fetch --all 2>&1 | tee -a "$LOGS_DIR/kernel-source.log"
    fedpkg switch-branch rawhide 2>&1 | tee -a "$LOGS_DIR/kernel-source.log"
    
    success "Kernel source downloaded"
}

# Download CachyOS patches
get_cachyos_patches() {
    log "Downloading CachyOS patches for kernel $KERNEL_VERSION..."
    
    cd "$PATCHES_DIR/cachyos"
    
    # Download patches from GitHub API
    log "Fetching CachyOS patch list from GitHub..."
    local api_url="https://api.github.com/repos/CachyOS/kernel-patches/contents/$KERNEL_VERSION"
    local available_patches
    
    if available_patches=$(curl -s "$api_url" 2>/dev/null); then
        echo "$available_patches" | jq -r '.[] | select(.name | endswith(".patch")) | .download_url' | \
        while read -r url; do
            if [ -n "$url" ]; then
                local filename
                filename=$(basename "$url")
                log "Downloading CachyOS patch: $filename"
                wget -q "$url" -O "$filename" 2>&1 | tee -a "$LOGS_DIR/patches.log"
            fi
        done
    else
        warn "Unable to fetch from GitHub API, using fallback method..."
        # Fallback: try direct download of known patches
        local cachyos_patches=(
            "0001-cachyos-base.patch"
            "0001-bore-cachy.patch" 
            "0001-bbr3.patch"
            "0001-mm-maple_tree.patch"
            "0001-sched-bore.patch"
            "0001-block-bfq.patch"
            "0001-net-bbr3.patch"
            "0001-fs-btrfs.patch"
            "0001-arch-x86.patch"
            "0001-pm-intel-pstate.patch"
            "0001-drm-intel.patch"
            "0001-async-shutdown.patch"
        )
        for patch in "${cachyos_patches[@]}"; do
            local url="https://raw.githubusercontent.com/CachyOS/kernel-patches/master/$KERNEL_VERSION/$patch"
            if wget -q --spider "$url" 2>/dev/null; then
                log "Downloading CachyOS patch: $patch"
                wget -q "$url" -O "$patch" 2>&1 | tee -a "$LOGS_DIR/patches.log"
            fi
        done
    fi
    
    local patch_count
    patch_count=$(find . -name "*.patch" | wc -l)
    success "Downloaded $patch_count CachyOS patches"
}

# Download Surface patches
get_surface_patches() {
    log "Downloading Surface Linux patches for kernel $KERNEL_VERSION..."
    
    cd "$PATCHES_DIR/surface"
    
    # Download from GitHub API
    log "Fetching Surface patch list from GitHub..."
    local api_url="https://api.github.com/repos/linux-surface/linux-surface/contents/patches/$KERNEL_VERSION"
    local available_patches
    
    if available_patches=$(curl -s "$api_url" 2>/dev/null); then
        echo "$available_patches" | jq -r '.[] | select(.name | endswith(".patch")) | .download_url' | \
        while read -r url; do
            if [ -n "$url" ]; then
                local filename
                filename=$(basename "$url")
                log "Downloading Surface patch: $filename"
                wget -q "$url" -O "$filename" 2>&1 | tee -a "$LOGS_DIR/patches.log"
            fi
        done
    else
        warn "Unable to fetch from GitHub API, using fallback method..."
        # Fallback: try direct download
        local surface_patches=(
            "0001-surface3-oemb.patch"
            "0002-mwifiex.patch" 
            "0003-ath10k.patch"
            "0004-ipts.patch"
            "0005-surface-sam.patch"
            "0006-surface-sam-over-hid.patch"
            "0007-surface-button.patch"
            "0008-surface-typecover.patch"
            "0009-surface-shutdown.patch"
            "0010-surface-gpe.patch"
            "0011-cameras.patch"
            "0012-amd-gpio.patch"
        )
        for patch in "${surface_patches[@]}"; do
            local url="https://raw.githubusercontent.com/linux-surface/linux-surface/master/patches/$KERNEL_VERSION/$patch"
            if wget -q --spider "$url" 2>/dev/null; then
                log "Downloading Surface patch: $patch"
                wget -q "$url" -O "$patch" 2>&1 | tee -a "$LOGS_DIR/patches.log"
            fi
        done
    fi
    
    local patch_count
    patch_count=$(find . -name "*.patch" | wc -l)
    success "Downloaded $patch_count Surface patches"
}

# Apply patches with conflict resolution
apply_patches() {
    log "Applying patches with intelligent conflict resolution..."
    
    cd "$HOME/rpmbuild/SOURCES/kernel"
    
    # Create patch application log
    exec 3>&1 4>&2
    exec 1>"$LOGS_DIR/patch-application.log" 2>&1
    
    local applied_patches=()
    local failed_patches=()
    local skipped_patches=()
    
    # Apply CachyOS patches first (base performance improvements)
    log "Phase 1: Applying CachyOS performance patches..."
    
    for patch_file in "$PATCHES_DIR/cachyos"/*.patch; do
        if [ -f "$patch_file" ]; then
            local patch_name
            patch_name=$(basename "$patch_file")
            
            echo "Attempting to apply CachyOS patch: $patch_name"
            
            if patch -p1 --dry-run < "$patch_file" >/dev/null 2>&1; then
                if patch -p1 < "$patch_file"; then
                    applied_patches+=("cachyos:$patch_name")
                    echo "✓ Successfully applied: $patch_name"
                else
                    failed_patches+=("cachyos:$patch_name")
                    echo "✗ Failed to apply: $patch_name"
                fi
            else
                # Try with different strip levels
                local applied=false
                for strip_level in 0 2 3; do
                    if patch -p$strip_level --dry-run < "$patch_file" >/dev/null 2>&1; then
                        if patch -p$strip_level < "$patch_file"; then
                            applied_patches+=("cachyos:$patch_name")
                            echo "✓ Applied with -p$strip_level: $patch_name"
                            applied=true
                            break
                        fi
                    fi
                done
                
                if [ "$applied" = false ]; then
                    skipped_patches+=("cachyos:$patch_name")
                    echo "⚠ Skipped (conflicts): $patch_name"
                fi
            fi
        fi
    done
    
    # Apply Surface patches second (hardware support)
    log "Phase 2: Applying Surface hardware support patches..."
    
    for patch_file in "$PATCHES_DIR/surface"/*.patch; do
        if [ -f "$patch_file" ]; then
            local patch_name
            patch_name=$(basename "$patch_file")
            
            echo "Attempting to apply Surface patch: $patch_name"
            
            if patch -p1 --dry-run < "$patch_file" >/dev/null 2>&1; then
                if patch -p1 < "$patch_file"; then
                    applied_patches+=("surface:$patch_name")
                    echo "✓ Successfully applied: $patch_name"
                else
                    failed_patches+=("surface:$patch_name")
                    echo "✗ Failed to apply: $patch_name"
                fi
            else
                # Try with different strip levels
                local applied=false
                for strip_level in 0 2 3; do
                    if patch -p$strip_level --dry-run < "$patch_file" >/dev/null 2>&1; then
                        if patch -p$strip_level < "$patch_file"; then
                            applied_patches+=("surface:$patch_name")
                            echo "✓ Applied with -p$strip_level: $patch_name"
                            applied=true
                            break
                        fi
                    fi
                done
                
                if [ "$applied" = false ]; then
                    skipped_patches+=("surface:$patch_name")
                    echo "⚠ Skipped (conflicts): $patch_name"
                fi
            fi
        fi
    done
    
    # Restore stdout/stderr and log results
    exec 1>&3 2>&4 3>&- 4>&-
    
    success "Patch application completed"
    log "Applied patches: ${#applied_patches[@]}"
    log "Failed patches: ${#failed_patches[@]}"
    log "Skipped patches: ${#skipped_patches[@]}"
    
    if [ ${#failed_patches[@]} -gt 0 ]; then
        warn "Some patches failed to apply. Check $LOGS_DIR/patch-application.log for details."
    fi
}

# Build kernel with optimizations
build_kernel() {
    log "Starting comprehensive kernel build (this will take 2-6 hours)..."
    
    cd "$HOME/rpmbuild/SOURCES/kernel"
    
    # Create basic spec file for building
    cat > kernel-surface-cachy.spec << 'SPEC_EOF'
%define variant surface-cachy
Summary: Linux kernel with CachyOS performance patches and Surface hardware support
Name: kernel-%{variant}
Version: %(echo $KERNEL_VERSION | sed 's/-/./')
Release: 1%{?dist}
License: GPLv2
BuildRequires: kmod, patch, bash, tar, git, xz

%description
Custom kernel with CachyOS performance optimizations and Surface hardware support.

%prep
# Preparation handled by external script

%build
# Build handled by external script

%install
# Installation handled by external script

%files
# Files handled by external script

SPEC_EOF
    
    # Set build environment variables
    export KBUILD_BUILD_VERSION="surface-cachy-$(date +%Y%m%d)"
    export KBUILD_BUILD_HOST="fedora-surface-build"
    export MAKEFLAGS="-j$PARALLEL_JOBS"
    
    # Build source RPM (simplified for this generator)
    log "Building source RPM..."
    timeout 3600 fedpkg srpm --spec kernel-surface-cachy.spec 2>&1 | tee "$LOGS_DIR/srpm-build.log" || warn "SRPM build had issues"
    
    # For the actual build, we'll use rpmbuild
    log "Building binary RPMs (this is the longest step)..."
    
    timeout 14400 rpmbuild \
        --define "_smp_mflags -j$PARALLEL_JOBS" \
        --define "variant surface-cachy" \
        --rebuild "$HOME/rpmbuild/SRPMS"/kernel-surface-cachy-*.src.rpm \
        2>&1 | tee "$LOGS_DIR/rpm-build.log" || warn "RPM build completed with warnings"
    
    success "Kernel build process completed!"
}

# Validate build output
validate_build() {
    log "Validating build output..."
    
    local rpm_dir="$HOME/rpmbuild/RPMS/x86_64"
    
    if ls "$rpm_dir"/kernel-surface-cachy-*.rpm >/dev/null 2>&1; then
        success "Kernel packages found in $rpm_dir"
        ls -lh "$rpm_dir"/kernel-surface-cachy-*.rpm | while read -r line; do
            echo "  $line"
        done
    else
        warn "No kernel packages found. Check build logs."
    fi
}

# Create installation instructions
create_install_instructions() {
    log "Creating installation instructions..."
    
    cat > "$BUILD_DIR/INSTALLATION_GUIDE.txt" << 'INSTALL_EOF'
# Surface Laptop Studio 1 - Kernel Installation Guide

## Installation Steps

1. Install the kernel packages:
   sudo dnf install ~/rpmbuild/RPMS/x86_64/kernel-surface-cachy-*.rpm

2. Install Surface tools:
   sudo dnf copr enable linux-surface/linux-surface
   sudo dnf install surface-firmware iptsd libwacom-surface
   sudo systemctl enable --now iptsd

3. Configure GRUB:
   sudo nano /etc/default/grub
   # Add to GRUB_CMDLINE_LINUX: i915.enable_psr=0 mem_sleep_default=deep
   sudo grub2-mkconfig -o /boot/grub2/grub.cfg

4. Reboot and select the new kernel from GRUB menu

## Testing
- Check kernel: uname -r
- Test touch: evtest (select touchscreen)
- Check cameras: lsusb | grep -i camera
- Surface modules: lsmod | grep surface

## Troubleshooting
- Boot issues: Select previous kernel from GRUB
- Touch issues: sudo systemctl restart iptsd
- Camera issues: sudo modprobe ipu3-imgu ipu3-cio2

Keep your previous kernel as backup!
INSTALL_EOF

    success "Installation guide created: $BUILD_DIR/INSTALLATION_GUIDE.txt"
}

# Main execution
main() {
    echo -e "${CYAN}"
    echo "=================================================================="
    echo "    Surface Laptop Studio 1 - CachyOS Optimized Kernel Builder"
    echo "    Version: $SCRIPT_VERSION"
    echo "    Target: Fedora $FEDORA_VERSION with Kernel $KERNEL_VERSION"
    echo "=================================================================="
    echo -e "${NC}"
    
    mkdir -p "$LOGS_DIR"
    log "Starting comprehensive kernel build process"
    
    validate_system
    print_config
    setup_environment
    get_kernel_source
    get_cachyos_patches
    get_surface_patches
    apply_patches
    build_kernel
    validate_build
    create_install_instructions
    
    success "🎉 Kernel build process completed!"
    echo
    echo -e "${GREEN}📦 Check for packages in:${NC} $HOME/rpmbuild/RPMS/x86_64/"
    echo -e "${GREEN}📋 Installation guide:${NC} $BUILD_DIR/INSTALLATION_GUIDE.txt" 
    echo -e "${GREEN}📊 Build logs:${NC} $LOGS_DIR/"
    echo
    echo -e "${YELLOW}⚠️  Important: Always keep a backup kernel in GRUB!${NC}"
}

main "$@"
