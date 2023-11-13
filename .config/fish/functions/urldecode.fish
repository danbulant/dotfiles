function urldecode
	if test -z $argv
		while read i
			echo -e (echo $i | sed "s/%/\\\\x/g")
		end
		#python -c "import sys, urllib as ul; [sys.stdout.write(ul.quote_plus(l)) for l in sys.stdin]"
	else
		echo -e (echo $argv | sed "s/%/\\\\x/g")
	end
end
