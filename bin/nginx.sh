#!/bin/bash
set -e

# Options
NGINX_INSTALLATION_PATH="/usr/local/lib/nginx"

if [[ -z $NGINX ]]; then
  typeset -u NGINX
  read -p "安装Nginx[Y/N]: (N) " NGINX
  if [[ -z $NGINX ]]; then
    NGINX="N"
  fi
fi

# 环境检查
checkPkg() {
  APPLICATIONS=(
    gcc-c++
    gd-devel
    GeoIP-devel
    libxslt-devel
    openssl-devel
    pcre-devel
    zlib-devel
  )
  LACK=()
  for((i = 0, len = ${#APPLICATIONS[*]}; i < len; i++))
  do
    if ! rpm -q ${APPLICATIONS[$i]}>/dev/null; then
      LACK+=(${APPLICATIONS[$i]})
    fi
  done
  if [[ ${#LACK[*]} > 0 ]]; then
    echo "缺少必要插件包 ${LACK[@]}"
    read -p "是否自动安装缺失包[Y/N]: (N) " AUTO_LACK
    if [[ -z $AUTO_LACK || ($AUTO_LACK != 'Y' && $AUTO_LACK != 'y') ]]; then
      exit
    fi
  fi
}

if [[ $NGINX == 'Y' ]]; then
  checkPkg
  if [[ -d $NGINX_INSTALLATION_PATH ]]; then
    typeset -u NGINX
    if [[ -z $NGINX_OVERWRITE ]]; then
      read -p "Nginx已安装, 是否覆盖[Y/N]: (N) " NGINX
      if [[ -z $NGINX ]]; then
        NGINX=N
      fi
    else
      NGINX=$NGINX_OVERWRITE
    fi
  fi
  if [[ -z $NGINX_VERSION ]]; then
    read -p "Nginx版本号: (1.20.2) " NGINX_VERSION
    if [[ -z $NGINX_VERSION ]]; then
      NGINX_VERSION="1.20.2"
    fi
  fi
  if [[ -z $NGINX_AUTO_START ]]; then
    read -p "开机启动[Y/N]: (N) " NGINX_AUTO_START
    if [[ -z $NGINX_AUTO_START ]]; then
      NGINX_AUTO_START="N"
    fi
  fi
fi

# Install
install_nginx() {
  if [[ $NGINX != 'Y' || $NGINX == 'y' ]]; then
    return
  fi
  if [[ $AUTO_LACK == 'Y' || $AUTO_LACK == 'y' ]]; then
    for((i = 0, len = ${#LACK[*]}; i < len; i++))
    do
      yum -y install ${LACK[$i]}
    done
  fi

  CONFIGURE_OPTIONS="
                      --prefix=$NGINX_INSTALLATION_PATH
                      --with-http_stub_status_module
                      --with-http_ssl_module
                      --with-http_realip_module
                      --with-http_addition_module
                      --with-http_sub_module
                      --with-http_dav_module
                      --with-http_flv_module
                      --with-http_mp4_module
                      --with-http_gunzip_module
                      --with-http_gzip_static_module
                      --with-http_random_index_module
                      --with-http_secure_link_module
                      --with-http_stub_status_module
                      --with-http_auth_request_module
                      --with-http_xslt_module=dynamic
                      --with-http_image_filter_module=dynamic
                      --with-http_geoip_module=dynamic
                      --with-threads
                      --with-stream
                      --with-stream_ssl_module
                      --with-stream_ssl_preread_module
                      --with-stream_realip_module
                      --with-stream_geoip_module=dynamic
                      --with-http_slice_module
                      --with-mail
                      --with-mail_ssl_module
                      --with-compat
                      --with-file-aio
                      --with-http_v2_module
                    "

  set -x
  if [[ -d $NGINX_INSTALLATION_PATH ]]; then
    mv $NGINX_INSTALLATION_PATH "$NGINX_INSTALLATION_PATH.`date +%Y%m%d%H%M%S`"
  fi
  # if [[ ! -f "nginx-$NGINX_VERSION.tar.gz" ]]; then
  #   curl --compressed -fLO "http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"
  # else
  if [[ -f "nginx-$NGINX_VERSION.tar.gz" ]]; then
    rm -rf "nginx-$NGINX_VERSION"
  else
    wget -c "http://nginx.org/download/nginx-$NGINX_VERSION.tar.gz"
  fi
  tar zxvf "nginx-$NGINX_VERSION.tar.gz"
  cd "nginx-$NGINX_VERSION"
  ./configure $CONFIGURE_OPTIONS
  make
  make install
  cd ..
  ln -s $NGINX_INSTALLATION_PATH/sbin/nginx /usr/local/sbin/nginx && true
  # 创建conf.d
  mkdir -p $NGINX_INSTALLATION_PATH/conf.d
  # 放入示例
	sudo cat > $NGINX_INSTALLATION_PATH/conf.d/nginx.conf.sample <<- EOF
    # server {
    #         listen          80;

    #         server_name     域名;
    #         root            目录地址;
    #         alias           虚拟目录地址;
    #         index           index.html;

    #         location ~ /(api)/ {
    #                proxy_pass          代理地址;
    #                proxy_set_header    Host               $http_host;
    #                proxy_set_header    X-Real-IP          $remote_addr;
    #                proxy_set_header    X-Forwarded-For    $proxy_add_x_forwarded_for;
    #         }
    # }
	EOF
  # 重写nginx配置
	sudo cat > $NGINX_INSTALLATION_PATH/conf/nginx.conf <<- EOF
    #user  nobody;
    worker_processes  1;

    #error_log   logs/error.log;
    #error_log   logs/error.log  notice;
    #error_log   logs/error.log  info;

    #pid         logs/nginx.pid;

    #load_module   /usr/local/nginx/modules/ngx_http_passenger_module.so;


    events {
      use                 epoll;
      worker_connections  1024;
    }


    http {
      include       mime.types;
      default_type  application/octet-stream;

      #log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
      #                  '$status $body_bytes_sent "$http_referer" '
      #                  '"$http_user_agent" "$http_x_forwarded_for"';

      #access_log  logs/access.log  main;

      sendfile    on;
      #tcp_nopush  on;

      #keepalive_timeout   75s;

      #gzip          on;
      #gzip_disable  'MSIE [1-6]\.(?!.*SV1)';
      #gzip_types    *;

      #client_max_body_size  1m;

      include   ../*.conf;
      include   ../conf.d/*.conf;
    }
	EOF
  if [[ $NGINX_AUTO_START != 'Y' || $NGINX_AUTO_START == 'y' ]]; then
		# 写启动服务
		sudo cat > /usr/lib/systemd/system/nginx.service <<- EOF
			[Unit]
			Description=Nginx service
			After=network.target

			[Service]
			Type=forking
			ExecStart=/usr/local/sbin/nginx

			[Install]
			WantedBy=multi-user.target
		EOF
		systemctl enable --now nginx
  fi
  # 清理现场
  rm -rf nginx-$NGINX_VERSION.tar.gz nginx-$NGINX_VERSION
  set +x
}

install_nginx
