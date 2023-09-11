#!/bin/ksh

alias python=python3

print ${PayWeek:?} | IFS="," read WeekLo WeekMid WeekHi
Today=$(date "+%Y-%m-%d")

PAYFILE=pay$$.csv; >$PAYFILE
PIDFILE=pid$$.csv; >$PIDFILE
[ ! "$DBASE" ] && DBASE="../../DBase"

grep "^%LOGIN%|" $DBASE/EMPTAB.csv | IFS="|" read x SALONUSER x x
grep "^%PASSWORD%|" $DBASE/EMPTAB.csv | IFS="|" read x SALONPASS x x

curl -s -H "Content-Type: application/json" -H "Auth-Type: Bearer" -d @- https://spectrum.salondata.com/public/auth <<EOF | read x Name x Value x
{"username":"$SALONUSER", "password":"$SALONPASS"}
EOF

Name=${Name//\"/} Value=${Value//\"/}
eval $Name="$Value"

StoreConfig=$(curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" https://spectrum.salondata.com/rest/storeconfig/listx | sed -e "s/'/\\\&/g")
python <<EOF | while read Store Salon
import sys, json
list = json.loads('$StoreConfig')
for item in list:
	print(item["pk"], item["n"])
EOF
do

[ ! "$Store" ] && continue

echo "#$Salon $Store" >>$PAYFILE

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" -H 'Content-Type: application/json' -d@- https://cron.salondata.com/rest/reportusage <<-EOF >/dev/null
{"report":"Payroll Consolidated", "date":"$Today", "endDate":"$WeekHi", "startDate":"$WeekLo", "stores":["$Salon"]}
EOF

curl -s "https://reports.salondata.com/rest/payrollweekresult/consolidated.csv?stores=$Store&start=$WeekLo&end=$WeekHi&token=$token" >>$PIDFILE

curl -s "https://reports.salondata.com/rest/payrollweekresult/adp?stores=$Store&date=$WeekHi&token=$token" >>$PAYFILE

done

typeset -A emptab
sort $PIDFILE | uniq | while IFS='"' read x name x x x x x payid x
do
	emptab[$payid]="$name"
done

rm -f $Class-*-$WeekHi.csv
outfile="" header="" code=""

while read line
do
	if [[ $line == \#* ]]; then
		line=${line#?} Salon=${line% *} Store=${line#* }
		continue
	fi

	if [[ $line == Co\ Code* ]]; then
		if [ ! "$header" ]; then
			header=${line/File \#/File \#,Batch Description,Employee Name}
		fi
		continue
	fi

	line=$line loop=$header,
	while [ "$loop" ]
	do
		field=${loop%%,*} loop=${loop#*,}
		if [ "$field" = "Co Code" ]; then
			val=${line%%,*} line=${line#*,} lval="$val"
			if [ "$code" != "$val" ]; then
				code=$val
				outfile=$Class-$code-$WeekHi.csv
				if [ ! -f $outfile ]; then
					echo "$header" >$outfile
				fi
			fi
			echo -n "$val" >>$outfile
		elif [ "$field" = "Batch Id" ]; then
			val=${line%%,*} line=${line#*,} lval="$val"
			echo -n ",$Salon" >>$outfile
		elif [ "$field" = "Batch Description" ]; then
			echo -n ",$Salon" >>$outfile
		elif [ "$field" = "Employee Name" ]; then
			echo -n ",\"${emptab[$lval]}\"" >>$outfile
		else
			val=${line%%,*} line=${line#*,} lval="$val"
			echo -n ",$val" >>$outfile
		fi
	done
	echo >>$outfile
done <$PAYFILE

rm -f $PAYFILE $PIDFILE
