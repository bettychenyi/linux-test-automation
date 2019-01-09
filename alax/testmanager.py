#!/usr/bin/python

#
# manage the alax test objects and run test on VMs
#


import os
import subprocess
from logger import LOG


class AlaxTestCase():
	TestID		= "0"
	TestName	= ""
	ExecScript	= ""
	LogFile		= ""


class AlaxTestVM():
	Role		= "NA"
	IP		= "NA"
	UserName	= "NA"
	# a dictionary to keep the test results
	TestResults	= {} 


def run_single_test_on_single_vm(vm, testcase):
	errcode = 2
	vm_username = vm.UserName
	vm_ip = vm.IP
	testid = testcase.TestID

	testcase_bash_script = testcase.ExecScript
	testcase_script_local_path = "./{0}/{1}".format("TestCases", testcase_bash_script)
	testcase_script_remote_path = "{0}/{1}/{2}".format("/home", vm_username, testcase_bash_script)

	testlog = testcase.LogFile
	testlog_local = "./_{0}-{1}-{2}".format(vm.Role, str(testid).zfill(2), testlog)
	testlog_remote = "{0}/{1}/{2}".format("/home", vm_username, testlog)

	if os.path.isfile(testcase_script_local_path) == False:
		LOG("             ERROR: The test script does not exist")
		return 2

	#copy the script to remote VM
	os.system("scp -q {0} {1}@{2}:".format(testcase_script_local_path, vm_username, vm_ip))
	os.system("ssh -q {0}@{1} 'chmod 755 {2}'".format(vm_username, vm_ip, testcase_script_remote_path))

	ssh = subprocess.Popen(["ssh", "{0}@{1}".format(vm_username, vm_ip), testcase_script_remote_path],
				shell=False,
				stdout=subprocess.PIPE,
				stderr=subprocess.PIPE)
	result = ssh.stdout.readlines()

	os.system("scp -q {0}@{1}:{2} {3}".format(vm_username, vm_ip, testlog_remote, testlog_local))

	if result == []:
		error = ssh.stderr.readlines()
		LOG("             ERROR: %s" % error)
		errcode = 1
	else:
		for i, line in enumerate(result):
			if line.strip() == "":
				continue
			if "TEST PASSED" in line:
				errcode = 0
				break
			if "TEST FAILED" in line:
				errcode = 1
				break

	os.system("ssh -q {0}@{1} 'rm -rf {2}'".format(vm_username, vm_ip, testcase_script_remote_path))
	os.system("ssh -q {0}@{1} 'rm -rf {2}'".format(vm_username, vm_ip, testlog_remote))

	return errcode
