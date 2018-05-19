#!/bin/ksh

INFILE=${1:?}
FEESCSV=${INFILE%.*}.csv

exec <$INFILE

egrep -A1 "Printed on|%|Ending" | egrep -v "Printed on|%|--|^$" | sed -e "s/.* //g" |
while true
do
	read STORE || break
	read DATE || break
	read FEEFRAN || break
	read FEEAD || break
	print $STORE,$DATE,$FEEFRAN,$FEEAD
done | sort | uniq >$FEESCSV
