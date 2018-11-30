#!/bin/ksh

print ${PayWeek:?} | IFS="," read WeekLo WeekMid WeekHi

COCODE="D5L"
OUTFILE=$Class-$WeekHi.csv
[ ! "$DBASE" ] && DBASE="../../DBase"

grep "^%LOGIN%|" $DBASE/EMPTAB.csv | IFS="|" read x SALONUSER x x
grep "^%PASSWORD%|" $DBASE/EMPTAB.csv | IFS="|" read x SALONPASS x x

BonusLo=12.0 BonusHi=17.0

typeset -F2 totalHours=0 regularHours=0 \
	adminHours=0 closingHours=0 floorHours=0 holidayHours=0 overtimeHours=0 personalHours=0 \
	receptionistHours=0 tipsComputedOld=0 sickHours=0 trainingHours=0 vacationHours=0 \
	ADMIN_HRS_PAY=0 CLOSE_HRS_PAY=0 FLOATING_WAGE_PAY=0 FLOOR_HRS_PAY=0 INCENTIVE_PAY_PAY=0 \
	OVERTIME_PAY=0 PRODUCT_BONUS_PAY=0 PRODUCTIVITY_PAY=0 RECEP_HRS_PAY=0 RETURN_BONUS_PAY=0 \
	SIX_DAY_BONUS_PAY=0 TRAINING_HRS_PAY=0 VACA_HRS_PAY=0 IR_PAY=0

curl -s -H "Content-Type: application/json" -H "Auth-Type: Bearer" -d @- https://spectrum.salondata.com/public/auth <<EOF | read x Name x Value x
{"username":"$SALONUSER", "password":"$SALONPASS"}
EOF

