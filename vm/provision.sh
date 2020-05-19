#!/bin/bash

setenforce 0
sed -i 's/^SELINUX=.*$/SELINUX=disabled/' /etc/selinux/config
yum install -y epel-release
yum install -y centos-release-scl
yum install -y https://rpms.remirepo.net/enterprise/remi-release-7.rpm

cat > /etc/yum.repos.d/Tuleap.repo << EOF
[Tuleap]
name=Tuleap
baseurl=https://ci.tuleap.net/yum/tuleap/rhel/7/dev/x86_64/
enabled=1
gpgcheck=1
gpgkey=https://ci.tuleap.net/yum/tuleap/gpg.key
EOF

yum install -y \
  rh-mysql57-mysql-server \
  tuleap \
  tuleap-plugin-agiledashboard \
  tuleap-plugin-graphontrackers \
  tuleap-theme-burningparrot \
  tuleap-theme-flamingparrot \
  tuleap-plugin-git \
  tuleap-plugin-pullrequest

# Add 'sql-mode' parameter after [mysqld]
sed -i '20 a sql-mode=NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION' /etc/opt/rh/rh-mysql57/my.cnf.d/rh-mysql57-mysql-server.cnf

# Activate mysql on boot
systemctl enable rh-mysql57-mysqld

# Start it
systemctl start rh-mysql57-mysqld

# Set a password
scl enable rh-mysql57 "mysqladmin -u root password 'ROOT'"

/usr/share/tuleap/tools/setup.el7.sh \
  --configure --assumeyes \
  --server-name=tuleap.dev.jkldsa.com \
  --mysql-server=localhost \
  --mysql-password=ROOT


echo "Provision done. Admin passwords are:"
cat /root/.tuleap_passwd
echo "Please reboot."
