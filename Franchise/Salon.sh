#!/bin/ksh

exec < ${1:?}
SALONRAW=".salon.txt"
rm -f $SALONRAW

ITEMSCSV="${1%.*}-items.txt"
print "DATE|CUSTOMER|STORE|INVOICE|COUNT|ITEM|DESCRIPTION|SHIPPED|BACK-ORDER|PRICE|AMOUNT|BACKBAR" >$ITEMSCSV

TALLYCSV="${1%.*}-tally.txt"
print "DATE|CUSTOMER|STORE|INVOICE|BACKBAR|RETAIL|CLOTHING|SUB-TOTAL|FREIGHT|RETURNS|SALES-TAX|ORDERED-BY" >$TALLYCSV

grep -E -A1 " DATE:| CUSTOMER #:| DOCUMENT #:| each | Each [0-9]| EACH | PACK | CS[0-9][0-9]* | BACKBAR:| RETAIL: | FREIGHT:| SALES TAX:| ORDERED BY | TOTAL:| SUB-TOTAL:| RETURN ALLOW:|Bay Clips,|^ \{38,50\}[^ ]" |
	sed \
	-e "s/^ \{38,50\}\([^ ].*\)/@DESC: \1/" \
	-e "s/ \*$/X/g" \
	-e "s/[\*\$]//g" \
	-e "s/^  *//" \
	-e "s/.*DOCUMENT #:/@INVOICE:/" \
	-e "s/.*DATE:/@DATE:/" \
	-e "s/.*CUSTOMER #:/@CUSTOMER:/" \
	-e "/Bay Clips,/s/.*Clips -/@STORE: /" \
	-e "/ each /s/^/@ITEM: /" \
	-e "/ Each /s/^/@ITEM: /" \
	-e "/ EACH /s/^/@ITEM: /" \
	-e "/ PACK /s/^/@ITEM: /" \
	-e "/ CS[0-9][0-9]* /s/^/@ITEM: /" \
	-e "/^@ITEM/s/ each / /" \
	-e "/^@ITEM/s/ Each / /" \
	-e "/^@ITEM/s/ EACH / /" \
	-e "/^@ITEM/s/ PACK / /" \
	-e "/^@ITEM/s/ CS[0-9][0-9]* / /" \
	-e "/^@ITEM/s/   */|/g" \
	-e "s/.*BACKBAR:/@BACKBAR:/" \
	-e "s/.*RETAIL:/@RETAIL:/" \
	-e "s/.*RETURN ALLOW:/@RETURNS:/" \
	-e "s/SUB-TOTAL:/^@&/" \
	-e "s/FREIGHT:/^@&/" \
	-e "s/CLOTHING:/^@&/" \
	-e "s/^TOTAL:/^@&/" \
	-e "s/SALES TAX:/^@&/" \
	-e "/SALES TAX/s/^/@CLOTHING: /" |
	tr '^' '\n' | tr -s ' ' | tee $SALONRAW |
while read line
do
	case "$line" in
	@INVOICE:*)
		INVOICE=${line#*: }
		;;
	@DATE:*)
		DATE=${line#*: }
		;;
	@CUSTOMER:*)
		CUSTOMER=${line#*: }
		;;
	@STORE:*)
		STORE=${line#*: }
		;;
	@ITEM:*)
		ITEM=${line#*: }
		if [[ $ITEM == -* ]]; then
			ITEM=$(print -- $ITEM | sed -e "s/\(.*\)|\([-0-9\.]*|[-0-9\.]*X*\)$/\1|||\2/")
		fi
		if [ ! "$(print -- "$ITEM" | cut -f7 -d'|')" ]; then
			read line
			if [[ $line == @DESC:* ]]; then
				ITEM="$(print -- $ITEM | cut -f1-2 -d'|')|${line#*: }|$(print -- $ITEM | cut -f3-6 -d'|')"
			else
				print "No Description!" >&2
			fi
		fi
		#[[ $ITEM == *X ]] && ITEM="${ITEM%?}|X"
		print -- "$DATE|$CUSTOMER|$STORE|$INVOICE|$ITEM" >>$ITEMSCSV
		;;
	@BACKBAR:*)
		BACKBAR=${line#*: }
		;;
	@SUB-TOTAL:*)
		TOTAL=${line#*: }
		;;
	@RETAIL:*)
		RETAIL=${line#*: }
		;;
	@FREIGHT:*)
		FREIGHT=${line#*: }
		;;
	@CLOTHING:*)
		line=${line#*: }
		[[ ${line} && ${line} != @* ]] && CLOTHING=${line}
		;;
	@RETURNS:*)
		RETURNS=${line#*: }
		;;
	@SALES\ TAX:*)
		TAX=${line#*: }
		;;
	ORDERED\ BY\ *)
		read line; line=${line% UPS GROUND *} line=${line% DO NOT SHIP *} line=${line% *}
		ORDERED=${line}
		;;
	@TOTAL:*)
		print -- "$DATE|$CUSTOMER|$STORE|$INVOICE|$BACKBAR|$RETAIL|$CLOTHING|$TOTAL|$FREIGHT|$RETURNS|$TAX|$ORDERED" >>$TALLYCSV
		unset DATE CUSTOMER STORE INVOICE BACKBAR RETAIL CLOTHING TOTAL FREIGHT RETURNS TAX ORDERED
		;;
	esac
done
