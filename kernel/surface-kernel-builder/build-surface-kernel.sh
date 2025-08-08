#!/bin/bash
#
# Surface Laptop Studio 1 - CachyOS Kernel Build Launcher
# 
# This script automatically downloads the latest patches and builds 
# an optimized kernel for Surface Laptop Studio 1 with:
# - Complete CachyOS performance enhancements
# - Full Surface hardware support
# - Optimized for Fedora 42
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/kernel-build-config.conf"
MAIN_SCRIPT="$SCRIPT_DIR/build-complete-fedora42-surface-cachy-kernel.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║    🚀 Surface Laptop Studio 1 - Optimized Kernel Builder 🚀       ║"
    echo "║                                                                    ║"
    echo "║    📊 Performance: CachyOS patches for maximum responsiveness     ║"
    echo "║    🖥️  Hardware: Complete Surface hardware support               ║"
    echo "║    ⚡ Speed: BORE scheduler + BBR3 + memory optimizations         ║"
    echo "║    🔧 Features: ZFS, containers, security, virtualization         ║"
    echo "║                                                                    ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_prerequisites() {
    echo -e "${BLUE}[PREREQ]${NC} Checking system prerequisites..."
    
    # Check OS
    if ! grep -q "Fedora" /etc/os-release; then
        echo -e "${RED}❌ Error: This script requires Fedora Linux${NC}"
        exit 1
    fi
    
    # Check version
    local fedora_version
    fedora_version=$(grep VERSION_ID /etc/os-release | cut -d'"' -f2)
    if [ "$fedora_version" -lt 40 ]; then
        echo -e "${YELLOW}⚠️  Warning: Fedora $fedora_version detected. Fedora 40+ recommended.${NC}"
    fi
    
    # Check hardware
    local hardware_info
    hardware_info=$(dmidecode -s system-product-name 2>/dev/null || echo "Unknown")
    if [[ "$hardware_info" == *"Surface"* ]]; then
        echo -e "${GREEN}✅ Surface device detected: $hardware_info${NC}"
    else
        echo -e "${YELLOW}⚠️  Warning: Surface device not detected. Hardware: $hardware_info${NC}"
        echo -e "${YELLOW}   This kernel is optimized for Surface Laptop Studio 1${NC}"
    fi
    
    # Check disk space
    local available_gb
    available_gb=$(df "$HOME" | awk 'NR==2{print int($4/1024/1024)}')
    if [ "$available_gb" -lt 30 ]; then
        echo -e "${RED}❌ Error: Need at least 30GB free space. Available: ${available_gb}GB${NC}"
        exit 1
    fi
    
    # Check memory
    local total_gb
    total_gb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
    if [ "$total_gb" -lt 8 ]; then
        echo -e "${YELLOW}⚠️  Warning: Less than 8GB RAM detected (${total_gb}GB). Build may be slow.${NC}"
    fi
    
    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

show_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}[CONFIG]${NC} Current configuration:"
        echo -e "${CYAN}  Performance:${NC}"
        echo "    ├─ CPU Architecture: $(grep "^CPU_ARCH=" "$CONFIG_FILE" | cut -d'"' -f2)"
        echo "    ├─ LTO: $(grep "^ENABLE_LTO=" "$CONFIG_FILE" | cut -d'"' -f2)"
        echo "    ├─ Scheduler: $(grep "^SCHEDULER=" "$CONFIG_FILE" | cut -d'"' -f2)"
        echo "    ├─ Timer Frequency: $(grep "^TIMER_FREQ=" "$CONFIG_FILE" | cut -d'"' -f2)Hz"
        echo "    └─ Preemption: $(grep "^PREEMPT_MODEL=" "$CONFIG_FILE" | cut -d'"' -f2)"
        echo -e "${CYAN}  Features:${NC}"
        echo "    ├─ ZFS Support: $(grep "^ENABLE_ZFS=" "$CONFIG_FILE" | cut -d'"' -f2)"
        echo "    ├─ NVIDIA Support: $(grep "^ENABLE_NVIDIA=" "$CONFIG_FILE" | cut -d'"' -f2)"
        echo "    ├─ Surface Hardware: Complete support enabled"
        echo "    └─ Containers: $(grep "^ENABLE_CONTAINERS=" "$CONFIG_FILE" | cut -d'"' -f2)"
    else
        echo -e "${YELLOW}⚠️  Configuration file not found. Using defaults.${NC}"
    fi
}

