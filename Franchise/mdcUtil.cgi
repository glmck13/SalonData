#!/bin/ksh

# [ "$REQUEST_METHOD" = "POST" ] && read -r QUERY_STRING

vars="$QUERY_STRING"
while [ "$vars" ]
do
	print $vars | IFS='&' read v vars
	[ "$v" ] && export ${v%%=*}="$(urlencode -d ${v#*=})"
done

export Class=$Action Class=${Class#* } Class=${Class%% *}

PATH=$PWD:$PATH
export DISPLAY=":0"
export RESULTS=$Class/Results; cd $DOCUMENT_ROOT/$RESULTS

exec 2>&1

print "Content-type: text/html\\n\\n"
print "<html><pre>"

if [[ "$Action" == Process* ]]; then

	PDF=$(get-pdf.py $DOCUMENT_ROOT/$RESULTS)

	if [[ "$PDF" == *.pdf ]]; then
		pdf-to-txt.sh "$PDF"
		$Class.sh "${PDF%.*}.txt"
		print "$PDF processed."
	else
		print "$PDF"
	fi

elif [[ "$Action" == Get* ]]; then
	$Class.sh; print "Completed"

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
