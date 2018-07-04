## Objectives

This tutorial is designed to walk you through the process of using Vagrant and Virtualbox to create a local instance of Cloudbreak 2.4.1. This approach allows you start your local Cloudbreak deployer instance when you want to spin up an HDP cluster in a cloud environment without incurring costs associated with hosting your Cloudbreak deployer instance itself on the cloud.

This tutorial is an update to the original one located here: [HCC Article](https://community.hortonworks.com/articles/102704/using-a-local-instance-of-cloudbreak-with-vagrant.html)

## Prerequisites

- You should already have installed VirtualBox 5.x.  Read more here: [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- You should already have installed Vagrant 2.x.  Read more here: [Vagrant](https://www.vagrantup.com/)
- You should already have installed the vagrant-vbguest plugin.  This plugin will keep the VirtualBox Guest Additions software current as you upgrade your kernel and/or VirtualBox versions.  Read more here: [vagrant-vbguest](https://github.com/dotless-de/vagrant-vbguest)
- You should already have installed the vagrant-hostmanager plugin.  This plugin will automatically manage the /etc/hosts file on your local computer and in your virtual machines. Read more here: [vagrant-hostmanager](https://github.com/devopsgroup-io/vagrant-hostmanager)

## Scope

This tutorial was tested in the following environment:

- macOS Sierra (version 10.13.4)
- VirtualBox 5.2.6
- Vagrant 2.1.1
- vagrant-vbguest plugin 0.15.2
- vagrant-hostnamanger plugin 1.8.9
- Cloudbreak 2.4.1

## Steps

### Setup Vagrant

#### Create Vagrant project directory

Before we get started, determine where you want to keep your Vagrant project files.  Each Vagrant project should have its own directory.  I keep my Vagrant projects in my ~/Development/Vagrant directory. You should also use a helpful name for each Vagrant project directory you create. 

$ cd ~/Development/Vagrant
$ mkdir centos7-cloudbreak
$ cd centos7-cloudbreak

We will be using a CentOS 7.4 Vagrant box, so I include centos7 in the Vagrant project name to differentiate it from a CentOS 6 project.  The project is for cloudbreak, so I include that in the name.

#### Create Vagrantfile

The Vagrantfile tells Vagrant how to configure your virtual machines.  You can copy/paste my Vagrantfile below:

```

# -*- mode: ruby -*-
# vi: set ft=ruby :

# Using yaml to load external configuration files
require 'yaml'

Vagrant.configure("2") do |config|
  # Using the hostmanager vagrant plugin to update the host files
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false

  # Run install script
  config.vm.provision "shell", path: "install.sh"

  # Loading in the VM configuration information
  servers = YAML.load_file('servers.yaml')

  servers.each do |servers| 
    config.vm.define servers["name"] do |srv|
      srv.ssh.username = "vagrant"
      srv.ssh.password = "vagrant"

      srv.vm.box = servers["box"] # Speciy the name of the Vagrant box file to use
      srv.vm.hostname = servers["name"] # Set the hostname of the VM
      srv.vm.network "private_network", ip: servers["ip"], :adapater=>2 # Add a second adapater with a specified IP
      srv.vm.provision :shell, inline: "sed -i'' '/^127.0.0.1\\t#{srv.vm.hostname}\\t#{srv.vm.hostname}$/d' /etc/hosts" # Remove the extraneous first entry in /etc/hosts

      srv.vm.provider :virtualbox do |vb|
        vb.name = servers["name"] # Name of the VM in VirtualBox
        vb.cpus = servers["cpus"] # How many CPUs to allocate to the VM
        vb.memory = servers["ram"] # How much memory to allocate to the VM
      end
    end
  end
end

```

#### Create a servers.yaml file

The servers.yaml file contains the configuration information for our VMs.  Here is the content from my file:

```
---
- name: cloudbreak
  box: bento/centos-7.4
  cpus: 2
  ram: 4096
  ip: 192.168.56.100

```

***NOTE: You may need to modify the IP address to avoid conflicts with your local network.***

#### Create install.sh file

The install.sh file is a script that will run on your VM the first time it is provisioned.  The line the ```Vagrantfile``` that runs this is here:

```

  config.vm.provision "shell", path: "install.sh"

```

This allows us to automate configuration tasks that would other wise be tedious and/or repetitive.  Here is the content from my file:

```

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
yum install -y docker-engine docker-engine-selinux
systemctl start docker
systemctl enable docker

# Install Cloudbreak application
mkdir /opt/cloudbreak-deployment
cd /opt/cloudbreak-deployment
curl -Ls public-repo-1.hortonworks.com/HDP/cloudbreak/cloudbreak-deployer_2.4.1_$(uname)_x86_64.tgz | sudo tar -xz -C /bin cbd

```

This installation script performs the prerequisite package installations and configurations.  This script also automates most of the Cloudbreak installation tasks.

#### Start Virtual Machine

Once you have created the 3 files in your Vagrant project directory, you are ready to start your instance.  Creating the instance for the first time and starting it every time after that uses the same ```vagrant up``` command.

```

$ vagrant up

```

You should notice Vagrant automatically updating the packages and installing additional packages on the first start of the VM.

Once the process is complete you should have 1 vm running.  You can verify by looking at the VirtualBox UI where you should see the ```cloudbreak``` VM running.  You should see something similar to this:

![Virtualbox UI](<assets/virtualbox-ui.png>)

#### Connect to Your Virtual Machine​

You should be able to login to your VM using the ```vagrant ssh` command.  You should see something similar to the following:

```

$ vagrant ssh
[vagrant@cloudbreak ~]$

```

### Configure Cloudbreak

The installation of Cloudbreak is covered well in the docs: [Cloudbreak Install Docs](https://docs.hortonworks.com/HDPDocuments/Cloudbreak/Cloudbreak-2.4.1/content/vm-launch/index.html).  However, we've automated most of the tasks using the ```install.sh``` script.  You can skip down to the ```Install Cloudbreak on Your Own VM``` section, step 3.

We need to be root for this, so we'll use ```sudo```.

```
sudo -i
```

#### Create Profile file

Now you need to setup the Profile file.  This file contains environment variables that determines how Cloudbreak runs.  Edit ```Profile``` using your editor of choice.

You need to include at least 4 settings.

```

export UAA_DEFAULT_SECRET='[SECRET]'
export UAA_DEFAULT_USER_EMAIL='<myemail>'
export UAA_DEFAULT_USER_PW='<mypassword>'
export PUBLIC_IP=192.168.56.100

```

You should set the ```UAA_DEFAULT_USER_EMAIL``` variable to the email address you want to use.  This is the account you will use to login to Cloudbreak.  You should set the ```UAA_DEFAULT_USER_PW``` variable to the password you want to use.  This is the password you will use to login to Cloudbreak.  You may need to change the value of ```PUBLIC_IP``` to avoid conflicts on your network.

#### Verify Cloudbreak Version

You should check the version of Cloudbreak to make sure the correct version is installed.

```

[root@cloudbreak cloudbreak-deployment]# cbd --version

```

You should see something similar to this:

```

[root@cloudbreak cloudbreak-deployment]# cbd --version
Cloudbreak Deployer: 2.4.1

```

***NOTE: Notice that we are installing version 2.4.1 which is the latest GA version as of May 2018***


#### Initialize Cloudbreak Configuration

Now that you have a profile, you can initialize your Cloudbreak configuration files.  First you need to run the ```cbd generate``` command.  You should see something similar to the following:

```

[root@cloudbreak cloudbreak-deployment]# cbd generate
* Dependency required, installing sed latest ...
* Dependency required, installing jq latest ...
* Dependency required, installing docker-compose 1.13.0 ...
* Dependency required, installing aws latest ...
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
ff3a5c916c92: Pulling fs layer
ff3a5c916c92: Verifying Checksum
ff3a5c916c92: Download complete
ff3a5c916c92: Pull complete
Digest: sha256:7df6db5aa61ae9480f52f0b3a06a140ab98d427f86d8d5de0bedab9b8df6b1c0
Status: Downloaded newer image for alpine:latest
Generating Cloudbreak client certificate and private key in /opt/cloudbreak-deployment/certs with 192.168.56.100 into /opt/cloudbreak-deployment/certs/traefik.
generating docker-compose.yml
generating uaa.yml

```

The second step is to pull down the the Docker images used by Cloudbreak using the ```cbd pull``` command.  You should see something similar to the following:

```

[root@cloudbreak cloudbreak-deployment]# cbd pull
Pulling haveged (hortonworks/haveged:1.1.0)...
1.1.0: Pulling from hortonworks/haveged
Digest: sha256:31c6151ebd88ac65322969c7a71969c0d95d98a9eafd4eaab56e11c62c48c42b
Status: Downloaded newer image for hortonworks/haveged:1.1.0
Pulling uluwatu (hortonworks/hdc-web:2.4.1)...
2.4.1: Pulling from hortonworks/hdc-web
...

```

### Start Cloudbreak

Once you have generated the configuraiton files and pulled down the Docker images, you can start Cloudbreak.  You start Cloudbreak using the ```cbd start``` command.  You should see something similar to the following:

```

[root@cloudbreak cloudbreak-deployment]# cbd start
generating docker-compose.yml
generating uaa.yml
Pulling haveged (hortonworks/haveged:1.1.0)...
1.1.0: Pulling from hortonworks/haveged
ca26f34d4b27: Pull complete
bf22b160fa79: Pull complete
d30591ea011f: Pull complete
22615e74c8e4: Pull complete
ceb5854e0233: Pull complete
Digest: sha256:09f8cf4f89b59fe2b391747181469965ad27cd751dad0efa0ad1c89450455626
Status: Downloaded newer image for hortonworks/haveged:1.1.0
Pulling uluwatu (hortonworks/cloudbreak-web:1.14.0)...
1.14.0: Pulling from hortonworks/cloudbreak-web
16e32a1a6529: Pull complete
8e153fce9343: Pull complete
6af1e6403bfe: Pull complete
075e3418c7e0: Pull complete
9d8191b4be57: Pull complete
38e38dfe826c: Pull complete
d5d08e4bc6be: Pull complete
955b472e3e42: Pull complete
02e1b573b380: Pull complete
Digest: sha256:06ceb74789aa8a78b9dfe92872c45e045d7638cdc274ed9b0cdf00b74d118fa2
...

Creating cbreak_periscope_1
Creating cbreak_logsink_1
Creating cbreak_identity_1
Creating cbreak_uluwatu_1
Creating cbreak_haveged_1
Creating cbreak_consul_1
Creating cbreak_mail_1
Creating cbreak_pcdb_1
Creating cbreak_uaadb_1
Creating cbreak_cbdb_1
Creating cbreak_sultans_1
Creating cbreak_registrator_1
Creating cbreak_logspout_1
Creating cbreak_cloudbreak_1
Creating cbreak_traefik_1
Uluwatu (Cloudbreak UI) url:
  https://192.168.56.100
login email:
  myoung@hortonworks.com
password:
  ****
creating config file for hdc cli: /root/.hdc/config
```

The start command will output the IP address and the username to login which is based on what we setup in the Profile.

#### Check Cloudbreak Logs

You can always look at the Cloudbreak logs in /opt/cloudbrea-deployer/cbreak.log.  You can also use the ```cbd logs cloudbreak``` command to view logs in real time.  Cloudbreak is ready to use when you see a message similar to ```Started CloudbreakApplication in 64.156 seconds (JVM running for 72.52)```.

#### Login to Cloudbreak

Cloudbreak should now be running.  We can login to the UI using the IP address specified in the Profile.  In our case that is ```https://192.168.56.100```.  Notice Cloudbreak uses ```https```.

Your browser may display a warning similar to the following:

![Browswer Warning](<assets/browser-warning.png>)

This is because of the self-signed certificate used by Cloudbreak.  You should accept the certificate and trust the site.  Then you should see a login screen similar to the following:

![Cloudbreak Login](<assets/cloudbreak-login.png>)

At this point you should be able the Cloudbreak UI screen where you can manage your credentials, blueprints, etc.  This tutorial doesn't cover setting up credentials or deploying a cluster.  Before you can deploy a cluster you need to setup ```credentials```.  See this link for setting up your crendentials:

[Managing Cloudbreak AWS Credentials](https://docs.hortonworks.com/HDPDocuments/Cloudbreak/Cloudbreak-2.4.1/content/cb-credentials/index.html)


### Stopping Cloudbreak

When you are ready to shutdown Cloudbeak, the process is simple.  First you need to stop the Cloudbreak deployer:

```
cbd kill
```

You should see something similar to this:

```
[root@cloudbreak cloudbreak-deployment]# cbd kill
Stopping cbreak_traefik_1 ... done
Stopping cbreak_cloudbreak_1 ... done
Stopping cbreak_logspout_1 ... done
Stopping cbreak_registrator_1 ... done
Stopping cbreak_sultans_1 ... done
Stopping cbreak_uaadb_1 ... done
Stopping cbreak_cbdb_1 ... done
Stopping cbreak_pcdb_1 ... done
Stopping cbreak_mail_1 ... done
Stopping cbreak_haveged_1 ... done
Stopping cbreak_consul_1 ... done
Stopping cbreak_uluwatu_1 ... done
Stopping cbreak_identity_1 ... done
Stopping cbreak_logsink_1 ... done
Stopping cbreak_periscope_1 ... done
Going to remove cbreak_traefik_1, cbreak_cloudbreak_1, cbreak_logspout_1, cbreak_registrator_1, cbreak_sultans_1, cbreak_uaadb_1, cbreak_cbdb_1, cbreak_pcdb_1, cbreak_mail_1, cbreak_haveged_1, cbreak_consul_1, cbreak_uluwatu_1, cbreak_identity_1, cbreak_logsink_1, cbreak_periscope_1
Removing cbreak_traefik_1 ... done
Removing cbreak_cloudbreak_1 ... done
Removing cbreak_logspout_1 ... done
Removing cbreak_registrator_1 ... done
Removing cbreak_sultans_1 ... done
Removing cbreak_uaadb_1 ... done
Removing cbreak_cbdb_1 ... done
Removing cbreak_pcdb_1 ... done
Removing cbreak_mail_1 ... done
Removing cbreak_haveged_1 ... done
Removing cbreak_consul_1 ... done
Removing cbreak_uluwatu_1 ... done
Removing cbreak_identity_1 ... done
Removing cbreak_logsink_1 ... done
Removing cbreak_periscope_1 ... done
[root@cloudbreak cloudbreak-deployment]#
```

Now exit the Vagrant box:

```
[root@cloudbreak cloudbreak-deployment]# exit
logout
[vagrant@cloudbreak ~]$ exit
logout
Connection to 127.0.0.1 closed.
```

Now we can shutdown the Vagrant box

```
$ vagrant halt
==> cloudbreak: Attempting graceful shutdown of VM...
```


### Starting Cloudbreak

To startup Cloudbreak, the process is the opposite of stopping it.  First you need to start the Vagrant box:

```
vagrant up
```

Once the Vagrant box is up, you need to ssh in to the box:

```
vagrant ssh
```

You need to be root:

```
sudo -i
```

Now start Cloudbreak:

```
cd /opt/cloudbreak-deployer
cbd start
```

You should see something similar to this:

```
[root@cloudbreak cloudbreak-deployment]# cbd start
generating docker-compose.yml
generating uaa.yml
Creating cbreak_consul_1
Creating cbreak_periscope_1
Creating cbreak_sultans_1
Creating cbreak_uluwatu_1
Creating cbreak_identity_1
Creating cbreak_uaadb_1
Creating cbreak_pcdb_1
Creating cbreak_mail_1
Creating cbreak_haveged_1
Creating cbreak_logsink_1
Creating cbreak_cbdb_1
Creating cbreak_logspout_1
Creating cbreak_registrator_1
Creating cbreak_cloudbreak_1
Creating cbreak_traefik_1
Uluwatu (Cloudbreak UI) url:
  https://192.168.56.100
login email:
  myoung@hortonworks.com
password:
  ****
creating config file for hdc cli: /root/.hdc/config
[root@cloudbreak cloudbreak-deployment]#
```

It takes a minute or two for the Cloudbreak application to fully start up.  Now you can login to the Cloudbreak UI.

### Review

If you have successfully followed along with this tutorial, you should now have a Vagrant box you can spin up via ```vagrant up```, startup Cloudbreak via ```cbd start``` and then create your clusters on the cloud.
