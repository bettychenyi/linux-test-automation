#!/bin/bash

logfile="Application-Checking.log"
testresult=true

echo "Running tests on $(hostname) ..."				>  $logfile
echo "Date: $(date)"						>> $logfile
echo "*******************************************************"	>> $logfile

##########################################################
# syslog to remote SMLS servers
##########################################################
printf "\n" >> $logfile
echo "Checking syslog to remote SMLS servers ..."		>> $logfile
the_sysconfig="$(cat /etc/rsyslog.conf | grep 1548 | grep smls)"
echo $the_sysconfig						>> $logfile
num_lines="$(cat /etc/rsyslog.conf | grep 1548 | grep smls | wc -l)"
if [[ "$num_lines" == "2"  ]]; then
	echo "PASS: 2 lines of config found"				>> $logfile
else
	echo "ERROR: syslog config error for SMLS servers "	>> $logfile
	testresult=false
fi

##########################################################
# UAM
##########################################################
printf "\n" >> $logfile
echo "Checking UAM ..."						>> $logfile
the_allmid="$(/bin/ls -l /usr/localcw/bin/allmid*)"
echo $the_allmid						>> $logfile
the_allmid_number="$(/bin/ls -l /usr/localcw/bin/allmid* | grep allmid | wc -l)"
if [[ "$the_allmid_number" == "2"  ]]; then
	echo "PASS: 2 files match the name of allmid"			>> $logfile
else
	echo "ERROR: number of allmid files does not match 2"	>> $logfile
	testresult=false
fi

##########################################################
# Nagios
##########################################################
printf "\n" >> $logfile
echo "Checking Nagios ..."					>> $logfile


##########################################################
# SACT client
##########################################################
printf "\n" >> $logfile
echo "Checking SACT client ..."					>> $logfile

##########################################################
# SACT in cron
##########################################################
printf "\n" >> $logfile
echo "Checking SACT in cron ..."				>> $logfile

##########################################################
# allmid script version
##########################################################
printf "\n" >> $logfile
echo "Checking allmid script version"				>> $logfile
the_allmid_sh="$(/usr/localcw/bin/allmid.sh -v)"
echo $the_allmid_sh						>> $logfile
if [[ "$the_allmid_sh" == *"allmid.sh script updated version 4.31.2"*  ]];then
	echo "PASS: allmid.sh version is verified as correct"		>> $logfile
else
	echo "ERROR: allmid.sh version is INCORRECT"		>> $logfile
	testresult=false
fi

if [[ "$testresult" == "true" ]]; then
	echo TEST PASSED
else
	echo TEST FAILED
fi
