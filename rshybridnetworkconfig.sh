#!/bin/bash
# rshybridnetworkconfig.sh - Version 1.4
# Rackspace RackConnect Network Configuration Script
# For use with the RackConnect F5 or ASA solution
# Created by Zachary Deptawa (zdeptawa@rackspace.com)
# 
# This script is intended for use on the following operating systems:
# RHEL, CentOS, Fedora, Ubuntu, Debian
#
# The purpose of this script is to disable direct public access to the Cloud Server and properly
# configure eth1 (the service network) to communicate through a dedicated network device utilizing 
# RackConnect (F5 BIG-IP device or ASA 5510 Sec+ or greater firewall). You will need to place a 
# 'gateways.txt' file in the current working directory with a list of /19 networks and the proper 
# gateway IP for each of those netblocks. Here is an example of the proper contents of a 
# 'gateways.txt' file:
#
# 10.176.32.0/19  10.176.60.255
# 10.176.64.0/19  10.176.90.255
# 10.176.96.0/19  10.176.120.255
# 10.176.128.0/19 10.176.150.255
#
# This script should only be used as a template and can be expanded upon for further automation.
# Logging has also been set to log to 'rshybridnetworkconfig[ddmmyy].log' in the current working 
# directory.
#
# ###### UPDATES ######
# Version 1.1 Updates
# -Support for Ubuntu and Debian
# -Log file name includes date
# -Cleaned up output
# -Added begin and end timestamps
#
#
# Version 1.2 Updates
# -Checking for both eth0 and eth1 gateways
# -Missing exits for eth1 checking (fixed)
# -Forced commenting of eth0 gateway for Debian and Ubuntu
# -dos2unix (or fromdos for Debian/Ubuntu) for gateways.txt 
#  to fix ill formatted gateways.txt files
#
# Version 1.3 Updates
# -Network is checked against IP and netmask(no longer hard coded /19)
# -Added error checks to gateways.txt section
#
# Version 1.4 Updates
# -Updated comments to reflect 'RackConnect'
# #####################

echo "########## B E G I N ########## - "`date`" - ########## B E G I N ##########" >> rshybridnetworkconfig$(date +%d%m%y).log
echo "Rackspace Hybrid Configuration Script running..." > rshybridnetworkconfig$(date +%d%m%y).log
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Determine OS type ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ `lsb_release -a |grep -i ubuntu |wc -l` -ge 1 ]]; then
        os=ubuntu
elif [[ `cat /etc/debian_version |wc -l` -ge 1 ]]; then
        os=debian
else
        os=redhat
fi
echo "OS type is set to: "$os >> rshybridnetworkconfig$(date +%d%m%y).log
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Download ipcalc ***" >> rshybridnetworkconfig$(date +%d%m%y).log
wget http://c1946142.cdn.cloudfiles.rackspacecloud.com/ipcalc
if [ -f ipcalc ]; then
	chmod +x ipcalc
	echo "ipcalc downloaded and modified for execution." >> rshybridnetworkconfig$(date +%d%m%y).log
else
	echo "ipcalc download failed! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
	exit
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Ensure perl is installed ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [ -f /usr/bin/perl ]; then
	echo "/usr/bin/perl present." >> rshybridnetworkconfig$(date +%d%m%y).log
else
	echo "/usr/bin/perl not found. Installing." >> rshybridnetworkconfig$(date +%d%m%y).log
	if [[ $os = ubuntu ]]; then
		apt-get -f install perl
	elif [[ $os = debian ]]; then
		apt-get -f install perl
	else 
		yum install perl -y
	fi
	if [ -f /usr/bin/perl ]; then	
		echo "/usr/bin/perl installed." >> rshybridnetworkconfig$(date +%d%m%y).log
	else
		echo "/usr/bin/perl installation failed! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
		exit
	fi
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Get private IP (eth1) ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ $os = ubuntu ]]; then
        if [ -f /etc/network/interfaces ]; then
                my_ip=`cat /etc/network/interfaces |grep address |awk '{getline;print$2}'`
                echo $my_ip >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "/etc/network/interfaces does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                exit
        fi
elif [[ $os = debian ]]; then
        if [ -f /etc/network/interfaces ]; then
                my_ip=`cat /etc/network/interfaces |grep address |awk '{getline;print$2}'`
                echo $my_ip >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "/etc/network/interfaces does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                exit
        fi