Name=${Name//\"/} Value=${Value//\"/}
eval $Name="$Value"

AvgFile=/tmp/avg$$.json
EmpFile=/tmp/emp$$.json
NameFile=/tmp/name$$.json
HoursFile=/tmp/hours$$.json
PayFile=/tmp/pay$$.json

trap "rm -f $AvgFile $EmpFile $NameFile $HoursFile $PayFile" HUP INT TERM QUIT EXIT

cat $DBASE/HEADER.csv >$OUTFILE

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" https://spectrum.salondata.com/rest/storeconfig/listx | tr '}[]' '\n' | sed -e "s/.*\"pk\"://" -e "s/,.*\"n\":\"/ /" -e "s/\".*//" | while read Store Salon
do

[ ! "$Store" ] && continue

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" "https://spectrum.salondata.com/rest/employee/reporting?storeIds=$Store&start=$WeekLo&end=$WeekHi" >$EmpFile

python <<EOF

import json

emp = {}

jfile = open("$EmpFile", "r")
report=json.load(jfile)

for r in report:
    emp[r["storeEmployees"][0]["employeeId"]] = {"last" : r["lname"], "first" : r["fname"]}

jfile = open("$NameFile", "w")
json.dump(emp, jfile)
EOF

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" "https://spectrum.salondata.com/rest/storeconfig/dailyemployee?storeConfig=$Store&date%3E=$WeekLo&date%3C=$WeekHi" >$HoursFile

python <<EOF

import json

jfile=open("$HoursFile", "r")
report=json.load(jfile)

jfile=open("$NameFile", "r")
emp=json.load(jfile)

tally = {}
avg = {}

for r in report:
    key = (r["storeConfig"]["objectId"]["idSnapshot"]["store_id"], r["employeeId"])
    strkey = str(key)

    if r["tipsComputedOld"] == None:
        r["tipsComputedOld"] = 0
    if r["tips"] == None:
        r["tips"] = 0
    if r["hcQty"] == None:
        r["hcQty"] = 0
    if r["hcSeconds"] == None:
        r["hcSeconds"] = 0
    if r["hcTime"] == None:
        r["hcTime"] = 0

    try:
        avg[strkey]
    except:
        avg[strkey] = [{"hcQty":0, "hcSeconds":0, "hcTime":0, "avg":0.0, "bonus":0}, {"hcQty":0, "hcSeconds":0, "hcTime":0, "avg":0.0, "bonus":0}]

    if r["date"] <= "$WeekMid":
        index = 0
    else:
        index = 1

    avg[strkey][index]["hcQty"] += int(r["hcQty"])
    avg[strkey][index]["hcSeconds"] += int(r["hcSeconds"])
    avg[strkey][index]["hcTime"] += int(r["hcTime"])

    try:
        tally[key]
    except:
        tally[key] = {"adminHours" : 0.0, "closingHours" : 0.0, "floorHours" : 0.0, "holidayHours" : 0.0, "personalHours" : 0.0, "receptionistHours" : 0.0, "sickHours" : 0.0, "trainingHours" : 0.0, "vacationHours" : 0.0, "tipsComputedOld" : 0.0, "~~~" : 0}

    tally[key]["adminHours"] += float(r["adminHours"])
    tally[key]["closingHours"] += float(r["closingHours"])
    tally[key]["floorHours"] += float(r["floorHours"])
    tally[key]["holidayHours"] += float(r["holidayHours"])
    tally[key]["personalHours"] += float(r["personalHours"])
    tally[key]["receptionistHours"] += float(r["receptionistHours"])
    tally[key]["sickHours"] += float(r["sickHours"])
    tally[key]["trainingHours"] += float(r["trainingHours"])
    tally[key]["vacationHours"] += float(r["vacationHours"])
    tally[key]["tipsComputedOld"] += float(r["tipsComputedOld"]) + float(r["tips"])

for t in tally.iteritems():
    for k, v in t[1].iteritems():
        print "$Salon" + "|" + emp[str(t[0][1])]["last"]+ "|" + emp[str(t[0][1])]["first"] +"|" + str(v) + "|" + k

for k, v in avg.iteritems():
    for a in v:
        if a["hcQty"] > 0:
            a["avg"] = float(a["hcTime"]*60 + a["hcSeconds"])/(a["hcQty"]*60)
        if a["avg"] >= $BonusLo and a["avg"] <= $BonusHi:
            a["bonus"] = 1
        else:
            a["bonus"] = 0

jfile = open("$AvgFile", "w")
json.dump(avg, jfile)
EOF

curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" "https://spectrum.salondata.com/rest/storeconfig/$Store/payrollweekresult?weekEnding%3E=$WeekLo&weekEnding%3C=$WeekHi" >$PayFile

python <<EOF

import json

jfile=open("$PayFile", "r")
report=json.load(jfile)

jfile=open("$NameFile", "r")
emp=json.load(jfile)

jfile=open("$AvgFile", "r")
avg=json.load(jfile)

tally = {}

for r in report:
    name = r["name"] + " PAY"
    day8 = float(r["day8"])
    store_id = r["storeConfig"]["objectId"]["idSnapshot"]["store_id"]
    employeeId = r["employeeId"]
    strkey = str((store_id, employeeId))

    if (name == "RETURN BONUS PAY"):
        if r["date"] <= "$WeekMid":
            index = 0
        else:
            index = 1
        try:
            if not avg[strkey][index]["bonus"]:
                r["totalPay"] = 0.0
        except:
            pass

    try:
        tally[(store_id, employeeId, name)]
    except:
        tally[(store_id, employeeId, name)] = 0.0

    tally[(store_id, employeeId, name)] += float(r["totalPay"])

    if (name == "OVERTIME PAY"):
        try:
            tally[(store_id, employeeId, "overtimeHours")]
        except:
            tally[(store_id, employeeId, "overtimeHours")] = 0.0

        tally[(store_id, employeeId, "overtimeHours")] += day8

for t in tally.iteritems():
    print "$Salon" + "|" + emp[str(t[0][1])]["last"] + "|" + emp[str(t[0][1])]["first"] + "|" + str(t[1]) + "|" + t[0][2]

EOF

done | while IFS="|" read Id Last First Value Name
do
	Last=${Last// /-} First=${First// /-} Name=${Name// /_}

	print $Id $Last,$First $Name $Value
done | LC_ALL=C sort | while read Id Employee Name Value
do
	if [[ "$Name" == \~* ]]; then
		let totalHours=$floorHours+$adminHours+$receptionistHours+$closingHours+$trainingHours+$vacationHours+$holidayHours
		let regularHours=$floorHours+$receptionistHours+$closingHours

		grep "^$Employee|" $DBASE/EMPTAB.csv | IFS="|" read x EMP FILE MGR

		[ "$MGR" ] && PRODUCTIVITY_PAY=0 INCENTIVE_PAY_PAY=0 SIX_DAY_BONUS_PAY=0 RETURN_BONUS_PAY=0
		let IR_PAY=$INCENTIVE_PAY_PAY+$RETURN_BONUS_PAY

		if [ ! "$EMP" ]; then
			print "$Id: $Employee not found!" >&2

		elif [ "$totalHours" -eq 0 ]; then
			:

		elif [ "$FILE" -eq 0 ]; then
			:

		else
			otHours=$overtimeHours
			[ "$otHours" -eq 0 ] && otHours=""

			print "$COCODE,$Id,$FILE,$Id,\"$EMP\",00$Id,,A,$adminHours,PSL,$vacationHours,H,$holidayHours,U,$trainingHours,,,,,,,,,,,,"
			print "$COCODE,$Id,$FILE,$Id,\"$EMP\",00$Id,,,,,,,,,,O,$PRODUCT_BONUS_PAY,V,$PRODUCTIVITY_PAY,N,$IR_PAY,D,$SIX_DAY_BONUS_PAY,,,,"
			print "$COCODE,$Id,$FILE,$Id,\"$EMP\",00$Id,$regularHours,,,,,,,,,,,,,,,,,T,$tipsComputedOld,$otHours,$OVERTIME_PAY"
		fi

		adminHours=0 closingHours=0 floorHours=0 holidayHours=0 overtimeHours=0 personalHours=0 \
			receptionistHours=0 tipsComputedOld=0 sickHours=0 trainingHours=0 vacationHours=0 \
			ADMIN_HRS_PAY=0 CLOSE_HRS_PAY=0 FLOATING_WAGE_PAY=0 FLOOR_HRS_PAY=0 INCENTIVE_PAY_PAY=0 \
			OVERTIME_PAY=0 PRODUCT_BONUS_PAY=0 PRODUCTIVITY_PAY=0 RECEP_HRS_PAY=0 RETURN_BONUS_PAY=0 \
			SIX_DAY_BONUS_PAY=0 TRAINING_HRS_PAY=0 VACA_HRS_PAY=0
	else
		eval $Name="$Value"
	fi
done >>$OUTFILE
