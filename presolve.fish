# Initialize a counter variable
set -g counter 0

# Total number of tasks
set -g total_tasks 0

# Custom command to increment the counter and print progress

function resolve -a namesarg resolvers new_name concur
  set names (cat $namesarg|grep '.')
  set -l hostarr
  set cnt 0
  set total_names (count $names)
  for dns_name in $names
	  for server_name in (cat $resolvers)
        set -a hostarr "host -t A -W 3 $dns_name $server_name"
      end
	  set cnt (math "$cnt + 1")
      set perc (math "floor($cnt/$total_names*100)")
	  echo -ne "Preparing commands: $perc% ($cnt/$total_names)     \033[0K\r"
	##| grep -v "IPv6"| grep address| awk '{print $4}'
  end

  set -g total_tasks (count $hostarr)
  printf "%s\n" $hostarr| parallel -j $concur --bar| grep address | awk '{print $4}' | sort -u| sort -h > $new_name
end


set prefixer ''
set concur 8
echo

if not contains -- '-ext' $argv
  echo "== Resolving names"
  set servers "servers.txt"
else
  echo "== Resolving external names"
  set prefixer 'ext-'
  set servers "servers-ext.txt"
  set concur 40
end



for name in "$prefixer"dns-*.txt
	set name_array (string split '-' $name)
	if test -z $prefixer
  	  set new_name "resolve-"$name_array[2]
    else
  	  set new_name "ext-resolve-"$name_array[3]
	end
       echo (date)"                "$name"  >"$new_name
  	resolve $name $servers $new_name $concur
end
