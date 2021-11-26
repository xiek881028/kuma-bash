#!/bin/bash
set -e

echo -e "\033[47;30m 该脚本用于部署常用的node环境安装 \033[0m"
echo -e "\033[47;30m 在询问阶段选项并未真正执行，可以随时按^C退出脚本 \033[0m"
echo -e "\033[33m 注意！该脚本仅在centos系统做过测试，其他系统未必适用 \033[0m"
echo

# Options
DEFAULT_NODE_VERSION="14.18.1"
NODE_INSTALLATION_PATH="/usr/local/lib/node"

if [[ -z $NODE ]]; then
  typeset -u NODE
  read -p "安装Node[Y/N]: (N) " NODE
  if [[ -z $NODE ]]; then
    NODE='N'
  fi
fi

if [[ $NODE == 'Y' && -d $NODE_INSTALLATION_PATH ]]; then
  typeset -u NODE
  if [[ -z $NODE_OVERWRITE ]]; then
    read -p "Node已安装, 是否覆盖[Y/N]: (Y) " NODE
    if [[ -z $NODE ]]; then
      NODE='Y'
    fi
  else
    NODE=$NODE_OVERWRITE
  fi
fi

if [[ $NODE == 'Y' ]]; then
  if [[ -z $NODE_VERSION ]]; then
    read -p "Node版本号: ($DEFAULT_NODE_VERSION) " NODE_VERSION
    if [[ -z $NODE_VERSION ]]; then
      NODE_VERSION=$DEFAULT_NODE_VERSION
    fi
  fi
fi

# Install
install_node() {
  if [[ $NODE != 'Y' ]]; then
    return
  fi

  set -x
  if [[ -d $NODE_INSTALLATION_PATH ]]; then
    sudo mv $NODE_INSTALLATION_PATH "$NODE_INSTALLATION_PATH.`date +%Y%m%d%H%M%S`"
  fi
  # if [[ ! -f "node-v$NODE_VERSION-linux-x64.tar.xz" ]]; then
  #   curl --compressed -fLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz"
  # else
  if [[ -f "node-v$NODE_VERSION-linux-x64.tar.xz" ]]; then
    sudo rm -rf "node-v$NODE_VERSION-linux-x64"
  else
    wget -c "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz"
  fi
  tar xvf "node-v$NODE_VERSION-linux-x64.tar.xz"
  sudo chown root:root -R "node-v$NODE_VERSION-linux-x64"
  sudo mv "node-v$NODE_VERSION-linux-x64" $NODE_INSTALLATION_PATH
  sudo echo "export PATH=$NODE_INSTALLATION_PATH/bin:"'$PATH' > /etc/profile.d/node.sh
  sudo source /etc/profile.d/node.sh
  sudo rm -rf "node-v$NODE_VERSION-linux-x64.tar.xz"
  sudo ln -s /usr/local/lib/node/bin/node /usr/bin/node
  sudo ln -s /usr/local/lib/node/bin/npm /usr/bin/npm
  sudo ln -s /usr/local/lib/node/bin/npx /usr/bin/npx
  # npm config set disturl https://npm.taobao.org/dist --global
  # npm config set registry https://registry.npm.taobao.org --global
  # npm install -g --registry=https://registry.npm.taobao.org npm@latest yarn
  # yarn config set disturl https://npm.taobao.org/dist --global
  # yarn config set registry https://registry.npm.taobao.org --global
  set +x
}

install_node
