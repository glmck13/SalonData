#!/bin/ksh

MenuItems=5
Seed=2018-11-02

secs=$(date "+%s")
secshi=$(date --date="$Seed" "+%s")
secslo=$secshi

while true
do
	(( secs <= secshi )) && break
	(( secshi += 14*86400+3600 ))
	secshi=$(date --date=$(date --date=@$secshi "+%Y-%m-%d") "+%s")
done

n=$MenuItems

print "<select name=\"PayWeek\">"
while (( --n >= 0 ))
do
	hi=$(date --date=@$secshi "+%Y-%m-%d")

	(( secsmid = secshi-7*86400+3600 ))
	secsmid=$(date --date=$(date --date=@$secsmid "+%Y-%m-%d") "+%s")
	mid=$(date --date=@$secsmid "+%Y-%m-%d")

	(( secslo = secsmid-6*86400+3600 ))
	secslo=$(date --date=$(date --date=@$secslo "+%Y-%m-%d") "+%s")
	lo=$(date --date=@$secslo "+%Y-%m-%d")

	(( secshi = secsmid-7*86400+3600 ))
	secshi=$(date --date=$(date --date=@$secshi "+%Y-%m-%d") "+%s")

	print "<option value=\"$lo,$mid,$hi\">$hi</option>"
done
print "</select>"