estimate_build_time() {
    local cpu_cores
    cpu_cores=$(nproc)
    local total_gb
    total_gb=$(grep MemTotal /proc/meminfo | awk '{print int($2/1024/1024)}')
    
    echo -e "${BLUE}[ESTIMATE]${NC} Build time estimation:"
    echo "  ├─ CPU cores: $cpu_cores"
    echo "  ├─ Memory: ${total_gb}GB"
    
    if [ "$cpu_cores" -ge 8 ] && [ "$total_gb" -ge 16 ]; then
        echo -e "  └─ Estimated time: ${GREEN}2-3 hours${NC} (fast system)"
    elif [ "$cpu_cores" -ge 4 ] && [ "$total_gb" -ge 8 ]; then
        echo -e "  └─ Estimated time: ${YELLOW}3-4 hours${NC} (moderate system)"
    else
        echo -e "  └─ Estimated time: ${RED}4-6 hours${NC} (slower system)"
    fi
}

interactive_config() {
    echo -e "${BLUE}[SETUP]${NC} Would you like to customize the build configuration?"
    echo "1) Use recommended settings (fastest, good performance)"
    echo "2) High performance (longer build, maximum optimization)"
    echo "3) Custom configuration (edit config file)"
    echo "4) Continue with current settings"
    
    read -p "Choose option [1-4]: " choice
    
    case $choice in
        1)
            echo -e "${GREEN}✅ Using recommended settings${NC}"
            cat > "$CONFIG_FILE" << 'EOF'
# Recommended settings for Surface Laptop Studio 1
CPU_ARCH="x86-64-v3"
ENABLE_LTO="thin"
TIMER_FREQ="1000"
SCHEDULER="bore"
ENABLE_ZFS="yes"
ENABLE_NVIDIA="yes"
PARALLEL_JOBS=""
EOF
            ;;
        2)
            echo -e "${YELLOW}⚡ Using high performance settings${NC}"
            cat > "$CONFIG_FILE" << 'EOF'
# High performance settings
CPU_ARCH="native"
ENABLE_LTO="full"
ENABLE_PGO="yes"
TIMER_FREQ="1000"
SCHEDULER="bore"
ENABLE_ZFS="yes"
ENABLE_NVIDIA="yes"
PARALLEL_JOBS=""
OPT_LEVEL="3"
EOF
            ;;
        3)
            echo -e "${CYAN}📝 Opening configuration file for editing...${NC}"
            if command -v nano >/dev/null; then
                nano "$CONFIG_FILE"
            elif command -v vim >/dev/null; then
                vim "$CONFIG_FILE"
            elif command -v gedit >/dev/null; then
                gedit "$CONFIG_FILE"
            else
                echo -e "${RED}❌ No suitable editor found. Please edit $CONFIG_FILE manually.${NC}"
                exit 1
            fi
            ;;
        4)
            echo -e "${BLUE}📋 Continuing with existing settings${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid choice. Using recommended settings.${NC}"
            choice=1
            ;;
    esac
}

confirm_build() {
    echo
    echo -e "${YELLOW}🔔 IMPORTANT WARNINGS:${NC}"
    echo "  ⚠️  This build will take 2-6 hours depending on your system"
    echo "  ⚠️  Keep your system plugged in during the build"
    echo "  ⚠️  Ensure stable internet connection for patch downloads"
    echo "  ⚠️  Always keep a backup kernel available in GRUB"
    echo "  ⚠️  Test thoroughly before relying on the new kernel"
    echo
    
    local disk_usage
    disk_usage=$(df -h "$HOME" | awk 'NR==2{print $4}')
    echo -e "${BLUE}📊 System Status:${NC}"
    echo "  ├─ Available space: $disk_usage"
    echo "  ├─ CPU cores: $(nproc)"
    echo "  ├─ Memory: $(free -h | awk 'NR==2{print $2}')"
    echo "  └─ Load average: $(uptime | awk -F'load average:' '{print $2}')"
    echo
    
    read -p "🚀 Ready to start the build? [y/N]: " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}🛑 Build cancelled by user${NC}"
        exit 0
    fi
}

