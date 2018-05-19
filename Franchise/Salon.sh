#!/bin/ksh

exec < ${1:?}
SALONRAW=".salon.txt"
rm -f $SALONRAW

ITEMSCSV="${1%.*}-items.txt"
print "DATE|CUSTOMER|STORE|INVOICE|COUNT|ITEM|DESCRIPTION|SHIPPED|BACK-ORDER|PRICE|AMOUNT|BACKBAR" >$ITEMSCSV

TALLYCSV="${1%.*}-tally.txt"
print "DATE|CUSTOMER|STORE|INVOICE|BACKBAR|RETAIL|CLOTHING|SUB-TOTAL|FREIGHT|RETURNS|SALES-TAX" >$TALLYCSV

sed -e "/ DATE:| CUSTOMER #:| DOCUMENT #:| each | EACH | PACK | CS[0-9][0-9]* | BACKBAR:| RETAIL: | FREIGHT:| SALES TAX:| SUB-TOTAL:| RETURN ALLOW:|Maryland Clips,|^ \{38,50\}[^ ]/p" |
	sed \
	-e "s/^ \{38,50\}\([^ ].*\)/@DESC: \1/" \
	-e "s/ \*$/X/g" \
	-e "s/[\*\$]//g" \
	-e "s/^  *//" \
	-e "s/.*DOCUMENT #:/@INVOICE:/" \
	-e "s/.*DATE:/@DATE:/" \
	-e "s/.*CUSTOMER #:/@CUSTOMER:/" \
	-e "/Maryland Clips,/s/.*Clips -/@STORE: /" \
	-e "/ each /s/^/@ITEM: /" \
	-e "/ EACH /s/^/@ITEM: /" \
	-e "/ PACK /s/^/@ITEM: /" \
	-e "/ CS[0-9][0-9]* /s/^/@ITEM: /" \
	-e "/^@ITEM/s/ each / /" \
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
		[[ $ITEM == *X ]] && ITEM="${ITEM%?}|X"
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
		CLOTHING=${line#*: }
		;;
	@RETURNS:*)
		RETURNS=${line#*: }
		;;
	@SALES\ TAX:*)
		TAX=${line#*: }
		;;
	@TOTAL:*)
		print -- "$DATE|$CUSTOMER|$STORE|$INVOICE|$BACKBAR|$RETAIL|$CLOTHING|$TOTAL|$FREIGHT|$RETURNS|$TAX" >>$TALLYCSV
		unset DATE CUSTOMER STORE INVOICE BACKBAR RETAIL CLOTHING TOTAL FREIGHT RETURNS TAX
		;;
	esac
done
