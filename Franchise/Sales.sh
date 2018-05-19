#!/bin/ksh

SALESRAW=".sales.txt"
rm -f $SALESRAW
INFILE=${1:?}
SALESCSV=${INFILE%.*}.csv
ed $INFILE <<EOF >/dev/null 2>&1
g/Version.*Printed/.,.+1 d
g/^$/d
w $SALESRAW
q
EOF

exec <$SALESRAW >$SALESCSV

processLine () {

	case ${EOL// /_} in

	PRODUCTS_REPORT*)
		read STORE; STORENO=${STORE##* }; STORE=${STORE% $STORENO} STORE=${STORE// /_}
		read STARTDATE x STOPDATE
		read EOL
		read EOL; CATEGORY=${EOL// /_}
		read EOL; PRODUCT=${EOL// /_}
		;;

	Total*)
		print -- "${EOL#*% }" | read COMPARE x
		read EOL
		[[ ${EOL// /_} == $CATEGORY ]] && read EOL
		[[ ${EOL// /_} == $CATEGORY ]] && read EOL

		if [[ $EOL == Category\ Total* ]]; then

			print -- "${EOL#*% }" | read COMPARE x
			read EOL
			[[ ${EOL// /_} == $CATEGORY ]] && read EOL
			[[ ${EOL// /_} == $CATEGORY ]] && read EOL

			if [[ $EOL == Grand\ Total* ]]; then

				print -- "${EOL#*% }" | read COMPARE x

				[ $GRANDTOT -ne $COMPARE ] && print "$STORE: $GRANDTOT != $COMPARE" >&2
				GRANDTOT=0 CATTOT=0 PRODTOT=0

				STORE=""
				while read EOL
				do
					[[ ${EOL// /_} == PRODUCTS_REPORT ]] && break
				done
			else
				[ $CATTOT -ne $COMPARE ] && print "$STORE, $CATEGORY: $CATTOT != $COMPARE" >&2
				CATTOT=0 PRODTOT=0

				CATEGORY=${EOL// /_}
				read EOL
				[[ ${EOL// /_} == $CATEGORY ]] && read EOL
				[[ ${EOL// /_} == $CATEGORY ]] && read EOL
				PRODUCT=${EOL// /_}
			fi
		else
			[ $PRODTOT -ne $COMPARE ] && print "$STORE, $CATEGORY, $PRODUCT: $PRODTOT != $COMPARE" >&2
			PRODTOT=0

			PRODUCT=${EOL// /_}
		fi
		;;

	Num*Prod*Inv*)
		;;

	Sold*Num*Description*)
		;;

	$PRODUCT)
		;;

	$CATEGORY)
		read EOL; PRODUCT=${EOL// /_}
		;;

	[0-9]*%*%*%*)
		print -- "${EOL#*.*% }" | read COMPARE x
		(( PRODTOT += $COMPARE ))
		(( CATTOT += $COMPARE ))
		(( GRANDTOT += $COMPARE ))
		print "$STARTDATE,$STOPDATE,$STORE,$STORENO,$CATEGORY,$PRODUCT,${EOL//,/_}"
		;;

	esac
}

PRODTOT=0 CATTOT=0 GRANDTOT=0

print -- "STARTDATE,STOPDATE,STORE,STORE#,CATEGORY,PRODUCT,COUNT,ITEM#,DESCRIPTION,INVCOST,RETAIL,AVGSALE,AVGDISC,AVGDISC%,SALESTOT,COST,MARGIN,GM%,TOT%"

read EOL
while true
do
	processLine
	if [[ $EOL != PRODUCTS\ REPORT ]]; then
		read EOL || exit
	fi
done | sed -e "s/  *oz /oz /g" -e "s/oz \([0-9\.]\)/oz  \1/" -e "s/   */|/g" -e "s/%//g" -e "s/|/,/" -e "s/ /,/" -e "s/$/^/" | tr "|" "\n" | sed -e "/,.*,/s/ /_/g" -e "s/  */,/g" | tr "\n^" ",\n" | sed -e "s/^,//"
