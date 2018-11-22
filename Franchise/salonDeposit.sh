#!/bin/ksh

SALONDATA=$HOME/etc/${QBO_SANDBOX}salonData.conf
LOGFILE=/tmp/salon.log
REPDATE=${1:-yesterday}
D=$(date --date="$REPDATE" +%d)
M=$(date --date="$REPDATE" +%m)
Y=$(date --date="$REPDATE" +%Y)
W=$(date --date="$REPDATE" +%w)

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
	ACCOUNT-BANK*)
		print $data | IFS="|" read x ABN ABV
		;;
	ACCOUNT-CASH*)
		print $data | IFS="|" read x AMN AMV
		;;
	ACCOUNT-CHARGE*)
		print $data | IFS="|" read x APN APV
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

secs=$(date --date=$REPDATE +%s)
[ "$REPDATE" != "yesterday" ] && let secs+=3600
let delta="(5-$W+7)%7"; let secs="$secs+$delta*86400"
FRIDATE=$(date --date=@$secs)

FD=$(date --date="$FRIDATE" +%d)
FM=$(date --date="$FRIDATE" +%m)
FB=$(date --date="$FRIDATE" +%b)
FY=$(date --date="$FRIDATE" +%Y)

MESSAGE="STORE:CASH:CHARGE\r"
typeset -F2 CASH CHARGE

n=-1
[ "$token" ] && while true
do
	let n=$n+1; [ "$n" -ge "$NUMSTORES" ] && break

	print "${STORE[$n]}" | IFS="|" read x S x VMN VMV VPN VPV CN CV

	MESSAGE+="${VMN:%%-*}" TMPFILE=/tmp/$S

	CASH=0 CHARGE=0

	curl -s -H "Auth-Type: Bearer" -H "Authorization: Bearer $token" https://spectrum.salondata.com/rest/storeconfig/dailytendersummary?storeConfig=$S\&date=$Y-$M-$D >$TMPFILE.json
	tr ',' '\n' <$TMPFILE.json | while read json
	do
		case $json in

		*tenderAmount*)
			json=${json//\"/} json=${json#*:}
			tenderAmount=$json
			;;

		*tenderTypeId*)
			json=${json//\"/} json=${json#*:}
			tenderTypeId=$json
			;;

		*creditCard*)
			json=${json//\"/} json=${json#*:}
			creditCard=$json
			if [ "$creditCard" = "true" ]; then
				let CHARGE=$CHARGE+$tenderAmount
			elif [ "$tenderTypeId" -le 2 ]; then
				let CASH=$CASH+$tenderAmount
			fi
			;;
		esac
	done

	>$TMPFILE.qbo

	MESSAGE+=":${CASH},"

	if [ "$CASH" -gt 0 ]; then
	# cat <<-EOF
	qbo.sh POST '/company/$QBO_REALMID/deposit' >>$TMPFILE.qbo <<-EOF
	{
	"DepositToAccountRef": { "value": "$ABV", "name": "$ABN" },
	"TxnDate": "$Y-$M-$D",
	"Line": [ { "Amount": "$CASH",
	"DetailType": "DepositLineDetail",
	"DepositLineDetail": {
	"Entity": { "value": "$VMV", "name": "$VMN", "type": "VENDOR" },
	"ClassRef": { "value": "$CV", "name": "$CN" },
	"AccountRef": { "value": "$AMV", "name": "$AMN" }
	}
	}]
	}
	EOF
	fi

	if grep "\"TotalAmt\":$CASH,.*\"$AMN\"" $TMPFILE.qbo >/dev/null 2>&1; then
		MESSAGE+="PASS"
	else
		MESSAGE+="FAIL"
	fi
		
	MESSAGE+=":${CHARGE},"

	if [ "$CHARGE" -gt 0 ]; then
	# cat <<-EOF
	qbo.sh POST '/company/$QBO_REALMID/deposit' >>$TMPFILE.qbo <<-EOF
	{
	"DepositToAccountRef": { "value": "$ABV", "name": "$ABN" },
	"TxnDate": "$Y-$M-$D",
	"Line": [ { "Amount": "$CHARGE",
	"DetailType": "DepositLineDetail",
	"DepositLineDetail": {
	"Entity": { "value": "$VPV", "name": "$VPN", "type": "VENDOR" },
	"ClassRef": { "value": "$CV", "name": "$CN" },
	"AccountRef": { "value": "$APV", "name": "$APN" }
	}
	}]
	}
	EOF
	fi

	if grep "\"TotalAmt\":$CHARGE,.*\"$APN\"" $TMPFILE.qbo >/dev/null 2>&1; then
		MESSAGE+="PASS"
	else
		MESSAGE+="FAIL"
	fi

	MESSAGE+="\r"
done

export TERM=xterm
expect >/dev/null <<EOF
set timeout 120
spawn alpine "$EMAIL"
expect "To AddrBk"
send "Salon Deposits for $M/$D/$Y\r$MESSAGE\rY"
expect "Alpine finished"
EOF
