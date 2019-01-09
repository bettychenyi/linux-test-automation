#!/usr/bin/python

#
# manage the alax logs
#

from datetime import datetime


log_filename = "./_alax-{0}.log".format(str(datetime.now().strftime('%Y_%m_%d_%H_%M_%S')))


def LOG(message):
	message_line = str(datetime.now().strftime('%Y-%m-%d %H:%M:%S')) + ": " + message
	print message_line
	# write this log into file, with "append" mode
	with open(log_filename, 'a') as f:
		f.write(message_line + "\n")
