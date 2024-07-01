#!/usr/bin/env bash

# this scripts only support wsl2
# WSL 版本： 2.2.4.0
# 内核版本： 5.15.153.1-2
# WSLg 版本： 1.0.61
# MSRDC 版本： 1.2.5326
# Direct3D 版本： 1.611.1-81528511
# DXCore 版本： 10.0.26091.1-240325-1447.ge-release
# Windows 版本： 10.0.22631.3737

VERSION_NO="1.0.0"
WIN_USER=$(whoami.exe | awk -F "\\" '{print $2}' | tr -d '\r')
LINUX_USER=$(whoami)

USERDIRECTORIES=(Desktop Documents Downloads Music Pictures Videos)
WSL_CONFIG_WIN_PATH="/mnt/c/Users/${WIN_USER}/.wslconfig"

PROXY_CMD1='host_ip=$(cat /etc/resolv.conf | grep "nameserver" | cut -f 2 -d " ")'
PROXY_CMD2='export ALL_PROXY="http://$host_ip:7890"'

function linkDir() {
    src=$1
    dest=$2

    # check if src directory exists
    if [ ! -d "$src" ]; then
        echo "Source file $src does not exist"
        return
    fi

    if [ ! -d $dest ]; then
        cmd="ln -s $src $dest"
        eval "$cmd"
        echo "$cmd"
        return
    fi

}

function getSourceFilePath() {
    str=$(echo "$SHELL" | awk -F "/" '{print $4}')
    if [[ "${str}" == "zsh" ]]; then
        echo "${HOME}/.zshrc"
    elif [[ "${str}" == "bash" ]]; then
        echo "$HOME/.bashrc"
    else
        echo "the shell scripts is not support ${str}"
        exit
    fi
}

function bindUserWorkspaceFromWinToLinux() {

    # check if these user exists
    if [ ! -d /mnt/c/Users/$WIN_USER ]; then
        echo "User $WIN_USER does not exist in Windows"
        return
    fi

    if ! id -u $LINUX_USER &>/dev/null; then
        echo "User $LINUX_USER does not exist in Linux"
        return
    fi

    # shellcheck disable=SC2068
    for dir in ${USERDIRECTORIES[@]}; do
        linkDir "/mnt/c/Users/$WIN_USER/$dir" "/home/$LINUX_USER/$dir"
    done

}

function unBindUserWorkspaceFromWinToLinux() {
    echo "Unbinding user workspace from Windows to Linux"
    LINUX_USER=$(whoami)

    # shellcheck disable=SC2068
    for dir in ${USERDIRECTORIES[@]}; do
        if [ -L "/home/$LINUX_USER/$dir" ]; then
            cmd="rm /home/$LINUX_USER/$dir"
            eval $cmd
            echo $cmd
        fi
    done
}

function proxy() {
    enable_proxy=$1
    if [ ! -n "$enable_proxy" ]; then
        echo "Usage: proxy.sh [1|0]"
        return
    fi

    # check if enable_proxy is exists
    if [ -z "$enable_proxy" ]; then
        echo "Usage: --proxy [1|0], 1 is enable proxy, 0 is disable proxy"
        return
    fi

    source_file=$(getSourceFilePath)

    if [ ! -f "${WSL_CONFIG_WIN_PATH}" ]; then
        echo "Creating wslconfig file"
        cat <<EOT >"${WSL_CONFIG_WIN_PATH}"
[wsl2]
nestedVirtualization=true
ipv6=true
[experimental]
autoMemoryReclaim=gradual # gradual | dropcache | disabled
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
EOT

        echo "insert wsl proxy to $source_file"
        cat <<EOT >>"${source_file}"

# wsl proxy
$PROXY_CMD1
$PROXY_CMD2
EOT

    fi

    if [ "$enable_proxy" -eq 1 ]; then
        echo "Enabling proxy"
        sed -i 's/^# host_ip/host_ip/' $source_file
        sed -i 's/^# export ALL_PROXY/export ALL_PROXY/' $source_file
    elif [ "$enable_proxy" -eq "0" ]; then
        echo "Disabling proxy"
        sed -i 's/^host_ip/# host_ip/' $source_file
        sed -i 's/^export ALL_PROXY/# export ALL_PROXY/' $source_file

    #  unset host_ip
    #  unset ALL_PROXY
    fi

}

