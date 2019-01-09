#!/usr/bin/python

# Usage:
# use alax to run selected (or ALL) test cases on the VMs in the vm-list-file
# python ./alax.py vm-list-file.lst test-case-name|ALL your_email@contoso.com
#


import sys
import xml.dom.minidom
from logger import * 
from reporter import *
from testmanager import *
from util import *


#############################################
# Check the script parameters
#############################################
default_username = "bettychen"

num_args = len(sys.argv)
if num_args < 3:
	LOG("Error: missing parameters. Example:")
	LOG("python ./alax.py ./my-vm.lst ./XML/vSCP-image-prep-lab-testcases.xml")
	sys.exit (1)

vm_list = sys.argv[1]
test_xml = sys.argv[2]
testcase_list = []
testvm_list = []
email_report_to = "NA"

#############################################
# Start testing
#############################################
LOG("ALAX Started: " + str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
LOG("-----------------------------------------------")
LOG("VM LIST  	: " + vm_list)
LOG("TEST XML 	: " + test_xml)
LOG("TEST LOG	: " + log_filename)

DOMTree = xml.dom.minidom.parse(test_xml)
collection = DOMTree.documentElement
if collection.hasAttribute("ReportTo"):
	email_report_to = collection.getAttribute("ReportTo")
LOG("REPORT TO	: " + email_report_to)

testcases = collection.getElementsByTagName("TestCase")
LOG("TEST CASES	: ")
test_index = 1
for testcase in testcases:
	t_id	= test_index
	t_name 	= GetTestTagText(testcase, 'TestName')
	t_script= GetTestTagText(testcase, 'ExecScript')
	t_log	= GetTestTagText(testcase, 'LogFile')

	tc = AlaxTestCase()
	tc.TestID	= t_id
	tc.TestName	= t_name
	tc.ExecScript	= t_script
	tc.LogFile	= t_log

	testcase_list.append(tc)
	LOG("        {0} : {1}".format(tc.TestID, tc.TestName))
	test_index += 1

LOG("     TOTAL : {0}".format(len(testcase_list)))
LOG("-----------------------------------------------")

LOG("Read the VM IP from {0} ...".format(vm_list))
LOG("")
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
			LOG("*** ERROR: cannot parse vm info : {0}".format(line))
			continue

		vm = AlaxTestVM()
		vm.Role = vm_role
		vm.IP = vm_ip
		vm.UserName = vm_username

		LOG("*** {0}: {1}@{2}: Run {3} test cases ...".format(vm_role, vm_username, vm_ip, len(testcase_list)))
		testcase_result = {}

		for testcase in testcase_list:
			testcase_bash_script = testcase.ExecScript
			LOG("    TEST #{0}: {1}".format(testcase.TestID, testcase_bash_script))
			test_result = run_single_test_on_single_vm(vm, testcase)

			if test_result == 0:
				testcase_result[testcase.TestID] = "PASS"
				LOG("             PASSED")
			elif test_result == 1:
				testcase_result[testcase.TestID] = "FAILED"
				LOG("             FAILED")
			else:
				testcase_result[testcase.TestID] = "ABORTED."
				LOG("             ABORTED.")

		vm.TestResults = testcase_result
		testvm_list.append(vm)
		LOG("")

LOG("-----------------------------------------------")
LOG("Test Summary:")
for vm in testvm_list:
	for key, value in vm.TestResults.items():
		LOG("{0}[{1}@{2}]	TEST#{3}: {4}".format(vm.Role, vm.UserName, vm.IP, key, value))

LOG("-----------------------------------------------")
LOG("ALAX Finished: " + str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')))
