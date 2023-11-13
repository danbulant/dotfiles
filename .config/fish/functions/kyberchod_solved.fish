function kyberchod_solved
	if test -z $argv[1]
        	echo "Enter user id as argument 1"
	        exit 1
	end
	http https://www.kyberchod.cz/user?id=$argv[1] | htmlq table td:first-child, table td:last-child --text | string trim | tr \n " " | string split "   " | string trim | sort
end
