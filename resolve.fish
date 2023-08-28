function resolve -a namesarg resolvers
  set names (cat $namesarg|grep '.')
  set counter 1
  for dns_name in $names
	 echo -ne "\033[0K\r["$counter"/"(count $names)"] "$dns_name>&2
	 set counter (math "$counter + 1")
           for server_name in (cat $resolvers)
               host -t A -W 3 $dns_name $server_name| grep -v "IPv6"| grep address| awk '{print $4}'
			  printf "." >&2
       end
	  echo -ne "\033[0K\r                                                                              \033[0K\r">&2
  end| sort -u| sort -h 
end


set prefixer ''
echo

if not contains -- '-ext' $argv
  echo "== Resolving names"
  set servers "servers.txt"
else
  echo "== Resolving external names"
  set prefixer 'ext-'
  set servers "servers-ext.txt"
end



for name in "$prefixer"dns-*.txt
	set name_array (string split '-' $name)
	if test -z $prefixer
  	  set new_name "resolve-"$name_array[2]
    else
  	  set new_name "ext-resolve-"$name_array[3]
	end
       echo (date)"                "$name"  >"$new_name
  	resolve $name $servers >$new_name
end
