#!/usr/bin/python

#
# helper and utility functions
#


def GetTestTagText(testcase, tag):
	ele = testcase.getElementsByTagName(tag)
	if len(ele) == 0:
		return "NA"
	chi = ele[0].childNodes
	if len(chi) == 0:
		return "NA"
	return chi[0].data
