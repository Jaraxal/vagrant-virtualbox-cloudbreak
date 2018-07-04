#!/bin/bash

# Install prerequisites
sudo yum -y update
sudo yum -y install net-tools ntp wget lsof unzip tar iptables-services

# Enable NTP
sudo systemctl enable ntpd && sudo systemctl start ntpd

# Disable Firewall
sudo systemctl disable firewalld && sudo systemctl stop firewalld
sudo iptables --flush INPUT && sudo iptables --flush FORWARD && sudo service iptables save

# Disable SELINUX
sudo sed -i --follow-symlinks 's/^SELINUX=.*/SELINUX=disabled/g' /etc/sysconfig/selinux

# Create Docker repo
cat > /etc/yum.repos.d/docker.repo <<EOF
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF

# Install Docker, enable and start service
yum install -y docker-engine-1.9.1 docker-engine-selinux-1.9.1
systemctl start docker
systemctl enable docker

# Install Cloudbreak application
mkdir /opt/cloudbreak-deployment
cd /opt/cloudbreak-deployment
curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.4.1_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd

