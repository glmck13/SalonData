#!/bin/ksh

INFILE=${1:?}
MINCUT=${INFILE%.*}-tab.txt

exec <$INFILE

print "STORE|DATE|NAME|MINCUT|RETURNBONUS|BONUS%" >$MINCUT

Buffer="" Bonus="" Percent=""

sed -e "s/ \+/ /g" | egrep "Great Clips$| [0-9]+$|min/cut$|Return Bonus.*%$|ENDING" |
while read line
do
	case "$line" in

	*Great\ Clips*)
		read line
		Store=${line##* }
		;;

	*PAYROLL\ WEEK\ ENDING*)
		Date=${line##* }
		;;

	*Return\ Bonus\ *%)
		Percent=${line##* } line=${line% $Percent}
		Bonus=${line##* }
		;;

	*min/cut)
		if [ "$Buffer" ]; then
			Buffer+="|$Bonus|$Percent"
			Bonus="" Percent=""
			print "$Buffer" >>$MINCUT
		fi
		Name=${line%% *} line=${line#$Name } Name+=${line%% *}
		line=${line% *} Minutes=${line##* }
		Buffer="$Store|$Date|$Name|$Minutes"
		;;
	esac
done

if [ "$Buffer" ]; then
	Buffer+="|$Bonus|$Percent"
	Bonus="" Percent=""
	print "$Buffer" >>$MINCUT
fi
