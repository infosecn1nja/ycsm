# You Can't See Me (YCSM)

This is a quick script installation for redirector setup (nginx reverse proxy, letsencrypt) compatible with some popular RATS (Cobalt Strike, Empire, Metasploit).

If HTTPS was selected, it will automatically setup letsencrypt certbot and obtain valid letsencrypt SSL certificates for your redirector domain name, and start nginx using the generated configuration. Using redirector an added benefit of using a separate host if domain is burned, real IP of C2 will still be useable. 

## Features
* Evade Vendor Sandboxes
* Block Shodan Access
* Block Vulnerability Scanners & Bots
* Auto SSL setup for HTTPS using letsencrypt certbot.
* Adds original source ip to user-agent header for easy tracking.

## Getting Started
```
git clone https://github.com/infosecn1nja/ycsm
cd ycsm
chmod +x ycsm-setup.sh

1) Setup Nginx Redirector
2) Check Status
3) Blocking Shodan
4) Quit

  YCSM - Select an Option:
```