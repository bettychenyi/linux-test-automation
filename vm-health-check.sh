#!/bin/bash

log_file="./vm-health-check.log"
function LOG() {
	echo "`date`: $1"
	echo "`date`: $1" >> $log_file
}

if [ -z "$1" ]; then
        LOG "ERROR: please provide vm_list config file."
	LOG "Example: ./check_healthy.sh my-vm.lst"
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
	vm_elements_len=${#elements[@]}
	if [ "$vm_elements_len" == "2"  ]; then
		vm_role="${elements[0]}"
		vm_ip_tmp="${elements[1]}"
	elif [ "$vm_elements_len" == "3" ]; then
		# element[0] is username
		vm_role="${elements[1]}"
		vm_ip_tmp="${elements[2]}"
	else
	#cannot parse the vm info. skip to next line
		LOG "ERROR: cannot parse this line: $line"
		continue
	fi
	vm_ip="$(echo -e ${vm_ip_tmp} | sed -e 's/[[:space:]]*$//')"

	#------------------------------------------
	# Check the TCP port 22 is reachable
	#------------------------------------------
	timeout $ping_timeout bash -c "(: </dev/tcp/$vm_ip/22) &>/dev/null"
	if [[ "$?" == "0" ]] ; then
		LOG "[$vm_role] $vm_ip: Up and Running/Volume attached, OAM Access (TCP Port 22): Pass"
		num_pass=$(($num_pass + 1))
	else
		LOG "[$vm_role] $vm_ip: port 22 is not reachable"
		num_fail=$(($num_fail + 1))
	fi
done < $vm_list

LOG "----------------------------"
LOG "OAM Checking finished:"
LOG "PASS: $num_pass; FAILED: $num_fail"