run_build() {
    echo -e "${GREEN}🚀 Starting kernel build process...${NC}"
    echo
    
    # Source configuration if it exists
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${BLUE}[LOADING]${NC} Loading configuration from $CONFIG_FILE..."
        # Export variables from config file
        set -a
        source "$CONFIG_FILE"
        set +a
    fi
    
    # Check if main script exists
    if [ ! -f "$MAIN_SCRIPT" ]; then
        echo -e "${RED}❌ Main build script not found: $MAIN_SCRIPT${NC}"
        echo "Please ensure all script files are in the same directory."
        exit 1
    fi
    
    # Make main script executable
    chmod +x "$MAIN_SCRIPT"
    
    # Run the main build script
    echo -e "${CYAN}🔧 Executing main build script...${NC}"
    exec "$MAIN_SCRIPT"
}

show_help() {
    echo "Surface Laptop Studio 1 - CachyOS Kernel Builder"
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --config          Edit configuration before building"
    echo "  --recommended     Use recommended settings and build"
    echo "  --performance     Use high performance settings and build"
    echo "  --check-only      Only check prerequisites and show config"
    echo "  --help, -h        Show this help message"
    echo
    echo "Features included:"
    echo "  ✅ CachyOS performance patches (BORE scheduler, BBR3, etc.)"
    echo "  ✅ Complete Surface Laptop Studio 1 hardware support"
    echo "  ✅ Intel + NVIDIA GPU optimizations"
    echo "  ✅ Advanced power management"
    echo "  ✅ ZFS filesystem support"
    echo "  ✅ Container and virtualization support"
    echo "  ✅ Security hardening features"
    echo
    echo "Build time: 2-6 hours depending on system specifications"
    echo "Disk space required: ~30GB"
    echo "Recommended: 8+ cores, 16GB+ RAM for optimal build speed"
}

# Parse command line options
case "${1:-}" in
    --help|-h)
        show_help
        exit 0
        ;;
    --check-only)
        print_banner
        check_prerequisites
        show_configuration
        estimate_build_time
        exit 0
        ;;
    --config)
        print_banner
        check_prerequisites
        interactive_config
        show_configuration
        estimate_build_time
        confirm_build
        run_build
        ;;
    --recommended)
        print_banner
        check_prerequisites
        echo -e "${GREEN}✅ Using recommended settings${NC}"
        # Create recommended config
        cat > "$CONFIG_FILE" << 'EOF'
CPU_ARCH="x86-64-v3"
ENABLE_LTO="thin"
TIMER_FREQ="1000"
SCHEDULER="bore"
ENABLE_ZFS="yes"
ENABLE_NVIDIA="yes"
EOF
        show_configuration
        estimate_build_time
        confirm_build
        run_build
        ;;
    --performance)
        print_banner
        check_prerequisites
        echo -e "${YELLOW}⚡ Using high performance settings${NC}"
        # Create performance config
        cat > "$CONFIG_FILE" << 'EOF'
CPU_ARCH="native"
ENABLE_LTO="full"
TIMER_FREQ="1000"
SCHEDULER="bore"
ENABLE_ZFS="yes"
ENABLE_NVIDIA="yes"
OPT_LEVEL="3"
EOF
        show_configuration
        estimate_build_time
        confirm_build
        run_build
        ;;
    "")
        # Interactive mode
        print_banner
        check_prerequisites
        show_configuration
        estimate_build_time
        interactive_config
        show_configuration
        confirm_build
        run_build
        ;;
    *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