else
        if [ -f /etc/sysconfig/network-scripts/ifcfg-eth1 ]; then
                my_ip=`cat /etc/sysconfig/network-scripts/ifcfg-eth1 |grep -i ipaddr |awk -F = '{print $2}'`
                echo $my_ip  >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "/etc/sysconfig/network-scripts/ifcfg-eth1 does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                exit
        fi
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Determine netmask and network of eth1 ***" >> rshybridnetworkconfig$(date +%d%m%y).log
# this ifconfig statement tested working on all current Cloud Server OS's
my_netmask=`ifconfig |grep $my_ip |grep -i mask |awk -F : '{print$4}'`
my_network=`./ipcalc $my_ip $my_netmask |grep Network |awk '{print$2}'`
echo "eth1 IP: "$my_ip >> rshybridnetworkconfig$(date +%d%m%y).log
echo "Netmask: "$my_netmask >> rshybridnetworkconfig$(date +%d%m%y).log
echo "Network: "$my_network >> rshybridnetworkconfig$(date +%d%m%y).log
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Check gateways.txt for proper GATEWAY IP ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [ -f gateways.txt ]; then 
	if [[ $os = ubuntu ]]; then
		if [[ -f /usr/bin/fromdos ]]; then
			fromdos gateways.txt
		else
			apt-get install tofrodos
			fromdos gateways.txt
		fi
	elif [[ $os = debian ]]; then
		if [[ -f /usr/bin/fromdos ]]; then
			fromdos gateways.txt
		else	
			apt-get install tofrodos
			fromdos gateways.txt
		fi
	else	
		if [[ -f /usr/bin/dos2unix ]]; then
			dos2unix gateways.txt
		else
			yum install -y dos2unix
			dos2unix gateways.txt
		fi
	fi
	if [ `cat gateways.txt |grep $my_network |wc -l` -gt 1 ]; then
		echo "Too many "$my_network" matches found in gateways.txt file! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
        exit
    elif [ `cat gateways.txt |grep $my_network |wc -l` -lt 1 ]; then
        echo "No "$my_network" matches found in gateways.txt file! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
        exit  
    else
        my_gateway=`cat gateways.txt |grep $my_network |awk '{print $2}'`
    fi
	echo $my_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
else
	echo "gateways.txt file does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
	exit
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Check current eth0 GATEWAY IP ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ $os = ubuntu ]]; then
        if [[ -f /etc/network/interfaces ]]; then
                eth0_gateway=`cat /etc/network/interfaces |grep -i gateway |awk '{print$2;exit}'`
		echo $eth0_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "/etc/network/interfaces does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                exit
        fi
elif [[ $os = debian ]]; then
        if [[ -f /etc/network/interfaces ]]; then
                eth0_gateway=`cat /etc/network/interfaces |grep -i gateway |awk '{print$2;exit}'`
		echo $eth0_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "/etc/network/interfaces does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                exit
        fi
else
        if [[ -f /etc/sysconfig/network ]]; then
                eth0_gateway=`cat /etc/sysconfig/network |grep -i gateway |awk -F = '{print $2}'`
		echo $eth0_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
	else
		echo "/etc/sysconfig/network does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
		exit
	fi
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Check current eth1 GATEWAY IP ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ $os = ubuntu ]]; then
	if [[ -f /etc/network/interfaces ]]; then
		current_gateway=`cat /etc/network/interfaces |grep -i gateway |awk '{getline;print $2}'`
		echo $current_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
	else
		echo "/etc/network/interfaces does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
		exit
	fi
elif [[ $os = debian ]]; then
	if [[ -f /etc/network/interfaces ]]; then
                current_gateway=`cat /etc/network/interfaces |grep -i gateway |awk '{getline;print $2}'`
                echo $current_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "/etc/network/interfaces does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
		exit
        fi
else
	if [[ -f /etc/sysconfig/network ]]; then
        	current_gateway=`cat /etc/sysconfig/network |grep -i gateway |awk -F = '{print $2}'`
        	echo $current_gateway >> rshybridnetworkconfig$(date +%d%m%y).log
	else
        	echo "/etc/sysconfig/network does not exist! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
        	exit
	fi
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** If Ubuntu or Debian, comment out current eth0 GATEWAY IP ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ $os = ubuntu ]]; then
        placeholder=`cat /etc/network/interfaces |grep gateway |awk '{print;exit}'`
        if [[ `echo $placeholder |grep '#'` ]]; then
                echo "eth0 GATEWAY IP already commented, no change needed." >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                sed -i "s/$placeholder/#$placeholder/g" /etc/network/interfaces
                echo "eth0 GATEWAY IP commented out." >> rshybridnetworkconfig$(date +%d%m%y).log
        fi
elif [[ $os = debian ]]; then
        placeholder=`cat /etc/network/interfaces |grep gateway |awk '{print;exit}'`
        if [[ `echo $placeholder |grep '#'` ]]; then
                echo "eth0 GATEWAY IP already commented, no change needed." >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                sed -i "s/$placeholder/#$placeholder/g" /etc/network/interfaces
                echo "eth0 GATEWAY IP commented out." >> rshybridnetworkconfig$(date +%d%m%y).log
        fi
else
        echo "OS is not Ubuntu or Debian. No change needed." >> rshybridnetworkconfig$(date +%d%m%y).log
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** If current eth1 and proper gateways match, do nothing. Else, update with proper gateway ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ "$my_gateway" = "$current_gateway" ]] ; then
        echo "Gateways match, no change needed." >> rshybridnetworkconfig$(date +%d%m%y).log
