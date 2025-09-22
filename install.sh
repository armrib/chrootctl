#!/bin/sh

set -euo pipefail # Exit on error, undefined variables, and pipe failures

readonly PROGRAM_NAME="chrootctl" # Name of the program

# Runtime variables
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Installation directories
readonly INSTALL_DIR="/opt/$PROGRAM_NAME"
readonly BIN_DIR="/usr/local/bin"
readonly LIB_DIR="$INSTALL_DIR/lib"
readonly DATA_DIR="/var/lib/$PROGRAM_NAME"
readonly CACHE_DIR="/var/cache/$PROGRAM_NAME"
readonly DIST_CACHE_DIR="$CACHE_DIR/dist"
readonly CHROOT_CACHE_DIR="$CACHE_DIR/chroot"

# Function to check if the script is run as root
if [ "$(id -u)" -ne 0 ]; then
  echo "Error: This script must be run as root."
  exit 1
fi

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   $PROGRAM_NAME Installation${NC}"
echo -e "${GREEN}================================================${NC}"
echo

# Create installation directories
echo -e "${YELLOW}Creating installation directories...${NC}"
for dir in "$INSTALL_DIR" "$BIN_DIR" "$LIB_DIR" "$DATA_DIR" "$DIST_CACHE_DIR" "$CHROOT_CACHE_DIR"; do
  mkdir -p "$dir"
  chmod 700 "$dir"
done
unset dir

# Copy script files
echo -e "${YELLOW}Installing script files...${NC}"

# Check if scripts exist in current directory
if [ ! -f "$SCRIPT_DIR/main.sh" ]; then
  echo -e "${RED}Error: main.sh not found in current directory${NC}"
  exit 1
fi

# Copy main script
cp "$SCRIPT_DIR/main.sh" "$INSTALL_DIR/$PROGRAM_NAME"
chmod 700 "$INSTALL_DIR/$PROGRAM_NAME"

# Copy utils library
cp -r "$SCRIPT_DIR/lib" "$INSTALL_DIR/"

# Prepare database
touch "$DATA_DIR/db"
chmod 600 "$DATA_DIR/db"

# Create symbolic link for easy execution
ln -sf "$INSTALL_DIR/$PROGRAM_NAME" "$BIN_DIR/$PROGRAM_NAME"
echo -e "${GREEN}✓${NC} Created command: $PROGRAM_NAME"

# Create uninstall script
echo -e "${YELLOW}Creating uninstall script...${NC}"
cat <<EOF >"$INSTALL_DIR/uninstall.sh"
#!/bin/sh
# $PROGRAM_NAME Uninstaller

echo "Uninstalling $PROGRAM_NAME..."

# Remove symbolic link
rm -f $BIN_DIR/$PROGRAM_NAME

# Remove installation directory
rm -rf $INSTALL_DIR

# Remove cache directories
rm -rf $CACHE_DIR

# Remove database
rm -rf $DATA_DIR

echo "$PROGRAM_NAME has been uninstalled"
EOF
chmod 700 "$INSTALL_DIR/uninstall.sh"
echo -e "${GREEN}✓${NC} Uninstall script created"

# Display installation summary
echo
echo -e "${GREEN}================================================${NC}"
echo -e "${GREEN}   Installation Complete!${NC}"
echo -e "${GREEN}================================================${NC}"
echo
echo -e "${GREEN}Installation Summary:${NC}"
echo -e "  • Main script: $INSTALL_DIR/$PROGRAM_NAME"
echo -e "  • Command: $PROGRAM_NAME"
echo
echo -e "${GREEN}Usage Examples:${NC}"
echo -e "  • Create a new chroot with default settings:"
echo -e "    ${YELLOW}$PROGRAM_NAME create test${NC}"
echo
echo -e "  • Create a new debian chroot:"
echo -e "    ${YELLOW}$PROGRAM_NAME create debian -t debian${NC}"
echo
echo -e "  • Enter the chroot:"
echo -e "    ${YELLOW}$PROGRAM_NAME enter test${NC}"
echo
echo -e "  • Delete the chroot:"
echo -e "    ${YELLOW}$PROGRAM_NAME delete test${NC}"
echo
echo -e "${GREEN}Uninstall:${NC}"
echo -e "  • To uninstall, run:"
echo -e "    ${YELLOW}$INSTALL_DIR/uninstall.sh${NC}"
echo
echo -e "${YELLOW}⚠ Important:${NC}"
echo -e "  1. This is a work in progress"
echo -e "  2. It might not work as expected"
echo -e "  3. If there is an error, please report it"
echo -e "  4. It can impact your system!"
echo
