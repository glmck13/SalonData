#!/bin/ksh

INFILE=${1:?}
STATSCSV=${INFILE%.*}.csv

exec <$INFILE

sed -e "s/  */ /g" | egrep "^[\.A-Za-z ]* [0-9][0-9][0-9][0-9]$|From|Payroll|GROWTH|%$" |
while read TEXT
do
	case "$TEXT" in
	*\ [0-9][0-9][0-9][0-9])
		STORE=${TEXT##* }
		;;
	From\ *)
		print $TEXT | read x x x END
		;;
	Total\ *)
		print $TEXT | read x x x A B x x x x C x
		;;
	Payroll\ %\ \(with\ *)
		print "$TEXT" | read x x x x x D x
		;;
	Payroll\ %\ \(without\ *)
		print "$TEXT" | read x x x x x E x
		;;
	Average\ *)
		F=${TEXT##* }
		;;
	Administrative\ *)
		G=${TEXT##* }
		;;
	Receptionist\ *)
		H=${TEXT##* }
		;;
	*Wait\ Times\ \>*)
		J=${TEXT##* }
		;;
	Holiday\ *|Vacation\ *)
		I=${TEXT##* }
		;;
	\*Customer\ *)
		K=${TEXT##* }
		;;
	*PRODUCT\ PERCENT\ *)
		L=${TEXT##* }
		;;
	*Salon\ Product\ *)
		M=${TEXT%\%*}% M=${M##* }
		;;
	*\*Sales\ Growth\ *)
		N=${TEXT##* }
		print "$STORE,$END,$A,$B,$C,$D,$E,$M,$F,$G,$H,$I,$J,$K,$L,$N"
		;;
	esac
done >$STATSCSV
