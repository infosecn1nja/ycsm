#!/bin/bash

NORMAL=`echo "\033[m"`
BRED=`printf "\e[1;31m"`
BGREEN=`printf "\e[1;32m"`
BYELLOW=`printf "\e[1;33m"`
COLUMNS=12

ycsm_action() {
  printf "\n${BGREEN}[+]${NORMAL} $1\n"
}

ycsm_warning() {
  printf "\n${BYELLOW}[!]${NORMAL} $1\n"
}

ycsm_error() {
  printf "\n${BRED}[!] $1${NORMAL}\n"
}

error_exit() {
  echo -e "\n$1\n" 1>&2
  exit 1
}

check_errors() {
  if [ $? -ne 0 ]; then
    ycsm_error "An error occurred..."
    error_exit "Exiting..."
  fi
}

ycsm_check_root() {
  if [ "$EUID" -ne 0 ]; then
    ycsm_error "Please run as root"
    exit
  fi
}

ycsm_confirm() {
  read -r -p "$1 [y/N] " response
  case "$response" in
      [yY][eE][sS]|[yY])
          return 0
          ;;
      *)
          return 1
          ;;
  esac
}

ycsm_install() {
  CONF_DST="/etc/nginx/sites-enabled/default"

  ycsm_action "Installing Dependencies..."
  apt-get install -y vim less

  ycsm_action "Updating apt-get..."
  apt-get update
  check_errors

  ycsm_action "Installing general net tools..."
  apt-get install -y inetutils-ping net-tools screen dnsutils curl
  check_errors

  ycsm_action "Installing nginx git..."
  apt-get install -y nginx nginx-extras git

  ycsm_action "Installing certbot..."
  git clone https://github.com/certbot/certbot.git /opt/letsencrypt > /dev/null 2>&1\

  ycsm_action "Adding cronjob..."
  cp ycsm-cron /etc/cron.d/ycsm
  check_errors

  ycsm_action "Copy nginx.conf, maps & security configuration into nginx folder"
  cp -rf maps security /etc/nginx
  mv /etc/nginx/nginx.conf /etc/nginx/nginx.conf.bak 
  cp -rf ./nginx.conf /etc/nginx/nginx.conf
  check_errors

  ycsm_action "Installing fail2ban..."
  apt-get install -y fail2ban
  check_errors
  
  ycsm_action "Finished installing dependencies!"
}

ycsm_initialize() {
  ycsm_action "Modifying nginx configs..."
  if [ "$#" -ne 2 ]; then
    read -r -p "What is the sites domain name? (ex: google.com) " domain_name
    read -r -p "What is the C2 server address? (IP:Port) " c2_server
  else
    domain_name=$1
    c2_server=$2
  fi

  cp ./default.conf $CONF_DST

  sed -i.bak "s/<DOMAIN_NAME>/$domain_name/" $CONF_DST
  rm $CONF_DST.bak

  sed -i.bak "s/<C2_SERVER>/$c2_server/" $CONF_DST
  rm $CONF_DST.bak
  check_errors

  SSL_SRC="/etc/letsencrypt/live/$domain_name"
  ycsm_action "Obtaining Certificates..."
  /opt/letsencrypt/certbot-auto certonly --non-interactive --quiet --register-unsafely-without-email --agree-tos -a webroot --webroot-path=/var/www/html -d $domain_name
  check_errors

  ycsm_action "Installing Certificates..."
  sed -i.bak "s/^#ycsm#//g" $CONF_DST
  rm $CONF_DST.bak
  check_errors

  ycsm_action "Move Sites..."
  mv /var/www/html/index.html /var/www/html/index.html.bak
  cp -rf ./sites/index.html /var/www/html/index.html
  mkdir -p /var/www/html/static/js
  cp -rf ./sites/jquery-2.2.4.min.js /var/www/html/static/js/jquery-2.2.4.min.js
  check_errors
    
  ycsm_action "Restarting Nginx..."
  systemctl restart nginx.service
  check_errors

  ycsm_action "Done!"
}

ycsm_setup() {
  ycsm_install
  ycsm_initialize $1 $2
}

ycsm_block_shodan() {
  printf "\n************************ Blocking Shodan ************************\n"
  iptables -A INPUT -s 104.131.0.69,104.236.198.48,155.94.222.12,155.94.254.133,155.94.254.143,162.159.244.38,185.181.102.18,188.138.9.50,198.20.69.74,198.20.69.98,198.20.70.114,198.20.87.98,198.20.99.130,208.180.20.97,209.126.110.38,216.117.2.180,66.240.192.138,66.240.219.146,66.240.236.119,71.6.135.131,71.6.146.185,71.6.158.166,71.6.165.200,71.6.167.142,82.221.105.6,82.221.105.7,85.25.103.50,85.25.43.94,93.120.27.62,98.143.148.107,98.143.148.135 -j DROP
  iptables-save > /etc/iptables.conf
  ycsm_action "Done!"
}

ycsm_status() {
  printf "\n************************ Processes ************************\n"
  ps aux | grep -E 'nginx' | grep -v grep

  printf "\n************************* Network *************************\n"
  netstat -tulpn | grep -E 'nginx'
}

ycsm_fail2ban() {
  printf "\n************************* Configure Fail2Ban *************************\n"
  cp -rf /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak
  echo -e '[Definition]\nfailregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" 403\nignoreregex =' > /etc/fail2ban/filter.d/nginx-403.conf
  echo -e '[Definition]\nfailregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" 404\nignoreregex =' > /etc/fail2ban/filter.d/nginx-404.conf
  echo -e '[Definition]\nfailregex = ^<HOST> -.*"(GET|POST|HEAD).*HTTP.*" 444\nignoreregex =' > /etc/fail2ban/filter.d/nginx-444.conf
  echo -e '\n[nginx-403]\n\nenabled = true\nport = http,https\nfilter = nginx-403\nlogpath = /var/log/nginx/access.log\nmaxretry = 5\nfindtime = 300' >> /etc/fail2ban/jail.conf
  echo -e '\n[nginx-404]\n\nenabled = true\nport = http,https\nfilter = nginx-404\nlogpath = /var/log/nginx/access.log\nmaxretry = 10\nfindtime = 300' >> /etc/fail2ban/jail.conf
  echo -e '\n[nginx-444]\n\nenabled = true\nport = http,https\nfilter = nginx-444\nlogpath = /var/log/nginx/access.log\nmaxretry = 10\nfindtime = 300' >> /etc/fail2ban/jail.conf
  ycsm_action "Done!"
  check_errors
}

ycsm_check_root

if [ "$#" -ne 4 ]; then
  PS3="
  YCSM - Select an Option:  "

  finshed=0
  while (( !finished )); do
    printf "\n"
    options=("Setup Nginx Redirector" "Check Status" "Blocking Shodan" "Configure Fail2Ban" "Quit")
    select opt in "${options[@]}"
    do
      case $opt in
        "Setup Nginx Redirector")
          ycsm_setup
          break;
          ;;
        "Check Status")
          ycsm_status
          break;
          ;;
        "Blocking Shodan")
          ycsm_block_shodan
          break;
          ;;
        "Configure Fail2Ban")
          ycsm_fail2ban
          break;
          ;;          
        "Quit")
          finished=1
          break;
          ;;
        *) ycsm_warning "invalid option" ;;
      esac
    done
  done
else
  ycsm_setup $1 $2
fi
