#!/bin/ksh

PATH=$PWD:$PATH
export DBASE=Payroll/DBase; cd $DOCUMENT_ROOT/$DBASE
export EMPTAB=EMPTAB.csv
export TMPTAB=/tmp/tab$$

trap "rm -f $TMPTAB" HUP INT QUIT TERM EXIT

exec 2>&1

print "Content-type: text/html\\n\\n"
print "<html>"

vars=$QUERY_STRING
while [ "$vars" ]
do
	print $vars | IFS='&' read v vars
	v=$(/bin/echo -e $(print $v | sed \
		-e "s/+/ /g" \
		-e "s/%\(..\)/\\\\x\1/g" \
		-e "s/=/&\"/" \
		-e "s/$/\"/"))
	eval export $v
done

if [ ! "$QUERY_STRING" ]; then

	print "<table border=1><tr><th>Employee Name</th><th>ADP Name</th><th>File #</th><th>Mgr Code</th></tr>"

	while IFS="|" read ename aname fileno mgr
	do
		print "<tr><td>$ename</td><td>$aname</td><td>$fileno</td><td>$mgr</td></tr>"
	done <$EMPTAB

	print "</table>"

elif [[ $Command == Add* ]]; then

	print "<pre>"

	if [ ! "$Fileno" ]; then
		print "Must enter a File #"
	elif [ ! "$Ename" ]; then
		print "Must enter an Employee Name"
	elif [ ! "$Aname" ]; then
		print "Must enter an ADP Name"
	elif [ "$Mgr" -a "$Mgr" != "M" ]; then
		print "Invalid Mgr value"
	else
		(print "$Ename|$Aname|$Fileno|$Mgr"; cat $EMPTAB) |
			sort -k1 -t'|' >$TMPTAB; cp $TMPTAB $EMPTAB
		print "Employee $Ename added"
	fi

	print "</pre>"

elif [[ $Command == Delete* ]]; then

	print "<pre>"

	grep "|$Fileno|" $EMPTAB >/dev/null

	if [ $? -ne 0 ]; then
		print "Employee(s) with File #$Fileno not found"
	else
		grep -v "|$Fileno|" $EMPTAB |
			sort -k1 -t'|' >$TMPTAB; cp $TMPTAB $EMPTAB
		print "Employee(s) with File #$Fileno deleted"
	fi

	print "</pre>"
fi

print "</html>"