function unProxy() {
    echo "clear proxy config"
    rm -f $WSL_CONFIG_WIN_PATH
    echo "delete $WSL_CONFIG_WIN_PATH"

    PROXY_CMD1='host_ip=$(cat /etc/resolv.conf | grep "nameserver" | cut -f 2 -d " ")'
    temp1=$(echo "$PROXY_CMD1" | sed 's/[\*\.&\/]/\\&/g')
    temp2=$(echo "$PROXY_CMD2" | sed 's/[\*\.&\/]/\\&/g')

    sed -i "/# wsl proxy/d" ~/.zshrc
    sed -i "/${temp1}/d" ~/.zshrc
    sed -i "/${temp2}/d" ~/.zshrc

    sed -i "/# wsl proxy/d" ~/.bashrc
    sed -i "/${temp1}/d" ~/.bashrc
    sed -i "/${temp2}/d" ~/.bashrc

    echo "remove wsl proxy from $HOME/.zshrc"

}

function status() {
    bindedTxt="binded"
    proxyTxt=""

    for dir in ${USERDIRECTORIES[@]}; do
        if [ ! -L "/home/$LINUX_USER/$dir" ]; then
            bindedTxt="not binded or not binded all"
            break
        fi
    done

    source_file=$(getSourceFilePath)
    if [ ! -f "${WSL_CONFIG_WIN_PATH}" ]; then
        proxyTxt="not init"
    elif [ ! -z "$(grep -e "^host_ip" $source_file)" ]; then
        proxyTxt="enabled"
    elif [ ! -z "$(grep -e "^# host_ip" $source_file)" ]; then
        proxyTxt="disabled"
    else
        proxyTxt="not init"
    fi

    echo -e "binded: $bindedTxt\nproxy: $proxyTxt"

}

function help() {
    echo "Usage: $(basename "$0") [options]"
    echo "Options:"
    echo "  --bind        	 bind user workspace from Windows to Linux, it will uses both win user and linux user which login in now"
    echo "  --unbind        	 unbind user workspace from Windows to Linux"
    echo "  --proxy [1|0]          control network proxy,1 is enable and 0 is disable, and then restart wsl"
    echo "  --unproxy        	 clear proxy config, and then restart wsl"
    echo "  --status        	 show the status of binded and proxy"
    echo "  --rest        	 clear all operations before excuted, and then restart wsl"
    echo "  --version, -v          show version"
    echo "  --help, -h             show help"
}

# Parse command-line options with parameters
while [[ $# -gt 0 ]]; do
    case "$1" in
    --version | -v)
        echo "Version: ${VERSION_NO}"
        exit
        ;;
    --help | -h)
        help
        exit
        ;;
    --status)
        status
        ;;
    --rest)
        echo "clear all operations"
        echo "excute unBindUserWorkspaceFromWinToLinux func"
        unBindUserWorkspaceFromWinToLinux

        echo "excute unProxy func"
        unProxy

        wsl.exe --shutdown
        exit
        ;;
    --bind)
        bindUserWorkspaceFromWinToLinux
        exit
        ;;
    --unbind)
        unBindUserWorkspaceFromWinToLinux
        exit
        ;;
    --proxy)
        proxy $2
        wsl.exe --shutdown
        exit
        ;;
    --unproxy)
        unProxy
        wsl.exe --shutdown
        exit
        ;;
    *)
        help
        exit
        ;;
    esac
    shift
done

help
