#!/bin/bash

############################################
# Usage:
# ./inter-vm-test.sh ./config/vm-list.lst ./config/test-matrix.lst icmp-ping /home/bettychen/my_key.pem
# ./inter-vm-test.sh ./config/vm-list.lst ./config/test-matrix.lst ssh /home/bettychen/my_key.pem
############################################

#------------------------------------------
# 1) Check the script aruguments
#------------------------------------------
if [ -z "$1" ]; then
	echo "ERROR: please provide vm_list config file."
	echo "Examples:"
	echo "./inter-vm-test.sh ./config/vm-list.lst ./config/test-matrix.lst icmp-ping /home/bettychen/my_key.pem"
	echo "./inter-vm-test.sh ./config/vm-list.lst ./config/test-matrix.lst ssh /home/bettychen/my_key.pem"
	exit 1
else
	vm_list="$1"
fi

if [ -z "$2" ]; then
	echo "ERROR: please provide vm_test_matrix config file."
	exit 1
else
	vm_test_matrix="$2"
fi

if [ -z "$3" ]; then
	echo "ERROR: please specify the test: 'ssh' or 'icmp-ping'"
	exit 1
elif [ "ssh" == "$3" ]; then
	test="ssh"
elif [ "icmp-ping" == "$3" ]; then
	test="icmp-ping"
else
	echo "ERROR: cannot understand the test: '$3'. Only accept 'ssh' or 'icmp-ping'"
	exit 1
fi

if [ -n "$4" ]; then
	echo "Additional parameter provided; assume it is key file: $4"
	user_access_key_file="$4"
fi

if [ ! -f $vm_list ]; then
	echo "ERROR: vm_list ($vm_list) does not exist"
	exit 1
fi

if [ ! -f $vm_test_matrix ]; then
	echo "ERROR: vm_test_matrix ($vm_test_matrix) does not exist"
	exit 1
fi


log_file="./inter-vm-$test-test.log"
echo "" > $log_file
function LOG() {
	echo "$1"
	echo "`date`: $1" >> $log_file
}

function LOG_VERBOSE() {
	echo "VERBOSE: $1"
}

#------------------------------------------
# 2) Define script variables
#------------------------------------------
ssh_ping_timeout=5
# The ping time interval for ICMP ping
# The max value can be set by a normal user is 200 millisecond
ping_interval=0.2
# Ping with about 1 minute (300 * 0.2 sec)
ping_count=300
default_username=bettychen

num_pass=0
num_fail=0

declare -A vm_username_array
declare -A vm_ip_array

#------------------------------------------
# 3)
# Read the test matrix file ('source vm' name -> 'destination vm' name)
# From the VM name, find its IP address by looking the vm_ip_array
# Then check:
#   a) Is the 'source vm' reachable? test this by a ssh connection
#   b) Can we establish ssh connection from 'source vm' to 'destination vm'?
#   c) What's the ICMP ping latency from 'source vm' to 'destination vm'?
#------------------------------------------
function Process_Inter_VM_Ping() {
	#------------------------------------------
	# If there is no VM defined yet, then ignore the processing
	#------------------------------------------
	if [ "${#vm_ip_array[@]}" = "0" ]; then
		return
	fi
	if [ "${#vm_username_array[@]}" = "0" ]; then
		LOG "Error: no user name defined"
		return
	fi
	# DEBUG only:
	# for v in "${!vm_ip_array[@]}"; do echo "$v is ${vm_ip_array[$v]}"; done
	# for u in "${!vm_username_array[@]}"; do echo "$u is ${vm_username_array[$u]}"; done

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
		# a) Make sure we can reach out to ${vm_ip_array[$vm_src]}
		timeout $ssh_ping_timeout bash -c "(: </dev/tcp/${vm_ip_array[$vm_src]}/22) &>/dev/null"
		if [[ "$?" != "0" ]] ; then
			LOG "$vm_src [${vm_ip_array[$vm_src]}]: FAILED"
			LOG_VERBOSE "Try to ping the source VM ${vm_ip_array[$vm_src]} with icmp ping, but failed."
			LOG_VERBOSE "Is this VM online? Do you use the correct IP address in the VM List file?"
			num_fail=$(($num_fail + 1))
			continue
		fi

		# b) Test that can we connect to ${vm_ip_array[$vm_dst]} from ${vm_ip_array[$vm_src]} by ssh
		# Note:
		# Q: Why "< /dev/null" in the end?
		# A: ssh is reading the rest of your standard input. 'read' (in the line of 'while') reads from stdin. 
		#    The '<' redirects stdin from a file. 
		#    So, below ssh command reads from stdin and it winds up eating the rest of your file.
		#    Other than below solution (with second redirect), we also can add '-n' option to ssh command
		#
		# By the way, change 'while' to 'for' will work, as 'for' doesn't redirect to stdin.
		# In fact, it reads the entire contents of the the txt file into memory before the first iteration.
		username=${vm_username_array[$vm_src]}
		if [ "$user_access_key_file" != "" ]; then
			key_options="-i $user_access_key_file"
			LOG_VERBOSE "Using key file $user_access_key_file to access $username@${vm_ip_array[$vm_src]}"
		else
			key_options=""
			LOG_VERBOSE "No key file provided to access $username@${vm_ip_array[$vm_src]}"
		fi
		key_options="$key_options -o StrictHostKeyChecking=no"

		ssh $key_options $username@${vm_ip_array[$vm_src]} "timeout $ssh_ping_timeout bash -c \"(: </dev/tcp/${vm_ip_array[$vm_dst]}/22) &>/dev/null\"" < /dev/null

		if [[ "$?" != "0" ]] ; then
			LOG "$username @ $vm_src [${vm_ip_array[$vm_src]}] -> $vm_dst [${vm_ip_array[$vm_dst]}]: FAILED"
			LOG_VERBOSE "Try to connect to the source VM ${vm_ip_array[$vm_src]} with ssh, but failed."
			num_fail=$(($num_fail + 1))
			continue
		fi

		if [ "$test" == "ssh"  ]; then
			LOG "$username @ $vm_src [${vm_ip_array[$vm_src]}] -> $vm_dst [${vm_ip_array[$vm_dst]}]: PASS"
			num_pass=$(($num_pass + 1))
			# if only do ssh connection test, then stop here and move on next one;
			# otherwise, go ahead and do icmp ping test
			continue
		fi

		# c) Start ICMP ping latency test, if VM can be reached by ssh
		num_pass=$(($num_pass + 1))
		LOG_VERBOSE "Checking icmp ping latency ($ping_count); please wait ..."
		output="$(ssh $key_options -n $username@${vm_ip_array[$vm_src]} ping -c $ping_count -i $ping_interval ${vm_ip_array[$vm_dst]} | grep avg)"
		# Processing the latency statistics
		# Example output: 
		# rtt min/avg/max/mdev = 0.530/0.620/0.716/0.061 ms
		IFS='/' read -ra latency <<< ${output}
		LOG "$username @ $vm_src [${vm_ip_array[$vm_src]}] -> $vm_dst [${vm_ip_array[$vm_dst]}]: PASS. avg:${latency[4]}; max:${latency[5]}"

	done < $vm_test_matrix
}


