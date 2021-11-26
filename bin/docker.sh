#!/bin/bash
set -e

echo -e "\033[47;30m 该脚本用于部署常用的docker环境安装 \033[0m"
echo -e "\033[47;30m 在询问阶段选项并未真正执行，可以随时按^C退出脚本 \033[0m"
echo -e "\033[33m 注意！该脚本仅在centos系统做过测试，其他系统未必适用 \033[0m"
echo

# Options
if [[ -z $DOCKER ]]; then
  typeset -u DOCKER
  read -p "安装/卸载Docker[Y/N]: (N) " DOCKER
  if [[ -z $DOCKER ]]; then
    DOCKER='N'
  fi
fi

if [[ $DOCKER == 'Y' ]]; then
  typeset -u DOCKER_INSTALL_TYPE
  echo "请选择Docker安装形式:"
  echo "0. 在线安装"
  echo "1. 离线安装"
  echo "2. 离线卸载"
  read -p "请输入索引: (0) " DOCKER_INSTALL_TYPE
  if [[ -z $DOCKER_INSTALL_TYPE ]]; then
    DOCKER_INSTALL_TYPE="0"
  fi
  if [[ $DOCKER_INSTALL_TYPE == '0' ]]; then
    if [[ -z $DOCKER_VERSION ]]; then
      read -p "Docker版本号: " DOCKER_VERSION
    fi
    if [[ -z $DOCKER_INSTALLATION_SOURCE ]]; then
      typeset -u DOCKER_INSTALLATION_SOURCE
      echo "请选择Docker安装源:"
      echo "0. Google"
      echo "1. 阿里云"
      echo "2. Azure中国"
      read -p "请输入索引: (0) " DOCKER_INSTALLATION_SOURCE
      if [[ -z $DOCKER_INSTALLATION_SOURCE ]]; then
        DOCKER_INSTALLATION_SOURCE="0"
      fi
    fi
  elif [[ $DOCKER_INSTALL_TYPE == '1' ]]; then
    echo "离线安装需准备Docker安装包"
    echo "请将安装包放置于与bash同级目录并确保目录中没有名称为docker的文件夹"
    echo "Docker安装包可在这获取: https://download.docker.com/linux/static/stable/x86_64/"
    echo -e "\033[33m 注意！手动安装测试版本为20.10.11，版本差异过大可能会安装失败 \033[0m"
    # containerd arm64安装包可在这获取: https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/arm64/
    # echo "containerd安装包可在这获取: https://containerd.io/downloads/"
    read -p "请输入Docker安装包名: " DOCKER_TAR
    # read -p "请输入containerd.io安装包名: " DOCKER_CONTAINERD
  fi
fi

# Install
install_docker() {
  if [[ $DOCKER != 'Y' ]]; then
    return
  fi

  DOCKER_INSTALLATION_SOURCE_MIRROR=''
  case $DOCKER_INSTALLATION_SOURCE in
    1)
      DOCKER_INSTALLATION_SOURCE_MIRROR=Aliyun
      ;;
    2)
      DOCKER_INSTALLATION_SOURCE_MIRROR=AzureChinaCloud
      ;;
  esac

  set -x
  export VERSION=$DOCKER_VERSION
  sudo curl -fsSL https://get.docker.com/ | sh -s docker --mirror $DOCKER_INSTALLATION_SOURCE_MIRROR
  # usermod -aG docker username
  # echo '{"registry-mirrors":[],"insecure-registries":[],"exec-opts":["native.cgroupdriver=systemd"]}' > /etc/docker/daemon.json
  # https://cr.console.aliyun.com/cn-hangzhou/instances/mirrors
  sudo systemctl enable --now docker
  set +x
  # centos实际是用yum进行安装，可用 yum list installed|grep docker 列出所有与docker有关的插件然后使用 yum remove package 来卸载
}

offline_uninstall() {
  sudo systemctl kill containerd.service && true
  sudo systemctl kill docker.socket && true
  sudo systemctl kill docker.service && true
  sudo systemctl daemon-reload
  sudo rm -rf /run/docker*
  sudo rm -rf /run/containerd*
  sudo rm -rf /usr/local/bin/docker*
  sudo rm -rf /usr/local/bin/containerd*
  sudo rm -rf /usr/local/bin/ctr
  sudo rm -rf /usr/local/bin/runc
  sudo rm -rf /usr/local/lib/docker
  sudo rm -rf /usr/lib/systemd/system/containerd.service
  sudo rm -rf /usr/lib/systemd/system/docker.service
  sudo rm -rf /usr/lib/systemd/system/docker.socket
  sudo rm -rf /var/lib/docker
  sudo rm -rf /var/lib/dockershim
  echo "卸载完成"
}

