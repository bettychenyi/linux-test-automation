#!/usr/bin/env python

import sys
import subprocess
import time
from datetime import datetime


#############################################
# Define script variables
#############################################
log_filename = "./remote-execute.log"
default_username = "bettychen"
num_pass = 0
num_fail = 0

def LOG(message):
	message_line = str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')) + ": " + message
	print message_line
	# write this log into file, with "append" mode
	with open(log_filename, 'a') as f:
		f.write(message_line + "\n")


#############################################
# Check the script parameters
#############################################
num_args = len(sys.argv)
if num_args < 3:
	LOG("Error: missing parameters")
	LOG("Example: ./remote-execute.py my-vm.lst 'uname -r'")
	sys.exit (1)

vm_list = sys.argv[1]
command = sys.argv[2]


#############################################
# Start testing
#############################################
LOG("Begin the OAM Remote Executor")
LOG("-----------------------------------------------")
LOG("Read the VM IP from {0} ...".format(vm_list))
with open(vm_list, 'rU') as vmlist:
	for line in vmlist:
		line = line.strip()

		if not line:
			continue

		if line.startswith("LAB"):
			LOG("*** " + line + " ***")
			continue

		elements = line.split(':')
		if len(elements) == 2:
			vm_username = default_username
			vm_role     = elements[0].strip()
			vm_ip       = elements[1].strip()
		elif len(elements) == 3:
			vm_username = elements[0].strip()
			vm_role     = elements[1].strip()
			vm_ip       = elements[2].strip()
		else:
			LOG("=> ERROR: cannot parse vm info : {0}".format(line))
			continue

		LOG("=> Running on {0}: {1}@{2}".format(vm_role, vm_username, vm_ip))
		ssh = subprocess.Popen(["ssh", "{0}@{1}".format(vm_username, vm_ip), command],
				       shell=False,
				       stdout=subprocess.PIPE,
				       stderr=subprocess.PIPE)
		result = ssh.stdout.readlines()
		if result == []:
			num_fail += 1
			error = ssh.stderr.readlines()
			LOG("   ERROR: %s" % error)
		else:
			num_pass += 1
			for i, line in enumerate(result):
				LOG("   " + line.replace('\n', ''))

LOG("-----------------------------------------------")
LOG("OAM Remote Executor finished:")
LOG("PASS: " + `num_pass` + "; FAILED: " + `num_fail`)

