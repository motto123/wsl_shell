#!/usr/bin/env zsh

# if $1 is 1, then enable proxy and then restart wsl
# if $1 is 0, then disable proxy and then restart wsl
# if $1 is other, then show help
if [ -n "$1" ] && [ "$1" -eq 1 ]; then
  echo "Enabling proxy"
  sed -i 's/^# host_ip/host_ip/' ~/.zshrc
  sed -i 's/^# export ALL_PROXY/export ALL_PROXY/' ~/.zshrc
#  source ~/.zshrc
elif [ -n "$1" ] && [ "$1" -eq "0" ]; then
  echo "Disabling proxy"
  sed -i 's/^host_ip/# host_ip/' ~/.zshrc
  sed -i 's/^export ALL_PROXY/# export ALL_PROXY/' ~/.zshrc
#  unset host_ip
#  unset ALL_PROXY
else
  #  if [ -n "$ALL_PROXY" ]; then
  #    echo "Proxy is enabled"
  #  else
  #    echo "Proxy is disabled"
  #  fi
  #  echo -e "ALL_PROXY=${ALL_PROXY}\n."
  echo "Usage: proxy.sh [1|0]"
  echo "1: enable proxy"
  echo "0: disable proxy"
  echo "restart wsl after enabling or disabling proxy"
fi
