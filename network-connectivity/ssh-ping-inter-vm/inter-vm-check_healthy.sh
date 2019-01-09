#!/bin/bash

log_file="/var/log/inter-vm-health-check.log"
vm_list="vm-list.lst"
vm_test_matrix="vm-test-matrix.lst"
ping_timeout=5
username=betty

function LOG() {
	echo "`date`: $1"
	#echo "`date`: $1" >> $log_file
}

declare -A vm_array

function Process_Inter_VM_Ping() {
	#------------------------------------------
	# If there is no VM defined yet, then ignore the processing
	#------------------------------------------
	if [ "${#vm_array[@]}" = "0" ]; then
		return
	fi
	#for v in "${!vm_array[@]}"; do echo "$v is ${vm_array[$v]}"; done

	#------------------------------------------
	# Otherwise, read the test matrix defination
	# and do the test
	#------------------------------------------
	while IFS='' read -r tm_line || [[ -n "$tm_line" ]]; do
		if [ "$tm_line" == "" ]; then
			continue
		fi

		IFS='-' read -r -a elements <<< $tm_line
		vm_src_tmp="${elements[0]}"
		vm_src="$(echo -e ${vm_src_tmp} | sed -e 's/[[:space:]]*$//')"		
		vm_dst_tmp="${elements[1]}"
		vm_dst="$(echo -e ${vm_dst_tmp} | sed -e 's/[[:space:]]*$//')"		

		#------------------------------------------
		# Start the ssh ping test
		#------------------------------------------
		#1) Make sure we can reach out to ${vm_array[$vm_src]}
		timeout $ping_timeout bash -c "(: </dev/tcp/${vm_array[$vm_src]}/22) &>/dev/null"
		if [[ "$?" != "0" ]] ; then
			LOG "$vm_src [${vm_array[$vm_src]}]: FAILED"
			num_fail=$(($num_fail + 1))
			continue
		fi

		#2) Test that can we ping ${vm_array[$vm_dst]} from ${vm_array[$vm_src]}
		# Note:
		# Q: Why "< /dev/null" in the end?
		# A: ssh is reading the rest of your standard input. 'read' (in the line of 'while') reads from stdin. 
		#    The '<' redirects stdin from a file. 
		#    So, below ssh command reads from stdin and it winds up eating the rest of your file.
		#    Other than below solution (with second redirect), we also can add '-n' option to ssh command
		#
		# By the way, change 'while' to 'for' will work, as 'for' doesn't redirect to stdin.
		# In fact, it reads the entire contents of the the txt file into memory before the first iteration.
		ssh $username@${vm_array[$vm_src]} "timeout $ping_timeout bash -c \"(: </dev/tcp/${vm_array[$vm_dst]}/22) &>/dev/null\"" < /dev/null

		if [[ "$?" == "0" ]] ; then
			LOG "$vm_src [${vm_array[$vm_src]}] -> $vm_dst [${vm_array[$vm_dst]}]: PASS"
			num_pass=$(($num_pass + 1))
		else
			LOG "$vm_src [${vm_array[$vm_src]}] -> $vm_dst [${vm_array[$vm_dst]}]: FAILED"
			num_fail=$(($num_fail + 1))
		fi
	done < $vm_test_matrix
}


num_pass=0
num_fail=0
LOG "Begin the OAM Inter-VM healthy Checking"
LOG "----------------------------"

LOG "Read the VM IP from $vm_list ..."
while IFS='' read -r line || [[ -n "$line" ]]; do

	if [ "$line" = "" ]; then
		continue
	fi

	#------------------------------------------
	# A new "LAB" defination startes here
	#------------------------------------------
	if [[ $line == LAB* ]] ; then
		# Let's process previous lab first, if has.
		Process_Inter_VM_Ping
		
		# Now cleanup the array for the next "LAB"
		LOG "*** $line ***"
		#for v in "${!vm_array[@]}"; do echo "$v is ${vm_array[$v]}"; done
		# Cleanup the VM array: unset all of the elements
		for v in "${!vm_array[@]}"; do unset 'vm_array[$v]'; done
		#for v in "${!vm_array[@]}"; do echo "$v is ${vm_array[$v]}"; done

		continue
	fi

	#------------------------------------------
	# Build the Lab array
	# Split vm_role and vm_ip from the line read from the file
	#------------------------------------------
	IFS=':' read -r -a elements <<< $line
	vm_role_tmp="${elements[0]}"
	vm_role="$(echo -e ${vm_role_tmp} | sed -e 's/[[:space:]]*$//')"
	vm_ip_tmp="${elements[1]}"
	vm_ip="$(echo -e ${vm_ip_tmp} | sed -e 's/[[:space:]]*$//')"
	vm_array[$vm_role]=$vm_ip

done < $vm_list

#------------------------------------------
# Reached to the end of the file
#------------------------------------------
Process_Inter_VM_Ping

LOG "----------------------------"
LOG "OAM Checking finished:"
LOG "PASS: $num_pass; FAILED: $num_fail"
