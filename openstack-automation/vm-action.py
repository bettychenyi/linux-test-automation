#!/usr/bin/env python

#
# Take action to a VM specified.
# The support actions are: Start, Stop, Reboot.
# Example: python vm-action.py 'My-VM-Name' 'Reboot'

import os
import sys
from keystoneauth1 import loading
from keystoneauth1 import session
from novaclient import client
logger_path = os.path.abspath(os.path.join(__file__, '..', '..', 'alax'))
sys.path.append(logger_path)
from logger import *

#################################################
# Prepare parameters
#################################################
AUTH_URL = 'https://identity.cluster01.lab.contoso.com:5000/v2.0'
USER_NAME = 'my-user-name'
USER_PWD = 'my-password'
PROJ_NAME = 'OPENSTACK-lab-12345-01'

num_args = len(sys.argv)
if num_args < 3:
	LOG('Error: missing parameters. Example:')
	LOG('python vm-action.py my-vm-name Reboot')
	LOG('Supported VM actions: Reboot, Start, or Stop')
	sys.exit(1)

my_server_name = sys.argv[1]
vm_action = sys.argv[2].lower()

#################################################
# Run VM actions
#################################################
loader = loading.get_plugin_loader('password')
auth = loader.load_from_options(auth_url=AUTH_URL, username=USER_NAME, password=USER_PWD, project_name=PROJ_NAME)

sess = session.Session(auth=auth)
nova = client.Client('2.0', session=sess)

# list all servers in this project/tenant
servers_list = nova.servers.list()
#print servers_list

vm_found = 0
for s in servers_list:
	if s.name == my_server_name:
		vm_found = 1
		LOG('Found the VM {0}'.format(my_server_name))
		break

if vm_found == 0:
	LOG('ERROR: The VM {0} is not found'.format(my_server_name))
	sys.exit(1)

# find my server and take action to it
my_server = nova.servers.find(name=my_server_name)
#output = my_server.get_console_output()

if vm_action == "reboot":
	LOG('Reboot VM {0} ...'.format(my_server_name))
	my_server.reboot()
elif vm_action == "start":
	LOG('Start VM {0}'.format(my_server_name))
	my_server.start()
elif vm_action == "stop":
	LOG('Stop VM {0}'.format(my_server_name))
	my_server.stop()
else:
	LOG('Unknown action. Only support: Reboot, Start, Stop')

LOG('Finished.')
