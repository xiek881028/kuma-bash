#!/bin/bash
set -e

echo -e "\033[47;30m 该脚本用于部署常用的服务自启动配置 \033[0m"
echo -e "\033[47;30m 配置只列出常用选项，如需高度定制请自行编写service文件 \033[0m"
echo -e "\033[47;30m 在询问阶段选项并未真正执行，可以随时按^C退出脚本 \033[0m"
echo -e "\033[33m 注意！该脚本仅在centos系统做过测试，其他系统未必适用 \033[0m"
echo

read -p "是否创建系统服务[Y/N]: (N)" ADD_SERVICE
if [[ -z $ADD_SERVICE ]]; then
  ADD_SERVICE='N'
fi

checkServiceName() {
  read -p "服务名称: " SERVICE_NAME
  if [[ -f /usr/lib/systemd/system/$SERVICE_NAME.service ]]; then
    read -p "服务 ${SERVICE_NAME} 已存在，是否覆写[Y/N]: (N)" SERVICE_REWRITE
    if [[ -z $SERVICE_REWRITE ]]; then
      SERVICE_REWRITE='N'
    fi
    if [[ $SERVICE_REWRITE == 'Y' || $SERVICE_REWRITE == 'y' ]]; then
      return
    else
      checkServiceName
    fi
  fi
}

askUser() {
  if [[ $ADD_SERVICE == 'Y' || $ADD_SERVICE == 'y' ]]; then
    echo -e "\033[33m 服务名称即文件名，需要全局唯一 \033[0m"
    echo -e "\033[33m 脚本涉及的路径为避免失败请使用绝对路径 \033[0m"
    checkServiceName
    read -p "服务描述: " SERVICE_DES
    read -p "环境变量(key1=value1 key2=value2): " SERVICE_ENV
    read -p "启动脚本: " SERVICE_START
    read -p "重启脚本: " SERVICE_RELOAD
    read -p "停止脚本: " SERVICE_STOP
    read -p "运行用户: (www)" SERVICE_USER
    if [[ -z $SERVICE_USER ]]; then
      SERVICE_USER="www"
    fi
    read -p "运行用户组: (www)" SERVICE_GROUP
    if [[ -z $SERVICE_GROUP ]]; then
      SERVICE_GROUP="www"
    fi
    __TEMP="
[Unit]
Description=$SERVICE_DES
After=syslog.target network.target

[Service]
Environment=\"$SERVICE_ENV\"
ExecStart=$SERVICE_START
ExecReload=$SERVICE_RELOAD
ExecStop=$SERVICE_STOP
RemainAfterExit=yes
User=$SERVICE_USER
Group=$SERVICE_GROUP

[Install]
WantedBy=multi-user.target"

    echo "以下内容将写入 /usr/lib/systemd/system/$SERVICE_NAME.service"
    echo -e "$__TEMP"
    echo
    read -p "这样可以吗[Y/N]? (Y)" CONFIRM
    if [[ -z $CONFIRM ]]; then
      CONFIRM="Y"
    fi
    if [[ $CONFIRM != 'Y' && $CONFIRM != 'y' ]]; then
      askUser
    else
      selfStarting
    fi
  fi
}

# 设置自启动
selfStarting() {
  read -p "是否设置开机自启动[Y/N]: (N)" SELF_START
  if [[ -z $SELF_START ]]; then
    SELF_START="N"
  fi
  read -p "是否立即启动服务[Y/N]: (N)" START_NOW
  if [[ -z $START_NOW ]]; then
    START_NOW="N"
  fi
}

askUser

# Install
install() {
  if [[ $ADD_SERVICE != 'Y' && $ADD_SERVICE != 'y' ]]; then
    return
  fi
  set -x
  if [[ $SERVICE_REWRITE == 'Y' || $SERVICE_REWRITE == 'y' ]]; then
    # 停止服务
    sudo systemctl kill $SERVICE_NAME.service || true
    # 删除服务
    sudo rm -rf /usr/lib/systemd/system/$SERVICE_NAME.service
  fi
  echo "$__TEMP" > /usr/lib/systemd/system/$SERVICE_NAME.service
  sudo chown root:root /usr/lib/systemd/system/$SERVICE_NAME.service
  sudo chmod 644 /usr/lib/systemd/system/$SERVICE_NAME.service
  if [[ $SELF_START == 'Y' || $SELF_START == 'y' ]]; then
    sudo systemctl enable $SELF_START.service
  fi
  if [[ $START_NOW == 'Y' || $START_NOW == 'y' ]]; then
    sudo systemctl start $SERVICE_NAME.service
    STATUS=sudo systemctl status $SERVICE_NAME.service -n50
    echo $STATUS
  fi
  echo
  echo "启动服务: systemctl start $SERVICE_NAME.service"
  echo "停止服务: systemctl stop $SERVICE_NAME.service"
  echo "重启服务: systemctl restart $SERVICE_NAME.service"
  echo "查看服务状态: systemctl status $SERVICE_NAME.service"
  echo "杀死服务: systemctl kill $SERVICE_NAME.service"
  echo "重新加载服务配置: systemctl reload $SERVICE_NAME.service"
  echo "重新加载所有修改的服务配置: sudo systemctl daemon-reload"
  set +x
}

install
