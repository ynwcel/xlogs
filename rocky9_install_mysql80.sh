#!/bin/bash

time=$(date +'%Y%m%d')
logfile="./install_mysql80.log.${time}"
read -p "set mysql password:" mysqlPwd
read -p "set mysql datadir:" mysqlDataDir

if [ -z "${mysqlPwd}" -o -z "${mysqlDataDir}" ]
then
   echo "pwd set empty or datadir set empty"
   exit;
fi;
oldmysql=$(rpm -qa | grep mysql| wc -l)
mariadb=$(rpm -qa | grep mariadb |wc -l)

if [ ${oldmysql} -gt 0 -o  ${mariadb} -gt 0 ]
then
  echo "exists old mysql or exists old mariadb"
  exit;
fi;

read -p "update yum packages[y/n]:" updateYum
if [ ${updateYum} == "Y" -o ${updateYum} == "y" ]
then
   yum -y upgrade
fi;
setenforce 0
yum -y install ncurses ncurses-devel ncurses-libs

echo "1.下载依赖环境"
yum -y install wget
wget -i -c https://repo.mysql.com/mysql80-community-release-el9-5.noarch.rpm

echo "2.开始安装"
yum -y install mysql80-community-release-el9-5.noarch.rpm
yum -y install mysql-community-client
yum -y install mysql-community-server

echo "3.创建数据目录及环境"
mkdir -p "${mysqlDataDir}"
chown -R mysql:mysql ${mysqlDataDir}

echo "4.创建配置文件"
exists=$(ls /etc/ | grep my.cnf | wc -l)
if [ $exists -gt 0 ]
then
   bakfile="/etc/my.cnf.bak.${time}"
   mv /etc/my.cnf ${bakfile}
fi
cat /dev/null > /etc/my.cnf
echo "[client]" > /etc/my.cnf
echo "default-character-set=utf8mb4" >> /etc/my.cnf
echo "" >> /etc/my.cnf
echo "[mysqld]" >> /etc/my.cnf
echo "server-id=127001" >> /etc/my.cnf
echo "datadir=${mysqlDataDir}" >> /etc/my.cnf
echo "socket=${mysqlDataDir}/mysql80.sock" >> /etc/my.cnf
echo "character-set-server=utf8mb4" >> /etc/my.cnf
echo "collation-server=utf8mb4_unicode_ci" >> /etc/my.cnf
cat /etc/my.cnf

echo "5.初始化mysql并获取初始密码"
mysqld --initialize --user=mysql > ${logfile} 2>&1
localpwd=$(cat ${logfile} | grep 'root@localhost' | awk -F 'root@localhost:' '{print($2)}' | sed -e 's/\s//g')


echo "6.启动MySQL"
systemctl start  mysqld.service
systemctl status mysqld.service
active=$(systemctl status mysqld.service | grep "active (running)" | wc -l)

if [ $active -le 0 ]
then
  echo "6.1 启动失败，请检查日志"
  exit;
fi

echo "7.重置密码"
mysql --connect-expired-password -h127.0.0.1 -uroot -p${localpwd} -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysqlPwd'"
mysql --connect-expired-password -h127.0.0.1 -uroot -P${localpwd} -e "flush privileges"

echo "8.重启服务"
systemctl restart mysqld
systemctl status mysqld.service

echo "9.测试连接"
mysql --connect-expired-password -h127.0.0.1 -uroot -p${mysqlPwd} -e "select version()"

echo "10.安装完成"
