#!/bin/ksh

Token ()
{
	if [ "$CONSUMED" = "Y" ]; then
		let PAYLINE=$PAYLINE+1; CONSUMED="N"
		read TOKEN
	else
		return 0
	fi
}

LookupEmployee ()
{
	grep "^$NAME|" $DBASE/EMPTAB.csv | IFS="|" read x EMP FILE MGR
}

ProcessEmployee ()
{
	print "$TOKEN" | IFS="|" read INFO PAYID REGHRS
#	[[ ${INFO#* } != Ded* ]] && INFO=${INFO#* }
#	print "$INFO" | read NAME x POSITION x WAGE x INS
	NAME=${INFO% Ded.*}; INFO=${INFO#*Ded.}
	print "$INFO" | read x POSITION x WAGE x INS

	CONSUMED="Y"; Token; print "$TOKEN" |
		read x TAIL
	if [[ $x == ID || $x == +([0-9]) ]]; then
		[ "$TAIL" ] && REGHRS=${TAIL#* }
		CONSUMED="Y"; Token
	fi

	print "$TOKEN" |
		read x OTHRS
	if [ "$x" != "OT-Hrs" ]; then
		print "$PAYLINE: $STORE: $NAME OT-Hrs error!" >&2
		exit 1
	fi

	CONSUMED="Y"; Token; print "$TOKEN" |
		read FLOORH ADMINH RECEPTH CLOSINGH VACH HOLH TRAINH

	CONSUMED="Y"; Token; print "$TOKEN" |
		read FLOORP ADMINP RECEPTP CLOSINGP TAIL

	VACP="0" HOLP="0"
	[ "$VACH" != "0.00" ] && print $TAIL | read VACP TAIL
	[ "$HOLH" != "0.00" ] && print $TAIL | read HOLP TAIL
	print $TAIL | read TRAINP BONUS PROD INCEN OTX SIXDAY RETURN OTHER TOTPAY
	if [ ! "$TOTPAY" ]; then
		print $TRAINH | read TRAINH x
		print $TAIL | read TRAINP BONUS INCEN OTX SIXDAY RETURN OTHER TOTPAY
		unset PROD
	fi

	CONSUMED="Y"; Token; print "$TOKEN" |
		read x x USERID
	if [ "$x" != "ID:" ]; then
		print "$PAYLINE: $STORE: $NAME User ID error!" >&2
		exit 1
	fi
	if [ ! "$PROD" ]; then
		print $USERID | read USERID x PROD x
	fi

	Cash="0" Check="0" Charge="0" TotTips="0" TotHrs="0"
	CONSUMED="Y"; Token
	while [ "$TOKEN" ]
	do
		print "$TOKEN" | read VAR VAL TAIL
		eval $VAR=$VAL
		TOKEN=$TAIL
	done
	CONSUMED="Y"

	EMP="" FILE="" MGR="" LookupEmployee
	if [ ! "$EMP" ]; then
		print "$STORE: $NAME not found!" >&2
	fi

	let _TOTHRS=$FLOORH+$ADMINH+$RECEPTH+$CLOSINGH+$TRAINH #+$VACH+$HOLH
	if [ "$_TOTHRS" -ne "$TotHrs" ]; then
		print "$NAME TOTHRS error: $_TOTHRS != $TotHrs" >&2
	fi

	let _TOTHRS=$FLOORH+$ADMINH+$RECEPTH+$CLOSINGH+$TRAINH
	let _ALLHRS="$REGHRS+${OTHRS:-0}"
	if [ "$_TOTHRS" -ne "$_ALLHRS" ]; then
		print "$NAME ALLHRS error: $_TOTHRS != $_ALLHRS" >&2
	fi

	let _TOTPAY=$FLOORP+$ADMINP+$RECEPTP+$CLOSINGP+$TRAINP+$VACP+$HOLP+$BONUS+$PROD+$INCEN+$OTX+$SIXDAY+$RETURN+$OTHER
	if [ "$_TOTPAY" -ne "$TOTPAY" ]; then
		print "$NAME TOTPAY error: $_TOTPAY != $TOTPAY" >&2
	fi

	let _TOTTIPS=$Cash+$Check+$Charge
	if [ "$_TOTTIPS" -ne "$TotTips" ]; then
		print "$NAME TOTTIPS error: $_TOTTIPS != $TotTips" >&2
	fi

	let _TOTHRS=$FLOORH+$ADMINH+$RECEPTH+$CLOSINGH+$TRAINH+$VACH+$HOLH

	let REGH=$FLOORH+$RECEPTH+$CLOSINGH; _REGH=$REGH
	# [ "$_REGH" = "0.00" ]   && _REGH=""
	# [ "$ADMINH" = "0.00" ] && ADMINH=""
	# [ "$VACH" = "0.00" ]   && VACH=""
	# [ "$HOLH" = "0.00" ]   && HOLH=""
	# [ "$TRAINH" = "0.00" ] && TRAINH=""
	# [ "$BONUS" = "0.00" ]  && BONUS=""
	# [ "$PROD" = "0.00" ]   && PROD=""
	# [ "$INCEN" = "0.00" ]  && INCEN=""
	# [ "$SIXDAY" = "0.00" ] && SIXDAY=""
	# [ "$RETURN" = "0.00" ] && RETURN=""
	# [ "$OTHRS" = "0.00" ]  && OTHRS=""
	# [ "$OTX" = "0.00" ]    && OTX=""
	# [ "$TotTips" = "0" ]   && TotTips=""

	case "$MODE" in

	BATCH)
	[ "$MGR" ] && PROD="0.00" INCEN="0.00" SIXDAY="0.00" RETURN="0.00"
	# [ ! "$_REGH" ] && return
	[ "$_TOTHRS" -eq 0 ] && return
	[ "$FILE" -eq 0 ] && return
#	print "$COCODE,$STORENO,$FILE,$STORENO,\"$EMP\",\"00$STORENO\",,A,$ADMINH,PSL,$VACH,H,$HOLH,U,$TRAINH"
#	print "$COCODE,$STORENO,$FILE,$STORENO,\"$EMP\",\"00$STORENO\",,,,,,,,,,O,$BONUS,V,$PROD,N,$INCEN,D,$SIXDAY"
#	print "$COCODE,$STORENO,$FILE,$STORENO,\"$EMP\",\"00$STORENO\",$_REGH,,,,,,,,,,,,,,,,,T,$TotTips,$OTHRS,$OTX"
	let _INCEN=$INCEN+$RETURN
	print "$COCODE,$STORENO,$FILE,$STORENO,\"$EMP\",00$STORENO,,A,$ADMINH,PSL,$VACH,H,$HOLH,U,$TRAINH,,,,,,,,,,,,"
	print "$COCODE,$STORENO,$FILE,$STORENO,\"$EMP\",00$STORENO,,,,,,,,,,O,$BONUS,V,$PROD,N,$_INCEN,D,$SIXDAY,,,,"
	print "$COCODE,$STORENO,$FILE,$STORENO,\"$EMP\",00$STORENO,$_REGH,,,,,,,,,,,,,,,,,T,$TotTips,$OTHRS,$OTX"
	;;

	STATS)
	print "\"$NAME\",$STORENO,$_TOTHRS,$TOTPAY,$_TOTTIPS,$FLOORH,$FLOORP,$ADMINH,$ADMINP,$RECEPTH,$RECEPTP,$CLOSINGH,$CLOSINGP,$TRAINH,$TRAINP,$VACH,$VACP,$HOLH,$HOLP,$BONUS,$PROD,$INCEN,$OTX,$SIXDAY,$RETURN"
	;;

	esac
}

