#!/usr/bin/env python

#
# get openstack login credentials from system environment variables
#

import os
 
def get_keystone_creds():
	d = {}
	d['version'] = '2.0'
	d['username'] = os.environ['OS_USERNAME']
	d['password'] = os.environ['OS_PASSWORD']
	d['auth_url'] = os.environ['OS_AUTH_URL']
	d['tenant_name'] = os.environ['OS_TENANT_NAME']
	return d
 
def get_nova_creds():
	d = {}
	d['version'] = '2.0'
	d['username'] = os.environ['OS_USERNAME']
	d['api_key'] = os.environ['OS_PASSWORD']
	d['auth_url'] = os.environ['OS_AUTH_URL']
	d['project_id'] = os.environ['OS_TENANT_NAME']
	return d
