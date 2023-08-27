#/usr/bin/env fish
#set -x
#set -g fish_trace 1

function filter_names 
  grep -E $argv | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|grep '\.'|grep -v '\.arpa'|sort -u
end

function resolve
  set names (cat $argv|grep '.')
  set counter 1
  for dns_name in $names
	  echo -ne "\033[0K\r["$counter"/"(count $names)"] "$dns_name>&2
	  set counter (math "$counter + 1")
           for server_name in (cat servers.txt)
               host $dns_name $server_name| grep -v "IPv6"| grep address| awk '{print $4}'
			   printf "." >&2
       end
	   echo -ne "\033[0K\r                                                                              \033[0K\r">&2
  end| sort -u| sort -h 
end

echo "==Saving current cache"
sudo unbound-control dump_cache > cache-current.txt


echo
echo "==Extracting names"
echo "===Google"
cat cache*.txt|filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com'| egrep -v 'yt|you' >dns-google.txt

echo "===YouTube"
cat cache*.txt|filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com'| egrep 'yt|you' >dns-youtube.txt

echo "===Facebook"
cat cache*.txt|filter_names "fbcdn|instag|faceb|b00c" >dns-facebook.txt

echo "===Tiktok"
cat cache*.txt|filter_names "tiktok|tiqcdn|bytesover|bytedance|byted\.org|bytegecko" >dns-tiktok.txt

echo "===OpenAI"
cat cache*.txt|filter_names "openai" >dns-openai.txt

echo "===Bing"
cat cache*.txt|filter_names "bing\.|bingapis|bingforbusiness|bi.ng|cortana|bing-int|microsoft|msft"|grep -E "bin|cortana" >dns-bing.txt

echo
echo "== Resolving names"
for name in dns-*.txt
       set name_array (string split '-' $name)
	   set new_name "resolve-"$name_array[2]
       echo $name"  >"$new_name
	   resolve $name >$new_name
end

echo "== Save names archive"
cat dns-*.txt| sort -u| sort -h > cache-archive.txt

