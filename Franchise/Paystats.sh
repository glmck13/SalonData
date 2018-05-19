#!/bin/ksh

print "STORE,TOTHRS,TOTPAY,TOTTIPS,FLOORH,FLOORP,ADMINH,ADMINP,RECEPTH,RECEPTP,CLOSINGH,CLOSINGP,TRAINH,TRAINP,VACH,VACP,HOLH,HOLP,BONUS,PROD,INCEN,OTX,SIXDAY,RETURN"

egrep -A 8 "Great Clips|Floor Pay|Total Hours:" | sed \
	-e "/OT Hrs/d" \
	-e "s/['a-zA-Z]\+//g" \
	-e "s/ \+/ /g" \
	-e "/[+=] /d" -e "/--/d" -e "/\//d" -e "/^,/d" -e "/ $/d" -e "/^$/d" \
	-e "s/: //" -e "s/\. //" |
while read STORE
do
	unset TOTHRS TOTPAY TOTTIPS FLOORH FLOORP ADMINH ADMINP RECEPTH RECEPTP CLOSINGH CLOSINGP TRAINH TRAINP VACH VACP HOLH HOLP BONUS PROD INCEN OTX SIXDAY RETURN

	read block; [ $(print $block | wc -w) -gt 1 ] && read block
	TOTHRS=$block

	read TOTTIPS
	read TOTPAY
	read block
	if [ $(print $block | wc -w) -le 3 ]; then
		print $block | read FLOORP HOLP OTX
		read ADMINP BONUS INCEN
		read RECEPTP FLOATP DIFFP
		read CLOSINGP SIXDAY MGRP
		read VACP PROD TOTPAY
		read TRAINP RETURN
	else
		print $block | read FLOORH FLOORP BONUS DIFFP
		read ADMINH ADMINP FLOATP MGRP
		read RECEPTH RECEPTP SIXDAY TOTPAY
		read CLOSINGH CLOSINGP PROD
		read VACH VACP RETURN
		read TRAINH TRAINP OTX
		read HOLH HOLP INCEN
	fi
	print "$STORE,$TOTHRS,$TOTPAY,$TOTTIPS,$FLOORH,$FLOORP,$ADMINH,$ADMINP,$RECEPTH,$RECEPTP,$CLOSINGH,$CLOSINGP,$TRAINH,$TRAINP,$VACH,$VACP,$HOLH,$HOLP,$BONUS,$PROD,$INCEN,$OTX,$SIXDAY,$RETURN"
done
