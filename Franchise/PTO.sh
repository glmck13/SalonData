#!/bin/ksh

INFILE=${1:?}
PTO=${INFILE%.*}-tab.txt

print "DATE|NAME|FILE|DEPT|CODE|DESC|BA#|ALLOWED|ACCRUED|EXCESS" >$PTO
DATE=$(grep 'Date :' $INFILE | head -1 | sed -e "s/.*Date : //" -e "s/ .*//")

sed -e "/^$/d" -e "/^[ \*]/d" -e "/#/d" -e "s/ 00*\([1-9][0-9]*\)/  \1/g" -e "s/\([0-9]\) \([0-9][0-9]\)/\1.\2/g" -e "s/   */|/g" $INFILE | while read line
do
	print "$DATE|$line" >>$PTO
done
