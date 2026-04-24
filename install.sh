#!/bin/bash

# ----------------------------------
# Colors
# ----------------------------------
NC='\033[0m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'

LOG_FILE="/root/cpanel_install.log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

clear
echo "======================================"
echo "     CLYTRIX CPANEL INSTALLER v2.0"
echo "======================================"

# ----------------------------------
# Root Check
# ----------------------------------
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Run as ROOT${NC}"
  exit 1
fi

# ----------------------------------
# Hostname Setup (Validation Added)
# ----------------------------------
echo ""
echo -e "${CYAN}Enter a valid FQDN hostname (e.g. server.yourdomain.com):${NC}"
read HOST

if [[ "$HOST" =~ ^[a-zA-Z0-9.-]+$ && "$HOST" == *.* ]]; then
    hostnamectl set-hostname $HOST
    echo -e "${GREEN}Hostname set to $HOST${NC}"
else
    echo -e "${RED}Invalid hostname!${NC}"
    exit 1
fi

# ----------------------------------
# Server Check
# ----------------------------------
echo ""
echo -e "${CYAN}Checking Server Requirements...${NC}"

RAM=$(free -m | awk '/Mem:/ {print $2}')
CPU=$(nproc)

echo "RAM: $RAM MB | CPU: $CPU Cores"

if [ "$RAM" -lt 2048 ]; then
    echo -e "${RED}Minimum 2GB RAM recommended for cPanel${NC}"
fi

# ----------------------------------
# System Update
# ----------------------------------
echo ""
echo -e "${CYELLOW}Updating System...${NC}"
yum update -y

yum install -y perl curl nano

# ----------------------------------
# Disable NetworkManager (safer way)
# ----------------------------------
systemctl is-active --quiet NetworkManager && {
    echo -e "${YELLOW}Disabling NetworkManager...${NC}"
    systemctl stop NetworkManager
    systemctl disable NetworkManager
}

# ----------------------------------
# Install cPanel
# ----------------------------------
echo ""
echo -e "${CYAN}Installing cPanel/WHM...${NC}"

cd /home
curl -o latest -L https://securedownloads.cpanel.net/latest

echo -e "${GREEN}Installation started (20-40 mins)...${NC}"
sh latest

# ----------------------------------
# Post Install Check
# ----------------------------------
if systemctl is-active --quiet cpanel; then

echo ""
echo "======================================"
echo -e "${GREEN}CPANEL INSTALLED SUCCESSFULLY 🎉${NC}"
echo "======================================"

IP=$(curl -s https://api.ipify.org)

echo -e "WHM URL: ${CYAN}https://$IP:2087${NC}"
echo -e "Login: root"
echo -e "Log File: $LOG_FILE"

# ----------------------------------
# POST INSTALL WIZARD
# ----------------------------------
echo ""
echo -e "${CYAN}Post Installation Optimization Wizard${NC}"

# Firewall
read -p "Install CSF Firewall? (y/n): " CSF
if [[ "$CSF" =~ ^[Yy]$ ]]; then
    cd /usr/src
    rm -fv csf.tgz
    wget https://download.configserver.com/csf.tgz
    tar -xzf csf.tgz
    cd csf
    sh install.sh
    echo -e "${GREEN}CSF Installed${NC}"
fi

# Fail2Ban
read -p "Install Fail2Ban? (y/n): " F2B
if [[ "$F2B" =~ ^[Yy]$ ]]; then
    yum install -y fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    echo -e "${GREEN}Fail2Ban Enabled${NC}"
fi

# LiteSpeed Suggestion
echo ""
echo -e "${YELLOW}LiteSpeed is recommended for high performance.${NC}"
echo -e "Visit: https://litespeedtech.com"

# CloudLinux Suggestion
echo -e "${YELLOW}CloudLinux improves stability & isolation.${NC}"
echo -e "Visit: https://www.cloudlinux.com"

# MySQL Tuning Tip
echo ""
echo -e "${CYAN}Recommended Next Steps:${NC}"
echo "- Secure SSH (change port, disable root login)"
echo "- Enable backups in WHM"
echo "- Configure AutoSSL"
echo "- Tune MySQL based on RAM"

# Reboot Option
echo ""
read -p "Reboot server now? (y/n): " RB
if [[ "$RB" =~ ^[Yy]$ ]]; then
    reboot
fi

else
    echo -e "${RED}Installation Failed. Check logs at $LOG_FILE${NC}"
fi
