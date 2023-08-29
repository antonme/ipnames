#/usr/bin/env fish
#set -x
#set -g fish_trace 1

function filter_names -a filter name antifilter forcedfilter
	echo "==="$name
	if test -z $forcedfilter
		set forcedfilter '.'
	end
	if test -z $antifilter
		set antifilter '##############'
	end
	#echo "name:"$name
	#echo "antifilter:"$antifilter
	#echo "forcedfilter:"$forcedfilter
  cat cache*.txt| grep -E $filter | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|grep '\.'|grep -v '\.arpa'|grep -v 'porn'| egrep -v $antifilter| egrep $forcedfilter| sort -u >dns-$name.txt
  cat list-*.txt| grep -E $filter | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|grep '\.'|grep -v '\.arpa'|grep -v 'porn'| egrep -v $antifilter| egrep $forcedfilter|sort -u >ext-dns-$name.txt
  grep -Fvxf dns-$name.txt ext-dns-$name.txt > temp.txt && mv temp.txt ext-dns-$name.txt
end

function resolve -a namesarg resolvers
  set names (cat $namesarg|grep '.')
  set counter 1
  for dns_name in $names
	  echo -ne "\033[0K\r["$counter"/"(count $names)"] "$dns_name>&2
	  set counter (math "$counter + 1")
           for server_name in (cat $resolvers)
               host -W 3 $dns_name $server_name| grep -v "IPv6"| grep address| awk '{print $4}'
			   printf "." >&2
       end
	   echo -ne "\033[0K\r                                                                              \033[0K\r">&2
  end| sort -u| sort -h 
end

echo "==Saving current cache"
sudo unbound-control dump_cache > cache-current.txt


echo
echo "==Extracting names"

filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com' 'google' 'yt|you'
filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com' 'youtube' '' 'yt|you'
filter_names "fbcdn|instag|\.facebook\.|b00c" 'facebook'
filter_names "\.tiktok|tiktokv|ttlive|bytefcdn|worldfcdn|bytetcdn|byte.cdn|ovscdns|pitaya|ttlive|bytefcdn|overseas|ovscdns|pitaya|worldfcdn|byte.cdn|bytedance|tiqcdn|ttcdn|ttwstatic|ttoversea|sgsnssdk|byteimg|ibyteimg|musical\.ly|isnssdk|ibyteimg|cdn\.concert\.io|anitm.xyz|2to2.top|bitssec|bytedapm|-oversea|goofy-cdn|byteglb|byteoversea|bytesover|ibytedtos|bytedance|byted\.org|bytegecko|hypstarcdn|pstatp" 'tiktok'
filter_names "openai\." 'openai'
filter_names "(^|\.)bing(\.)|bingads|bingapis|bingforbusiness|bi.ng|cortana|bing-int|microsoft|msft" 'bing' '' "bin|cortana"

echo
echo "== Save names archive"
cat dns-*.txt| sort -u| sort -h > cache-archive.txt
