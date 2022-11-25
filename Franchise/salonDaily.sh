#!/bin/ksh

PATH=$PWD:$HOME/bin:/usr/local/bin:$PATH

SALONDATA=$HOME/etc/${QBO_SANDBOX}salonDaily.conf
REPDATE=${1:-yesterday}
D=$(date --date="$REPDATE" +%d)
M=$(date --date="$REPDATE" +%m)
Y=$(date --date="$REPDATE" +%Y)
W=$(date --date="$REPDATE" +%w)

o2Refresh.sh

NUMSTORES=0
while read data
do
	[[ "$data" == \#* ]] && continue

	case "$data" in
	GREATCLIPS*)
		print $data | IFS="|" read x SALONUSER SALONPASS
		;;
	EMAIL*)
		print $data | IFS="|" read x EMAIL
		;;
	ACCOUNT-TIPBANK*)
		print $data | IFS="|" read x TIP_BANK_NAME TIP_BANK_VAL
		;;
	ACCOUNT-TIPENT*)
		print $data | IFS="|" read x TIP_ENT_NAME TIP_ENT_VAL
		;;
	ACCOUNT-TIPINC*)
		print $data | IFS="|" read x TIP_INC_NAME TIP_INC_VAL
		;;
	ACCOUNT-DEPBANK*)
		print $data | IFS="|" read x DEP_BANK_NAME DEP_BANK_VAL
		;;
	ACCOUNT-CASH*)
		print $data | IFS="|" read x DEP_CASH_NAME DEP_CASH_VAL
		;;
	ACCOUNT-CHARGE*)
		print $data | IFS="|" read x DEP_CHARGE_NAME DEP_CHARGE_VAL
		;;
	STORE*)
		STORE[$NUMSTORES]=${data#*|}
		let NUMSTORES=$NUMSTORES+1
		;;
	esac
done <$SALONDATA

curl -s -H "Content-Type: application/json" -H "Auth-Type: Bearer" -d @- https://spectrum.salondata.com/public/auth <<EOF | read x Name x Value x
{"username":"$SALONUSER", "password":"$SALONPASS"}
EOF

Name=${Name//\"/} Value=${Value//\"/}
eval $Name="$Value"

MESSAGE="STORE:CASH:CHARGE:TIPS\r"
typeset -F2 CASH CHARGE TIPS

TIPCMD=/tmp/qbopurchase-cmd.json TIPRSP=/tmp/qbopurchase-rsp.json TIPCOUNT=0
cat - >$TIPCMD <<-EOF
{
"PaymentType": "Check", 
"AccountRef": { "name": "$TIP_BANK_NAME", "value": "$TIP_BANK_VAL" }, 
"EntityRef": {"name": "$TIP_ENT_NAME", "value": "$TIP_ENT_VAL", "type": "VENDOR" },
"DocNumber" : "EFT", 
"TxnDate": "$Y-$M-$D",
"Line": [
EOF

n=-1
[ "$token" ] && while true
do
	let n=$n+1; [ "$n" -ge "$NUMSTORES" ] && break

	print "${STORE[$n]}" | IFS="|" read x S x VEND_CASH_NAME VEND_CASH_VAL VEND_CHARGE_NAME VEND_CHARGE_VAL CLASS_NAME CLASS_VAL

	MESSAGE+="${VEND_CASH_NAME:%%-*}" TMPFILE=/tmp/$S

	CASH=0 CHARGE=0 TIPS=0

	tries=3
	while [ "$tries" -gt 0 ]; do
	curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" https://reports.salondata.com/rest/tipexport?storeConfig=$S\&date=$Y-$M-$D >$TMPFILE-salontips.json
	[ "$(wc -c <$TMPFILE-salontips.json)" -gt 100 ] && break
	let tries=$tries-1
	sleep 3
	done

	eval $(
	python3 <<-EOF
	import json
	x=json.loads(open("$TMPFILE-salontips.json").read())
	print("TIPS={}".format(x[0]["amount"]))
	EOF
	)

	if [ "$TIPS" -gt 0 ]; then
	[ "$TIPCOUNT" -gt 0 ] && print "," >>$TIPCMD
	let TIPCOUNT=$TIPCOUNT+1
	cat - >>$TIPCMD <<-EOF
	{
	"DetailType": "AccountBasedExpenseLineDetail", 
	"Amount": $TIPS,
	"AccountBasedExpenseLineDetail": {
		"AccountRef": { "name": "$TIP_INC_NAME", "value": "$TIP_INC_VAL" },
		"ClassRef": { "name": "$CLASS_NAME", "value": "$CLASS_VAL" },
		"BillableStatus": "NotBillable"
	}
	}
	EOF
	fi

	tries=3
	while [ "$tries" -gt 0 ]; do
	curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" https://spectrum.salondata.com/rest/storeconfig/dailytendersummary?storeConfig=$S\&date=$Y-$M-$D >$TMPFILE-salontender.json
	[ "$(wc -c <$TMPFILE-salontender.json)" -gt 100 ] && break
	let tries=$tries-1
	sleep 3
	done

	eval $(
	python3 <<-EOF
	import json
	tender = json.loads(open("$TMPFILE-salontender.json", "r").read())
	cash=0
	charge=0
	for t in tender:
	    pk = t["tenderType"]["objectId"]["idSnapshot"]["tendertypepk"]
	    amt = float(t["tenderAmount"])
	    if pk == 11:
	        pass
	    elif pk == 1:
	        cash += amt
	    else:
	        charge += amt
	print("CASH={} CHARGE={}".format(cash, charge))
	EOF
	)

	>$TMPFILE-qbodeposit.json

	MESSAGE+=":${CASH},"

	if [ "$CASH" -gt 0 ]; then
	#cat >>$TMPFILE-qbodeposit.json <<-EOF
	qbo.sh POST '/company/$QBO_REALMID/deposit' >>$TMPFILE-qbodeposit.json <<-EOF
	{
	"DepositToAccountRef": { "value": "$DEP_BANK_VAL", "name": "$DEP_BANK_NAME" },
	"TxnDate": "$Y-$M-$D",
	"Line": [ { "Amount": "$CASH",
	"DetailType": "DepositLineDetail",
	"DepositLineDetail": {
	"Entity": { "value": "$VEND_CASH_VAL", "name": "$VEND_CASH_NAME", "type": "VENDOR" },
	"ClassRef": { "value": "$CLASS_VAL", "name": "$CLASS_NAME" },
	"AccountRef": { "value": "$DEP_CASH_VAL", "name": "$DEP_CASH_NAME" }
	}
	}]
	}
	EOF
	fi

	if grep "\"TotalAmt\":$CASH,.*\"$DEP_CASH_NAME\"" $TMPFILE-qbodeposit.json >/dev/null 2>&1; then
		MESSAGE+="PASS"
	else
		MESSAGE+="FAIL"
	fi
		
	MESSAGE+=":${CHARGE},"

	if [ "$CHARGE" -gt 0 ]; then
	#cat >>$TMPFILE-qbodeposit.json <<-EOF
	qbo.sh POST '/company/$QBO_REALMID/deposit' >>$TMPFILE-qbodeposit.json <<-EOF
	{
	"DepositToAccountRef": { "value": "$DEP_BANK_VAL", "name": "$DEP_BANK_NAME" },
	"TxnDate": "$Y-$M-$D",
	"Line": [ { "Amount": "$CHARGE",
	"DetailType": "DepositLineDetail",
	"DepositLineDetail": {
	"Entity": { "value": "$VEND_CHARGE_VAL", "name": "$VEND_CHARGE_NAME", "type": "VENDOR" },
	"ClassRef": { "value": "$CLASS_VAL", "name": "$CLASS_NAME" },
	"AccountRef": { "value": "$DEP_CHARGE_VAL", "name": "$DEP_CHARGE_NAME" }
	}
	}]
	}
	EOF
	fi

	if grep "\"TotalAmt\":$CHARGE,.*\"$DEP_CHARGE_NAME\"" $TMPFILE-qbodeposit.json >/dev/null 2>&1; then
		MESSAGE+="PASS"
	else
		MESSAGE+="FAIL"
	fi

	MESSAGE+=":${TIPS}"
	MESSAGE+="\r"
done

print "]\n}" >>$TIPCMD
[ "$TIPCOUNT" -gt 0 ] && qbo.sh POST '/company/$QBO_REALMID/purchase' <$TIPCMD >$TIPRSP

SUBJECT="Salon Deposits for $M/$D/$Y"

#echo "$EMAIL" "$SUBJECT" "$MESSAGE"
sendaway.sh "$EMAIL" "$SUBJECT" "$MESSAGE"
