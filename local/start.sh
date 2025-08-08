#!/bin/bash
set -e

# Install heliosup if not already installed
if [ ! -f "/usr/local/bin/helios" ]; then
  echo "[*] Installing helios..."
  curl -s https://raw.githubusercontent.com/a16z/helios/master/heliosup/install | bash
  /root/.helios/bin/heliosup
else
  echo "[*] Helios already installed"
fi

# Start helios with supplied or default args
exec /root/.helios/bin/helios ethereum \
    --network mainnet \
    --consensus-rpc https://www.lightclientdata.org \
    --execution-rpc https://ethereum-mainnet.g.allthatnode.com \