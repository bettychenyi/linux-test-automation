#!/usr/bin/env python

import sys
import subprocess
import time
from datetime import datetime


#############################################
# Define script variables
#############################################
log_filename = "./remote-capture-tcpdump.log"

def LOG(message):
	message_line = str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')) + ": " + message
	print message_line
	# write this log into file, with "append" mode
	with open(log_filename, 'a') as f:
		f.write(message_line + "\n")


def SSH_REMOTE_COMMAND(user_key, command):
	if user_key == "":
		LOG("=> execute ssh with {0}@{1} without key".format(target_user, target_ip))
		sshp = subprocess.Popen(["ssh", "{0}@{1}".format(target_user, target_ip), command])
		sts = sshp.wait()
	else:
		LOG("=> execute ssh with {0}@{1} with key {2}".format(target_user, target_ip, target_user_key))
		sshp = subprocess.Popen(["ssh", "-i", target_user_key, "{0}@{1}".format(target_user, target_ip), command])
		sts = sshp.wait()
	LOG(command)


def SCP_REMOTE_COPY(user_key, filename):
	if user_key == "":
		LOG("=> execute scp with {0}@{1} without key".format(target_user, target_ip))
		scpp = subprocess.Popen(["scp", "{0}@{1}:{2}".format(target_user, target_ip, filename), filename])
		sts = scpp.wait()
	else:
		LOG("=> execute scp with {0}@{1} with key {2}".format(target_user, target_ip, target_user_key))
		scpp = subprocess.Popen(["scp", "-i", target_user_key, "{0}@{1}:{2}".format(target_user, target_ip, filename), filename])
		sts = scpp.wait()
	LOG(filename)


#############################################
# Check the script parameters
#############################################
num_args = len(sys.argv)
if num_args == 2:
	target_ip = sys.argv[1]
	target_user = "bettychen"
	target_user_key = ""
	target_eth = "eth0"
	target_tcp_port = "3868"
	target_capture_duration = "10"
	LOG("Start with default values:")
elif num_args == 7:
	target_ip = sys.argv[1]
	target_user = sys.argv[2]
	target_user_key = sys.argv[3]
	target_eth = sys.argv[4]
	target_tcp_port = sys.argv[5]
	target_capture_duration = sys.argv[6]
	LOG("Start with below command:")
else:
	LOG("Error: missing parameters")
	LOG("Example: use default value to capture traffic on 192.168.1.100")
	LOG("         ./remote-capture-tcpdump.py 192.168.1.100")
	LOG("")
	LOG("Example: use bettychen to login 192.168.1.100 with key ./my-key.pem;")
	LOG("         then start tcpdump to capture TCP traffic on eth0 for 10 seconds, on TCP port 3868")
	LOG("         ./remote-capture-tcpdump.py 192.168.1.100 bettychen ./my-key.pem eth0 3868 10")
	sys.exit (1)

LOG("./remote-capture-tcpdump.py {0} {1} {2} {3} {4} {5}".format(target_ip, target_user, target_user_key, target_eth, target_tcp_port, target_capture_duration))


#############################################
# Start testing
#############################################
LOG("Begin the Remote Capture")
LOG("-----------------------------------------------")

current_time = str(datetime.now().strftime('%Y%m%d%H%M%S'))
dump_file_name = "tcpdump-{0}-{1}-{2}-{3}sec-{4}.pcap".format(target_ip, target_eth, target_tcp_port, target_capture_duration, current_time)
tcpdump_command = "sudo /usr/sbin/tcpdump -i {0} -G {1} -W 1 port {2} -w {3}".format(target_eth, target_capture_duration, target_tcp_port, dump_file_name)
LOG("Running remote command on {0} with {1} seconds. Please wait ...".format(target_ip, target_capture_duration))

SSH_REMOTE_COMMAND(target_user_key, tcpdump_command)
SSH_REMOTE_COMMAND(target_user_key, "sudo chmod 444 {0}".format(dump_file_name))
SCP_REMOTE_COPY(target_user_key, dump_file_name)
#ssh = subprocess.Popen(["ssh", "{0}@{1}".format(target_user, target_ip), command],
#			       shell=False,
#			       stdout=subprocess.PIPE,
#			       stderr=subprocess.PIPE)
#result = ssh.stdout.readlines()

#if result == []:
#	error = ssh.stderr.readlines()
#	LOG(("   Finished with:\n %s" % error).replace("\\n', '", '\n'))
#else:
#	for i, line in enumerate(result):
#		LOG("   " + line.replace('\n', ''))

LOG("-----------------------------------------------")
LOG("Remote Capture finished.")
