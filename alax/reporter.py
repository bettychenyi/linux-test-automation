#!/usr/bin/python

#
# manage alax test reporting, including email reports.
#


import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart


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
