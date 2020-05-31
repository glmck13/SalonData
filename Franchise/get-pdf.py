#!/usr/bin/python

import cgi, os, sys
import cgitb; cgitb.enable()

form = cgi.FieldStorage()
fileitem = form['pdffile']

if fileitem.filename:
   fn = sys.argv[1] + '/' + os.path.basename(fileitem.filename)
   fn = fn.replace(' ', '_')
   open(fn, 'wb').write(fileitem.file.read())
else:
   fn = ""

print(os.path.basename(fn))
