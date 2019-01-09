#!/usr/bin/python

import keystoneclient.v2_0.client as ksclient

auth_url  = "https://identity.cluster01.lab.contoso.com:5000/v2.0"
user_name = "my-user-name"
user_pwd  = "my-user-password"
tenant_name = "OPENSTACK-lab-12345-01"

keystone = ksclient.Client(auth_url=auth_url, username=user_name, password=user_pwd, tenant_name=tenant_name)
auth_ref = keystone.auth_ref

print auth_ref
