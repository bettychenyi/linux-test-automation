#!/usr/bin/python

# Usage:
# python ./monitor-vm-resource.py vm-list-file.lst your_email@contoso.com

import os, errno
import sys
import smtplib
import subprocess
import time
from datetime import datetime

from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

log_filename = "./monitor-vm-resource.log"
try:
	os.remove(log_filename)
except OSError:
	pass

def LOG(message):
	message_line = str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')) + ": " + message
	print message_line
	# write this log into file, with "append" mode
	with open(log_filename, 'a') as f:
		f.write(message_line + "\n")


def LOG_VERBOSE(message):
	message_line = str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')) + ": " + message
	print message_line


def send_mail(to_email, subject, message):
	fromaddr = "my_email@gmail.com"
	toaddr = to_email
	username = "my_email@gmail.com"
	password = "my_email_password"
	smtpsvr = "smtp.gmail.com:587"
	msg = MIMEMultipart()
	msg['From'] = fromaddr
	msg['To'] = toaddr
	msg['Subject'] = subject
	body = message 
	msg.attach(MIMEText(body, 'plain'))
	try:
		server = smtplib.SMTP(smtpsvr)
		server.ehlo()
		server.starttls()
		server.login(username,password)
		text = msg.as_string()
		server.sendmail(fromaddr, toaddr, text)
		server.quit()
	except smtplib.SMTPException:
		LOG("Error: unable to send email to: " + to_email)


def check_vm_ram_utilization(username, vm_ip, user_key_file):
	ssh = subprocess.Popen(["ssh", "-i", user_key_file, "-o", "StrictHostKeyChecking=no", "{0}@{1}".format(username, vm_ip), 'free'],
				shell=False,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)
	result = ssh.stdout.readlines()
	#               total        used        free      shared  buff/cache   available
	# Mem:       32781696     3868412    27810052       98768     1103232    28560660
	# Swap:       8388604           0     8388604
	if result == []:
		error = ssh.stderr.readlines()
		LOG_VERBOSE("=> ERROR: %s" % error)
	else:
		index_total_Mem = 1
		index_used_Mem  = 2

		for i, line in enumerate(result):
			#print line

			if line.strip() == "":
				continue
			if "total" in line:
				continue
			if "Swap" in line:
				continue

			elements_raw = line.split(' ')
			# remove those elements with only space
			elements = [x.replace('\n', '') for x in elements_raw if x]
			if len(elements) < 7:
				LOG_VERBOSE("Error: not able to parse free output:")
				LOG_VERBOSE(line)
				return "ERROR"

			total_mem = elements[index_total_Mem]  # total
			used_mem  = elements[index_used_Mem]   # used
			return "{0}:{1:.1%}".format("Mem", float(used_mem)/float(total_mem))


def check_vm_cpu_utilization(username, vm_ip, idle_low_bound, steal_high_boundi, user_key_file):
	ssh = subprocess.Popen(["ssh", "-i", user_key_file, "-o", "StrictHostKeyChecking=no", "{0}@{1}".format(username, vm_ip), 'mpstat -P ALL 1 2'],
				shell=False,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)
	result = ssh.stdout.readlines()
	#  Linux 3.10.0-327.36.3.el7.x86_64 (bettychen_dev)      07/05/2018      x86_64        (8 CPU)
	#  07:38:34 AM  CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest   %idle
	#  07:38:34 AM  all    0.11    0.00    0.06    0.01    0.00    0.00    0.00    0.00   99.83
	#  07:38:34 AM    0    0.09    0.00    0.04    0.00    0.00    0.00    0.00    0.00   99.87
	#  07:09:04 PM    1    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00  100.00
	#  Average:       0    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00   99.87
	#  Average:       1    0.00    0.00    0.00    0.00    0.00    0.00    0.00    0.00  100.00 

	if result == []:
		error = ssh.stderr.readlines()
		LOG_VERBOSE("=> ERROR: %s" % error)
	else:
		index_CPU   = 2
		index_steal = 9
		index_idle  = 11

		for i, line in enumerate(result):
			#print line

			if line.strip() == "":
				continue
			if "Linux" in line:
				continue
			if "CPU" in line:
				elements_raw = line.split(' ')
				elements = [x.replace('\n', '') for x in elements_raw if x]
				# print ', '.join(elements)
				index_CPU   = elements.index("CPU")
				index_steal = elements.index("%steal")
				index_idle  = elements.index("%idle")
				continue
			if "all" in line:
				continue
			if "Average" in line:
				continue

			elements_raw = line.split(' ')
			# remove those elements with only space
			elements = [x.replace('\n', '') for x in elements_raw if x]
			if len(elements) < 12:
				LOG_VERBOSE("Error: not able to parse mpstat output:")
				LOG_VERBOSE(line)
				return "ERROR"

			cpu_id   = elements[index_CPU]    # CPU 
			cpu_steal= elements[index_steal]  # %steal
			cpu_idle = elements[index_idle]   # %idle
			
			if float(cpu_idle) < idle_low_bound:
				warning_msg = "Alert: [{0}]: CPU#{1}  idle = {2}% (<{3}%)".format(vm_ip, cpu_id, cpu_idle, idle_low_bound)
				LOG_VERBOSE("=> " + warning_msg)
				#send_mail(to_email, 'VM Health Checking [CPU] ' + warning_msg, ''.join(result))
				return "CPU{0}:{1}({2}<{3})".format(cpu_id, "idle", cpu_idle, idle_low_bound)
			if float(cpu_steal) > steal_high_boundi:
				warning_msg = "Alert: [{0}]: CPU#{1} steal = {2}% (>{3}%)".format(vm_ip, cpu_id, cpu_steal, steal_high_boundi)
				LOG_VERBOSE("=> " + warning_msg)
				#send_mail(to_email, 'VM Health Checking [CPU] ' + warning_msg, ''.join(result))
				return "CPU{0}:{1}({2}>{3})".format(cpu_id, "steal", cpu_steal, steal_high_boundi)
		LOG_VERBOSE("   No resource alert.")
		return "CPU: OK"


#############################################
# Check the script parameters
#############################################
cpu_idle_threshold = 50
cpu_steal_threshold = 2
default_username ="bettychen"

num_args = len(sys.argv)
if num_args < 3:
	LOG("Error: missing parameters")
	LOG("Example: ./monitor-vm-resource.py my-vm.lst /home/bettychen/my_key.pem")
	sys.exit (1)

vm_list = sys.argv[1]
user_access_key_file = sys.argv[2]


#############################################
# Start testing
#############################################
LOG("Begin the OAM Resource Checker")
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
	
		LOG_VERBOSE("Checking {0}: {1}@{2} with {3} ...".format(vm_role, vm_username, vm_ip, user_access_key_file))
		CPU_Result = check_vm_cpu_utilization(vm_username, vm_ip, cpu_idle_threshold, cpu_steal_threshold, user_access_key_file)
		Mem_Result =  check_vm_ram_utilization(vm_username, vm_ip, user_access_key_file)
		LOG("{0}:{1}	{2}	{3}".format(vm_role, vm_ip, CPU_Result, Mem_Result))

LOG("Resource checking finished")
#while (1):
#	sys.stdout.write('.')
#	sys.stdout.flush()
#	cpu_check = check_vm_cpu_utilization(username, vm_ip, cpu_idle_threshold, cpu_steal_threshold, alert_email_to)
#	if cpu_check != 0:
#		break
#	time.sleep(5)

#print "Error: test exited with alter email sent to " + alert_email_to
