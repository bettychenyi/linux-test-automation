#!/bin/bash

##########################################################
# Define script variables
#########################################################
logfile="Basic-Checking-for-Linux-System.log"
testresult=true
rhel_version="7.2"

echo "Running tests on $(hostname) ..."				>  $logfile
echo "Date: $(date)"						>> $logfile
echo "*******************************************************"	>> $logfile

##########################################################
# CentOS 7 image
###########################################################
printf "\n" >> $logfile
echo "Checking /etc/redhat-release:"				>> $logfile
linux_release="$(cat /etc/redhat-release)"
echo $linux_release						>> $logfile
# RHEL release examples: 
# Red Hat Enterprise Linux Server release 7.2 (Maipo)
# Red Hat Enterprise Linux Server release 6.8 (Santiago)
IFS=' ' read -ra elements <<< $linux_release
if [[ ${#elements[@]} -eq 8 ]]; then
	rhel_version="${elements[6]}"
else
	echo "WARNING: cannot parse the redhat release version" >> $logfile
fi

echo "Checking uname -a:"					>> $logfile
uname -a							>> $logfile

##########################################################
# umask 0022
##########################################################
printf "\n" >> $logfile
echo "Checking umask:"						>> $logfile
the_umask="$(umask)"
echo $the_umask							>> $logfile
if [[ "$the_umask" == "0022" ]]; then
	echo "PASS: umask: 0022"					>> $logfile
else
	echo "ERROR: umask is NOT set to 0022"			>> $logfile
	testresult=false
fi

##########################################################
# ssh Idle Timer
##########################################################
printf "\n" >> $logfile
echo "Checking ssh Idle Timer:"					>> $logfile
the_ssh_idle_timer="$(env | grep TMOUT | grep 1800)"
env | grep TMOUT						>> $logfile
if [[ "$the_ssh_idle_timer" == "" ]]; then
	echo "ERROR: TMOUT is NOT set to 1800"			>> $logfile
	testresult=false
else
	echo "PASS: TMOUT is set to 1800"				>> $logfile
fi

##########################################################
# sshd config
##########################################################
printf "\n" >> $logfile
echo "Checking TCPKeepAlive:"					>> $logfile
ssh_config_file="/etc/ssh/sshd_config"
the_TCPKeepAlive="$(sudo cat $ssh_config_file | grep TCPKeepAlive)"
echo $the_TCPKeepAlive						>> $logfile
if [[ "$the_TCPKeepAlive" == *"yes"* ]] && [[ "$the_TCPKeepAlive" != *"#"* ]]; then
	echo "PASS: TCPKeepAlive is set to yes"			>> $logfile
else
	echo "ERROR: TCPKeepAlive is NOT set to yes"		>> $logfile
	testresult=false
fi

if [[ "$rhel_version" == *"6."* ]]; then
	echo "Checking sshd running status (by service status, on RHEL 6.x)"	>> $logfile
	the_stats_sshd="$(sudo service sshd status)"
	echo $the_stats_sshd					>> $logfile
	if [[ "$the_stats_sshd" == *"pid"* ]] && [[ "$the_stats_sshd" == *"is running"*  ]]; then
		echo "PASS: sshd is running"				>> $logfile
	else
		echo "ERROR: sshd is NOT running"		>> $logfile
		testresult=false
	fi
else
	echo "Checking sshd running status (by systemctl, on RHEL 7.x)"	>> $logfile
	the_stats_sshd="$(sudo systemctl status sshd)"
	echo $the_stats_sshd					>> $logfile
	if [[ "$the_stats_sshd" == *"Active"* ]] && [[ "$the_stats_sshd" == *"running"*  ]]; then
		echo "PASS: sshd is Active and running"		>> $logfile
	else
		echo "ERROR: sshd is NOT Active and running"	>> $logfile
		testresult=false
	fi
fi

##########################################################
# UTC Timezone
##########################################################
printf "\n" >> $logfile
echo "Checking Time Zone is set to UTC:"			>> $logfile
the_date="$(date)"
echo $the_date							>> $logfile
if [[ "$the_date" == *"UTC"* ]]; then
	echo "PASS: The time zone is set to UTC"			>> $logfile
else
	echo "ERROR: time zone is NOT set to UTC"		>> $logfile
	testresult=false
fi

##########################################################
# DNS resolution
##########################################################
printf "\n" >> $logfile
echo "Checking DNS settings:"					>> $logfile
the_dns_setting="$(cat /etc/resolv.conf | grep nameserver)"
echo $the_dns_setting						>> $logfile
cat /etc/resolv.conf | grep nameserver > /dev/null
if [[ $? == 0 ]]; then
	FS=' ' read -ra elements <<< $the_dns_setting
	if [[ ${#elements[@]} == 2 ]]; then
		the_ip=${elements[1]}
		the_num_ip_seg="$(echo $the_ip | tr -cd '.' | wc -c)"
		if [[ $the_num_ip_seg != 3 ]]; then
			echo "ERROR: DNS nameserver is NOT set to a valid IP"	>> $logfile
			testresult=false
		else
			echo "PASS: The DNS nameserver is set"	>> $logfile
		fi
	else
		echo "ERROR: cannot parse the DNS nameserver"	>> $logfile
		testresult=false
	fi
else
	echo "ERROR: cannot find nameserver from /etc/resolv.conf"		>> $logfile
	testresult=false
fi

##########################################################
# sudoers
##########################################################
printf "\n" >> $logfile
echo "Checking sudo su (is current user in group wheel?)"	>> $logfile
the_user_group="$(groups)"
echo $the_user_group						>> $logfile
if [[ "$the_user_group" == *"wheel"*  ]]; then
	echo "PASS: current user is in wheel group and in sudoer file"	>> $logfile
else
	echo "ERROR: current user is NOT in wheel group. sudo su will fail"	>> $logfile
	testresult=false
fi

##########################################################
# telnet
##########################################################
printf "\n" >> $logfile
echo "Checking telnet has been installed"			>> $logfile
the_telnet_installed="$(yum list installed | grep telnet)"
echo $the_telnet_installed					>> $logfile
if [[ "$the_telnet_installed" != "" ]]; then
	echo "PASS: telnet has been installed from yum"		>> $logfile
else
	echo "ERROR: telnet has NOT been installed from yum"	>> $logfile
	testresult=false
fi

##########################################################
# VM hostname
##########################################################
printf "\n" >> $logfile
echo "Checking VM hostname preserve:"				>> $logfile
hostname_cfg_file="/etc/cloud/cloud.cfg.d/99_hostname.cfg"
if [[ ! -f $hostname_cfg_file ]]; then
	echo "ERROR: $hostname_cfg_file does not exist"		>> $logfile
	testresult=false
else
	the_preserve_hostname="$(sudo cat /etc/cloud/cloud.cfg.d/99_hostname.cfg)"
	echo $the_preserve_hostname				>> $logfile
	echo $the_preserve_hostname | grep "preserve_hostname" | grep "false"
	if [[ $? -eq 0  ]]; then
		echo "PASS: preserve_hostname: false"			>> $logfile
	else
		echo "ERROR: preserve_hostname is NOT set to false"	>> $logfile
		testresult=false
	fi
fi

##########################################################
# Testing reached to the end
##########################################################
if [[ "$testresult" == "true" ]]; then
	echo TEST PASSED
else
	echo TEST FAILED
fi