else
        echo "Gateway mismatch, changing network file to reflect proper gateway." >> rshybridnetworkconfig$(date +%d%m%y).log
       	if [[ $os = ubuntu ]]; then
		placeholder=`cat /etc/network/interfaces |grep address |awk '{getline;print}'`
		sed -i "s/$placeholder/$placeholder\n    gateway $my_gateway/" /etc/network/interfaces
		if [[ `cat /etc/network/interfaces |grep -i gateway |awk '{getline;print$2}'` = $my_gateway ]]; then
                        echo "Gateway has been updated successfully." >> rshybridnetworkconfig$(date +%d%m%y).log
                else
                        echo "Gateway update failed! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                        exit
                fi
	elif [[ $os = debian ]]; then
		placeholder=`cat /etc/network/interfaces |grep address |awk '{getline;print}'`
                sed -i "s/$placeholder/$placeholder\n    gateway $my_gateway/" /etc/network/interfaces
		if [[ `cat /etc/network/interfaces |grep -i gateway |awk '{getline;print$2}'` = $my_gateway ]]; then
                        echo "Gateway has been updated successfully." >> rshybridnetworkconfig$(date +%d%m%y).log
                else
                        echo "Gateway update failed! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                        exit
                fi
	else
		if [[ "$current_gateway" = "" ]]; then
                	sed -i "/GATEWAY/s|$|$my_gateway|" /etc/sysconfig/network
        	else
                	sed -i "s/$current_gateway/$my_gateway/g" /etc/sysconfig/network
        	fi
        	if [[ `cat /etc/sysconfig/network |grep -i gateway |awk -F = '{print $2}'` = $my_gateway ]]; then
                	echo "Gateway has been updated successfully." >> rshybridnetworkconfig$(date +%d%m%y).log
        	else
                	echo "Gateway update failed! Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
                	exit
        	fi
	fi
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Make sure eth0 is down ***" >> rshybridnetworkconfig$(date +%d%m%y).log
ifconfig eth0 down
if [[ `ifconfig |grep "eth0" |wc -l` = 0 ]]; then
        echo "eth0 offline." >> rshybridnetworkconfig$(date +%d%m%y).log
else
        echo "eth0 failed to be brought down. Exiting." >> rshybridnetworkconfig$(date +%d%m%y).log
        exit
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Ensure eth0 is disabled (persistent across reboots) ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ $os = ubuntu ]];then
	if [[ `cat /etc/network/interfaces |grep "auto eth0" |wc -l` = 1 ]]; then
		sed -i 's/auto eth0//g' /etc/network/interfaces
		echo "eth0 auto start removed." >> rshybridnetworkconfig$(date +%d%m%y).log
	else
		echo "eth0 not configured to start on boot. Continuing." >> rshybridnetworkconfig$(date +%d%m%y).log
	fi 
elif [[ $os = debian ]]; then
	if [[ `cat /etc/network/interfaces |grep "auto eth0" |wc -l` = 1 ]]; then
                sed -i 's/auto eth0//g' /etc/network/interfaces
                echo "eth0 auto start removed." >> rshybridnetworkconfig$(date +%d%m%y).log
        else
                echo "eth0 not configured to start on boot. Continuing." >> rshybridnetworkconfig$(date +%d%m%y).log
        fi
else
	if [ -f /etc/sysconfig/network-scripts/ifcfg-eth0 ]; then
        	sed -i "s/ONBOOT=yes/ONBOOT=no/g" /etc/sysconfig/network-scripts/ifcfg-eth0
        	echo "eth0 ONBOOT is set to no." >> rshybridnetworkconfig$(date +%d%m%y).log
	else
        	echo "/etc/sysconfig/network-scripts/ifcfg-eth0 does not exist." >> rshybridnetworkconfig$(date +%d%m%y).log
	fi
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Restart networking for changes to take effect ***" >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ $os = ubuntu ]]; then
	/etc/init.d/networking restart
elif [[ $os = debian ]]; then
	/etc/init.d/networking restart
else
	/etc/init.d/network restart
fi
echo "Networking restarted." >> rshybridnetworkconfig$(date +%d%m%y).log
if [[ `route -n |grep $my_gateway` ]]; then
        echo "Proper eth1 gateway route exists." >> rshybridnetworkconfig$(date +%d%m%y).log
else
        echo "Proper eth1 gateway route *does not* exist. Manual intervention required." >> rshybridnetworkconfig$(date +%d%m%y).log
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Cleanup ***" >> rshybridnetworkconfig$(date +%d%m%y).log
rm -f ipcalc
if [ -f ipcalc ]; then
        echo "Cleanup failed. Please remove the ipcalc script manually." >> rshybridnetworkconfig$(date +%d%m%y).log
else
        echo "Successfully removed ipcalc. Cleanup finished." >> rshybridnetworkconfig$(date +%d%m%y).log
fi
echo >> rshybridnetworkconfig$(date +%d%m%y).log

echo "*** Script Completed! ***" >> rshybridnetworkconfig$(date +%d%m%y).log
echo "##########   E N D   ########## - "`date`" - ##########   E N D   ##########" >> rshybridnetworkconfig$(date +%d%m%y).log
echo >> rshybridnetworkconfig$(date +%d%m%y).log
