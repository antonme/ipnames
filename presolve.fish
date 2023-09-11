# Initialize a counter variable
set -g counter 0

# Total number of tasks
set -g total_tasks 0

# Custom command to increment the counter and print progress

function resolve -a name resolvers new_name concur
	parallel -j $concur --bar host -t A -W 3 :::: $name :::: $resolvers| rg address | awk '$4{print $4}' | sort -u| sort -h > $new_name
end


set prefixer ''
set concur 16
echo

if not contains -- '-ext' $argv
  echo "== Resolving names to ipv4"
  set servers "servers.txt"
else
  echo "== Resolving external names to ipv4"
  set prefixer 'ext-'
  set servers "servers-ext.txt"
  set concur 80
end

set names (ls "$prefixer"dns-*.txt)

if test $argv[2]
  set names "$prefixer"dns-$argv[2].txt
end

for name in $names
	set name_array (string split '-' $name)
	if test -z $prefixer
  	  set new_name "resolve-"$name_array[2]
    else
  	  set new_name "ext-resolve-"$name_array[3]
	end
       echo (date)"                "$name"  >"$new_name
  	resolve $name $servers $new_name $concur
end
