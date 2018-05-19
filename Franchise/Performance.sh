#!/bin/ksh

INFILE=${1:?}

exec >${INFILE%.*}.csv

print -- "STORE,STORE#,NAME,MONTH,AVGFLHR,AVGCUST,AVGHCTIME,CUTSPERHR,STNDPROD,AVGDOWNTIME,TOTNCMPH,PRODUCTIVITY,PAYROLL%,LASTMONTH,NEWCUSTRET%,RPTCUSTRET%"

egrep '%.*\$.*%|Salon' ${INFILE} | sed \
	-e "/Stylist/d" \
	-e "s/ Salon / +Salon+ /" \
	-e "s/^ \+/First Last /" \
	-e "s/\([A-Z][a-z]\+\) \([0-9]\+\) /\1-\2 /" \
	-e "s/^\([A-Za-z]\+\) \([A-Za-z]\+\) \([A-Za-z]\+\) /\3,\1-\2 /" \
	-e "s/^\([A-Za-z]\+\) \([A-Za-z-]\+\) /\2,\1 /" \
	-e "s/  */ /g" |
while read NAME DATE EOL
do
	if [[ "$DATE" == +Salon+ ]]; then
		STOREID=${EOL%% *} STORE=${EOL##* - }
		continue
	fi

	if [[ $NAME == Last,First ]]; then
		NAME=$LASTNAME
	else
		LASTNAME=$NAME
	fi

	print -- "\"$STORE\",$STOREID,\"$NAME\",$DATE,${EOL// /,}"
done
