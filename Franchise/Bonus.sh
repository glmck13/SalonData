#!/bin/ksh

print ${PayWeek:?} | IFS="," read WeekLo WeekHi

OUTFILE=$Class-$WeekHi.csv
[ ! "$DBASE" ] && DBASE="../../DBase"

grep "^%LOGIN%|" $DBASE/EMPTAB.csv | IFS="|" read x SALONUSER x x
grep "^%PASSWORD%|" $DBASE/EMPTAB.csv | IFS="|" read x SALONPASS x x

curl -s -H "Content-Type: application/json" -H "Auth-Type: Bearer" -d @- https://spectrum.salondata.com/public/auth <<EOF | read x Name x Value x
{"username":"$SALONUSER", "password":"$SALONPASS"}
EOF

Name=${Name//\"/} Value=${Value//\"/}
eval $Name="$Value"

StatsFile=/tmp/stats$$.json

trap "rm -f $StatsFile" HUP INT TERM QUIT EXIT

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" https://spectrum.salondata.com/rest/storeconfig/listx | tr '}[]' '\n' | sed -e "s/.*\"pk\"://" -e "s/,.*\"n\":\"/ /" -e "s/\".*//" | while read Store Salon
do

[ ! "$Store" ] && continue

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" "https://spectrum.salondata.com/rest/storeconfig/dailystoresummary?storeConfig=$Store&date%3E=$WeekLo&date%3C=$WeekHi" >$StatsFile

python <<EOF

import json

jfile=open("$StatsFile", "r")
report=json.load(jfile)

tally = {"productSales" : 0, "serviceSales" : 0, "adminPay" : 0, "bonusPay" : 0, "closingPay" : 0, "floorPay" : 0, "holidayPay" : 0, "overtimePay" : 0, "receptionistPay" : 0, "trainingPay" : 0, "vacationPay" : 0, "customerCount" : 0}

for r in report:
    tally["customerCount"] += int(r["customerCount"])
    tally["productSales"] += float(r["productSales"])
    tally["serviceSales"] += float(r["serviceSales"])
    tally["adminPay"] += float(r["adminPay"])
    tally["bonusPay"] += float(r["bonusPay"])
    tally["closingPay"] += float(r["closingPay"])
    tally["floorPay"] += float(r["floorPay"])
    tally["holidayPay"] += float(r["holidayPay"])
    tally["overtimePay"] += float(r["overtimePay"])
    tally["receptionistPay"] += float(r["receptionistPay"])
    tally["trainingPay"] += float(r["trainingPay"])
    tally["vacationPay"] += float(r["vacationPay"])

totalSales = tally["productSales"] + tally["serviceSales"]

totalPay = tally["adminPay"] + tally["bonusPay"] + tally["closingPay"] + tally["floorPay"] + tally["holidayPay"] + tally["overtimePay"] + tally["receptionistPay"] + tally["vacationPay"] # + tally["trainingPay"]

percentPayroll = totalPay/totalSales*100

print "{},{:.2f},{},{:.2f},{:.1f}%".format("$Salon", totalSales, tally["customerCount"], totalPay, percentPayroll)
EOF

done >$OUTFILE
