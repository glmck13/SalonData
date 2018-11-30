#!/bin/ksh

MenuItems=5

(( secshi = $(date +%s) + ((5-$(date +%w)+7) % 7)*86400 ))

n=$MenuItems
print "<select name=\"PayWeek\">"
while (( --n >= 0 ))
do
	hi=$(date --date=@$secshi "+%Y-%m-%d")

	(( secslo = secshi-6*86400+3600 ))
	secslo=$(date --date=$(date --date=@$secslo "+%Y-%m-%d") "+%s")
	lo=$(date --date=@$secslo "+%Y-%m-%d")

	(( secshi = secshi-7*86400+3600 ))
	secshi=$(date --date=$(date --date=@$secshi "+%Y-%m-%d") "+%s")

	print "<option value=\"$lo,$hi\">$hi</option>"
done
print "</select>"
