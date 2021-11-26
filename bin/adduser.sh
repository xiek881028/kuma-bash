#!/bin/bash
# 注意！该脚本仅在centos系统做过测试，其他系统未必适用
set -e

echo -e "\033[47;30m 该脚本用于部署常用的创建用户以及赋予sudo权限 \033[0m"
echo -e "\033[47;30m 在询问阶段选项并未真正执行，可以随时按^C退出脚本 \033[0m"
echo -e "\033[33m 注意！该脚本仅在centos系统做过测试，其他系统未必适用 \033[0m"
echo

DEFAULT_USER_NAME='www'
DEFAULT_INSTALL_COMP='N'
DEFAULT_HAS_SUDO='N'
DEFAULT_SET_PWD='N'

read -p "是否创建用户[Y/N]: (N)" ADD_USER
if [[ -z $ADD_USER ]]; then
  ADD_USER='N'
fi

# CheckUser
checkUser() {
  read -p "请输入用户名: (www)" USER_NAME
  if [[ -z $USER_NAME ]]; then
    USER_NAME='www'
  fi
  if id -u ${USER_NAME} >/dev/null 2>&1 ; then
    echo -e "\033[41;37m 危险操作，会清除当前系统用户及其home目录下所有文件 \033[0m"
    read -p "$USER_NAME 已存在，是否删除当前用户重新创建[Y/N]: (N)" READD
    if [[ -z $READD ]]; then
      READD='N'
    fi
    if [[ $READD == 'Y' || $READD == 'y' ]]; then
      return
    else
      checkUser
    fi
  fi
}

if [[ $ADD_USER == 'Y' || $ADD_USER == 'y' ]]; then
  checkUser
  read -p "是否在新建时设置用户密码[Y/N]: (N)" SET_PWD
  read -p "用户 $USER_NAME 是否拥有sudo权限[Y/N]: (N)" HAS_SUDO
  if [[ -z $HAS_SUDO ]]; then
    HAS_SUDO=$DEFAULT_HAS_SUDO
  fi
  if [[ $HAS_SUDO == 'Y' || $HAS_SUDO == 'y' ]]; then
    # 安装代码补全(sudo)
    read -p "是否安装sudo代码补全[Y/N]: (N)" INSTALL_COMP
    if [[ -z $INSTALL_COMP ]]; then
      INSTALL_COMP=$DEFAULT_INSTALL_COMP
    fi
  fi
fi

# Install
install() {
  if [[ $ADD_USER != 'Y' && $ADD_USER != 'y' ]]; then
    return
  fi
  set -x
  if [[ $READD == 'Y' || $READD == 'y' ]]; then
    # 结束用户所有进程
    sudo pkill -u $USER_NAME
    # 删除用户及其home目录
    sudo userdel -r $USER_NAME
    # 删除sudo权限
    sudo rm -rf /etc/sudoers.d/$USER_NAME
  fi
  sudo useradd $USER_NAME
  if [[ $SET_PWD == 'Y' || $SET_PWD == 'y' ]]; then
    sudo passwd $USER_NAME
  fi
  if [[ $HAS_SUDO == 'Y' || $HAS_SUDO == 'y' ]]; then
    sudo echo "$USER_NAME ALL=(ALL) ALL" > /etc/sudoers.d/$USER_NAME
    sudo chmod 440 /etc/sudoers.d/$USER_NAME
  fi
  if [[ $INSTALL_COMP == 'Y' || $INSTALL_COMP == 'y' ]]; then
    sudo yum -y install bash-completion
    sudo complete -cf sudo
  fi
  set +x
}

install