ProcessStore ()
{
	Token; STORE=$TOKEN; STORENO=${STORE##* }; CONSUMED="Y"
	Token; print "$TOKEN" | read x x x x STARTDATE x ENDDATE; CONSUMED="Y"
	while Token
	do
		if [ "$TOKEN" != "Great Clips" ]; then
			CONSUMED="Y"; ProcessEmployee
		else
			break
		fi
	done
}

[ ! "$MODE" ] && MODE="BATCH"
[ ! "$DBASE" ] && DBASE="./DBase"

CONSUMED="Y" TOKEN="" PAYLINE=0

COCODE="D5L"
typeset -F2 REGH

case "$MODE" in
	BATCH)
		cat $DBASE/HEADER.csv
		;;
	STATS)
		print "NAME,STORE,TOTHRS,TOTPAY,TOTTIPS,FLOORH,FLOORP,ADMINH,ADMINP,RECEPTH,RECEPTP,CLOSINGH,CLOSINGP,TRAINH,TRAINP,VACH,VACP,HOLH,HOLP,BONUS,PROD,INCEN,OTX,SIXDAY,RETURN"
		;;
esac

sed -e "s/  */ /g" -e "s/^  *//" -e "s/, /,/" -e "s/ Ins \([0-9][0-9]*\) / Ins \1 | /" -e "s/ Pay ID//" -e "s/ Reg Hrs/ |/" -e "s/^OT Hrs/OT-Hrs/" -e "s/Tot Hrs/TotHrs/" -e "s/^Tips: //" -e "s/Total Tips /TotTips /" -e "s/ Bonus tivity.*//" -e "/^$/d" |
egrep -v "^BIWEEKLY PAYROLL |^Floor Admin Recept Closing |^Total Hours: |^Total Tips: |^Payroll Total |^= = |^Service Sales |^Salon average |^Version |^Floor Pay |^Admin Pay |^Recep Pay |^Closing Pay |^Vacation Pay |^Training Pay |^Floor Hrs |^Admin Hrs |^Recep Hrs |^Closing Hrs |^Vacation Hrs |^Training Hrs |^Holiday Hrs |^Week Ending | had Productivity of | had Product % of | worked " | tee .payroll |
while Token
do
# print "$TOKEN"; CONSUMED="Y"
	if [ "$TOKEN" = "Great Clips" ]; then
		CONSUMED="Y"; ProcessStore
	else
		break
	fi
done # | grep -v ",,,,,,,,,,,,$"

case "$MODE" in
	BATCH)
		cat $DBASE/TRAILER.csv
		;;
esac
