#!/usr/bin/env python3

import sys, smtplib, ssl
from email.message import EmailMessage

try:
	Addresses = sys.argv[1]
	Subject = sys.argv[2]
	Message = sys.argv[3]
except:
	print("Usage: {} addresses subject message [attachment]".format(sys.argv[0]))
	exit()

Attachment = None
if len(sys.argv) > 4:
	Attachment = sys.argv[4]

SMTP_FROM = ""
SMTP_KEY = ""
SMTP_SERVER = ""
SMTP_PORT = 465

eml = EmailMessage()
eml.set_content(Message.encode("utf-8").decode("unicode_escape"))
eml['Subject'] = Subject
eml['From'] = SMTP_FROM
eml['To'] = Addresses

if Attachment:
	with open(Attachment, 'rb') as fp:
		filename = Attachment.split('/')
		filename = filename[len(filename)-1]
		eml.add_attachment(fp.read(), maintype="application", subtype="octect-stream", filename=filename)

context = ssl.create_default_context()
with smtplib.SMTP_SSL(SMTP_SERVER, SMTP_PORT, context=context) as server:
    server.login(SMTP_FROM, SMTP_KEY)
    server.send_message(eml)
