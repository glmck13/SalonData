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
	case "$data" in
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

secs=$(date --date=$REPDATE +%s)
[ "$REPDATE" != "yesterday" ] && let secs+=3600
let delta="(5-$W+7)%7"; let secs="$secs+$delta*86400"
FRIDATE=$(date --date=@$secs)

FD=$(date --date="$FRIDATE" +%d)
FM=$(date --date="$FRIDATE" +%m)
FB=$(date --date="$FRIDATE" +%b)
FY=$(date --date="$FRIDATE" +%Y)

MESSAGE="STORE:CASH:CHARGE\r"

n=-1
while true
do
	let n=$n+1; [ "$n" -ge "$NUMSTORES" ] && break

	print "${STORE[$n]}" | IFS="|" read x S P VMN VMV VPN VPV CN CV

	MESSAGE+="$S" TMPFILE=/tmp/$S

	curl -s -u $S:$P "https://www.salondata.com/$S/$FY/$FM($FB)/$FM-$FD/${S}D${M}${D}${Y#??}DAILYREP_.PDF" >$TMPFILE.pdf
	pdftotext -layout $TMPFILE.pdf - 2>/dev/null | sed -e "s/  */ /g" | egrep "Cash & Check Deposit|Total Charges|Total Deposit" | tr '\n' ' ' | read x x x x x x x CASH x x x x x CHARGE x x x x x x x x x x TOTAL x

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
