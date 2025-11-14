#!/bin/bash

time=$(date +'%Y%m%d')
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
yum -y install ncurses ncurses-devel ncurses-libs


echo "i.下载依赖环境"
yum -y install wget
wget -i -c http://dev.mysql.com/get/mysql57-community-release-el7-10.noarch.rpm
rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022

echo "2.开始安装"
yum -y install mysql57-community-release-el7-10.noarch.rpm
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
echo "default-character-set=utf8" >> /etc/my.cnf
echo "socket=${mysqlDataDir}/mysql57.sock" >> /etc/my.cnf
echo "" >> /etc/my.cnf
echo "[mysqld]" >> /etc/my.cnf
echo "server-id=127001" >> /etc/my.cnf
echo "datadir=${mysqlDataDir}" >> /etc/my.cnf
echo "socket=${mysqlDataDir}/mysql57.sock" >> /etc/my.cnf
echo "character-set-server=utf8" >> /etc/my.cnf
echo "collation-server=utf8_general_ci" >> /etc/my.cnf
echo "" >> /etc/my.cnf
echo "slow_query_log=1" >> /etc/my.cnf
echo "long_query_time=2" >> /etc/my.cnf
echo "slow_query_log_file=${mysqlDataDir}/mysql57-slow.log" >> /etc/my.cnf
echo "" >> /etc/my.cnf
echo "log_error=${mysqlDataDir}/mysql57-error.log" >> /etc/my.cnf
echo "log_bin=${mysqlDataDir}/mysql57-bin.log" >> /etc/my.cnf
cat /etc/my.cnf

echo "5.启动MySQL"
systemctl start  mysqld.service
systemctl status mysqld.service
active=$(systemctl status mysqld.service | grep "active (running)" | wc -l)

if [ $active -le 0 ]
then
  echo "5.1 启动失败，请检查日志"
  exit;
fi

echo "6.重置密码"
str=$(grep "password is generated for root@localhost:" /var/log/mysqld.log)
localPWD=${str##*"root@localhost: "}
mysql --connect-expired-password -uroot -p${localPWD} -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$mysqlPwd'"
mysql --connect-expired-password -uroot -P${localPWD} -e "flush privileges"

#重启MySQL查看配置结果
systemctl restart mysqld
systemctl status mysqld.service

mysql --connect-expired-password -uroot -p${mysqlPwd} -e "select version()"
echo "7.安装完成"