LOG "Begin the Inter-VM test: $test"
LOG "----------------------------"
LOG "vm_list = $vm_list"
LOG "vm_test_matrix = $vm_test_matrix"

LOG "*******************************************"
LOG "Read the VM IP from $vm_list ..."
while IFS='' read -r line || [[ -n "$line" ]]; do

	if [ "$line" = "" ]; then
		continue  # skip the blank line
	fi

	#------------------------------------------
	# A new "LAB" defination startes here
	#------------------------------------------
	if [[ $line == LAB* ]] ; then
		# Let's process previous lab first, if has.
		Process_Inter_VM_Ping

		# Now cleanup the array for the next "LAB"
		LOG "*** $line ***"
		# Cleanup array: unset all of the elements
		for v in "${!vm_ip_array[@]}"; do unset 'vm_ip_array[$v]'; done
		for u in "${!vm_username_array[@]}"; do unset 'vm_username_array[$u]'; done

		continue
	fi

	#------------------------------------------
	# Build the Lab vm array for IP/UserName
	# Split vm_name and vm_ip from the line read from the file
	#------------------------------------------
	IFS=':' read -r -a elements <<< $line
	vm_elements_len=${#elements[@]}
	if [ "$vm_elements_len" == "2"  ]; then
		vm_un_tmp="$default_username"
		LOG_VERBOSE "$line"
		LOG_VERBOSE "No username specified in VM List File. Use default username: $default_username"
		vm_name_tmp="${elements[0]}"
		vm_ip_tmp="${elements[1]}"
	elif [ "$vm_elements_len" == "3" ]; then
		vm_un_tmp="${elements[0]}"
		vm_name_tmp="${elements[1]}"
		vm_ip_tmp="${elements[2]}"
	else
		#cannot parse the vm info. skip to next line
		LOG "ERROR: cannot parse this line: $line"
		continue
	fi

	vm_un="$(echo -e ${vm_un_tmp} | sed -e 's/[[:space:]]*$//')"
	vm_name="$(echo -e ${vm_name_tmp} | sed -e 's/[[:space:]]*$//')"
	vm_ip="$(echo -e ${vm_ip_tmp} | sed -e 's/[[:space:]]*$//')"

	vm_username_array[$vm_name]=$vm_un
	vm_ip_array[$vm_name]=$vm_ip

done < $vm_list

#------------------------------------------
# Reached to the end of the file
#------------------------------------------
Process_Inter_VM_Ping

LOG "----------------------------"
LOG "Inter-VM test finished:"
LOG "PASS: $num_pass; FAILED: $num_fail"

exit 0
