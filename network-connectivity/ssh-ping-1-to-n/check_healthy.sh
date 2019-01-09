#!/bin/bash

log_file="/home/bettychen/log/vm-health-check.log"
function LOG() {
	echo "`date`: $1"
	echo "`date`: $1" >> $log_file
}

if [ -z "$1" ]; then
        LOG "Warning: please provide vm_list config file."
        exit 1
else
        vm_list="$1"
fi

ping_timeout=5

num_pass=0
num_fail=0
LOG "Begin the OAM Checking"
LOG "----------------------------"

LOG "Read the VM IP from $vm_list ..."
while IFS='' read -r line || [[ -n "$line" ]]; do
	if [ "$line" = "" ]; then
		continue
	fi

	if [[ $line == LAB* ]] ; then
		LOG "*** $line ***"
		continue
	fi

	#------------------------------------------
	# Split vm_role and vm_ip for test
	#------------------------------------------
	IFS=':' read -r -a elements <<< $line
	vm_role="${elements[0]}"
	vm_ip_tmp="${elements[1]}"
	vm_ip="$(echo -e ${vm_ip_tmp} | sed -e 's/[[:space:]]*$//')"

	#------------------------------------------
	# Check the TCP port 22 is reachable
	#------------------------------------------
	timeout $ping_timeout bash -c "(: </dev/tcp/$vm_ip/22) &>/dev/null"
	if [[ "$?" == "0" ]] ; then
		LOG "[$vm_role] $vm_ip: PASS"
		num_pass=$(($num_pass + 1))
	else
		LOG "[$vm_role] $vm_ip: port 22 is not reachable"
		num_fail=$(($num_fail + 1))
	fi
done < $vm_list

LOG "----------------------------"
LOG "OAM Checking finished:"
LOG "PASS: $num_pass; FAILED: $num_fail"
