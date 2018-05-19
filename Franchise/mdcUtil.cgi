#!/bin/ksh

print "$QUERY_STRING" | IFS='=+& ' read x Action Class x

PATH=$PWD:$PATH
export DISPLAY=":0"
export RESULTS=$Class/Results; cd $DOCUMENT_ROOT/$RESULTS

exec 2>&1

print "Content-type: text/html\\n\\n"
print "<html><pre>"

if [[ "$Action" == Process* ]]; then

	PDF=$(get-pdf.pl $DOCUMENT_ROOT/$RESULTS)

	if [[ "$PDF" == *.pdf ]]; then
		pdf-to-txt.sh "$PDF"
		$Class.sh "${PDF%.*}.txt"
		print "$PDF processed."
	else
		print "$PDF"
	fi

elif [ ! "$(ls)" ]; then
	print "Folder is empty"

elif [[ "$Action" == Delete* ]]; then
	print "Deleting:"
	ls -l; rm -f *

elif [[ "$Action" == Archive* ]]; then
	print "Saving files to Archive folder:"
	mv -f * ../Archive; ls ../Archive
fi

print "</pre></html>"
