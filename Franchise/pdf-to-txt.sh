#!/bin/ksh

INFILE="${1:?}"

pdftotext -layout $INFILE - | tr -d "\014" >${INFILE%.*}.txt