offline_install() {
  if [[ $DOCKER != 'Y' ]]; then
    return
  fi
  set -x
  sudo tar -xzf $DOCKER_TAR
  sudo chown root:root -R docker
  # mkdir -p containerd
  # tar -xzf $DOCKER_CONTAINERD -C containerd
  # mv containerd /usr/local/lib
  if [[ -d /usr/local/lib/docker ]]; then
    date=`echo \`date +%Y%m%d%H%M%S\``
    mv /usr/local/lib/docker /usr/local/lib/docker.$date
  fi
  sudo mv -f docker /usr/local/lib
  sudo ln -s /usr/local/lib/docker/containerd /usr/local/bin/containerd && true
  sudo ln -s /usr/local/lib/docker/containerd-shim /usr/local/bin/containerd-shim && true
  sudo ln -s /usr/local/lib/docker/containerd-shim-runc-v2 /usr/local/bin/containerd-shim-runc-v2 && true
  sudo ln -s /usr/local/lib/docker/ctr /usr/local/bin/ctr && true
  sudo ln -s /usr/local/lib/docker/docker /usr/local/bin/docker && true
  sudo ln -s /usr/local/lib/docker/dockerd /usr/local/bin/dockerd && true
  sudo ln -s /usr/local/lib/docker/docker-init /usr/local/bin/docker-init && true
  sudo ln -s /usr/local/lib/docker/docker-proxy /usr/local/bin/docker-proxy && true
  sudo ln -s /usr/local/lib/docker/runc /usr/local/bin/runc && true

  # 写service文件
	sudo cat > /usr/lib/systemd/system/containerd.service <<- EOF
    # Copyright The containerd Authors.
    #
    # Licensed under the Apache License, Version 2.0 (the "License");
    # you may not use this file except in compliance with the License.
    # You may obtain a copy of the License at
    #
    #     http://www.apache.org/licenses/LICENSE-2.0
    #
    # Unless required by applicable law or agreed to in writing, software
    # distributed under the License is distributed on an "AS IS" BASIS,
    # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    # See the License for the specific language governing permissions and
    # limitations under the License.

    [Unit]
    Description=containerd container runtime
    Documentation=https://containerd.io
    After=network.target local-fs.target

    [Service]
    ExecStartPre=-/sbin/modprobe overlay
    ExecStart=/usr/local/bin/containerd

    Type=notify
    Delegate=yes
    KillMode=process
    Restart=always
    RestartSec=5
    # Having non-zero Limit*s causes performance problems due to accounting overhead
    # in the kernel. We recommend using cgroups to do container-local accounting.
    LimitNPROC=infinity
    LimitCORE=infinity
    LimitNOFILE=1048576
    # Comment TasksMax if your systemd version does not supports it.
    # Only systemd 226 and above support this version.
    TasksMax=infinity
    OOMScoreAdjust=-999

    [Install]
    WantedBy=multi-user.target
	EOF

	sudo cat > /usr/lib/systemd/system/docker.service <<- EOF
    [Unit]
    Description=Docker Application Container Engine
    Documentation=https://docs.docker.com
    After=network-online.target firewalld.service containerd.service
    Wants=network-online.target
    Requires=docker.socket containerd.service

    [Service]
    Type=notify
    # the default is not to use systemd for cgroups because the delegate issues still
    # exists and systemd currently does not support the cgroup feature set required
    # for containers run by docker
    ExecStart=/usr/local/bin/dockerd -H fd:// --containerd=/run/containerd/containerd.sock
    ExecReload=/bin/kill -s HUP $MAINPID
    TimeoutSec=0
    RestartSec=2
    Restart=always

    # Note that StartLimit* options were moved from "Service" to "Unit" in systemd 229.
    # Both the old, and new location are accepted by systemd 229 and up, so using the old location
    # to make them work for either version of systemd.
    StartLimitBurst=3

    # Note that StartLimitInterval was renamed to StartLimitIntervalSec in systemd 230.
    # Both the old, and new name are accepted by systemd 230 and up, so using the old name to make
    # this option work for either version of systemd.
    StartLimitInterval=60s

    # Having non-zero Limit*s causes performance problems due to accounting overhead
    # in the kernel. We recommend using cgroups to do container-local accounting.
    LimitNOFILE=infinity
    LimitNPROC=infinity
    LimitCORE=infinity

    # Comment TasksMax if your systemd version does not support it.
    # Only systemd 226 and above support this option.
    TasksMax=infinity

    # set delegate yes so that systemd does not reset the cgroups of docker containers
    Delegate=yes

    # kill only the docker process, not all processes in the cgroup
    KillMode=process
    OOMScoreAdjust=-500

    [Install]
    WantedBy=multi-user.target
	EOF

	sudo cat > /usr/lib/systemd/system/docker.socket <<- EOF
    [Unit]
    Description=Docker Socket for the API

    [Socket]
    ListenStream=/var/run/docker.sock
    SocketMode=0660
    SocketUser=root
    SocketGroup=docker

    [Install]
    WantedBy=sockets.target
	EOF

  sudo chmod +x /usr/lib/systemd/system/containerd.service
  sudo chmod +x /usr/lib/systemd/system/docker.service
  sudo chmod +x /usr/lib/systemd/system/docker.socket
  sudo systemctl daemon-reload
  sudo systemctl start containerd
  # sudo systemctl start docker
  # echo 检查安装结果
  # sudo docker -v
  # echo -e "\033[33m 注意！因为docker服务会一直尝试重启，不正确的关闭将会导致docker卡死，如遇卡死可尝试重启服务器，离线安装的docker请使用离线卸载来卸载，避免意外情况。 \033[0m"
  set +x
}

if [[ $DOCKER_INSTALL_TYPE == '0' ]]; then
  install_docker
elif [[ $DOCKER_INSTALL_TYPE == '1' ]]; then
  offline_install
elif [[ $DOCKER_INSTALL_TYPE == '2' ]]; then
  offline_uninstall
fi

# 对于arm64架构的安装，目前没有过多精力去做，写一下大体思路
# containerd的arm版本可以在这找到：https://download.docker.com/linux/ubuntu/dists/focal/pool/stable/arm64/
# arm的安装命令可使用 dpkg -i <.deb file name>
# docker的arm版本可以在这里找到：https://download.docker.com/linux/static/stable/
