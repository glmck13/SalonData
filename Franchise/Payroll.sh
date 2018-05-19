#!/bin/ksh

PDF=${1:?}
TXT=${PDF%.*}.txt
ERRORS=${PDF%.*}-ERRORS.txt
BATCH=${PDF%.*}-BATCH.csv
STATS=${PDF%.*}-STATS.csv
TOTALS=${PDF%.*}-TOTALS.csv

export DBASE=../DBase

Payproc.sh <"$TXT" >"$BATCH" 2>"$ERRORS"
COCODE=$(tail -n1 "$BATCH" | cut -f1 -d,)
cp "$BATCH" "PR${COCODE}EPI.csv"

MODE="STATS" Payproc.sh <"$TXT" >"$STATS" 2>>"$ERRORS"

Paystats.sh <"$TXT" >"$TOTALS"
