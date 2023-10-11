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
  cat cache*.txt| rg $filter | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|rg '\.'|rg -v '\.arpa'| rg -v $antifilter| rg $forcedfilter| rg -v "^-|^[0-9]"|sort -u >dns-$name.txt
  cat list-*.txt| rg $filter | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|rg '\.'|rg -v '\.arpa'| rg -v $antifilter| rg $forcedfilter| rg -v "^-|^[0-9]"|sort -u >ext-dns-$name.txt
  grep -Fvxf dns-$name.txt ext-dns-$name.txt > temp.txt && mv temp.txt ext-dns-$name.txt
end


echo "==Saving current cache @dns"
unbound-control dump_cache > cache-current.txt

echo "==Saving current cache @home.setia"
unbound-control -s 192.168.1.20 -c keys/home/unbound.conf dump_cache > cache-current-setia.txt
echo
echo "==Preparing surfshark names"
curl https://api.surfshark.com/v4/server/clusters| jq .[].connectionName | tr -d '"'|sort|uniq > dns-surfshark.txt

echo
echo "==Extracting names"

filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com' 'google' 'yt|you|googlevideo|video'
filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com|googlevideo|(-|\.)youtube\.|\.ytimg' 'youtube' 'lytics' 'yt|you|googlevideo|video'
filter_names "fbcdn|instag|\.facebook\.|b00c" 'facebook'
filter_names "\.tiktok|tiktokv|(\.|-)tt|ttlive|bytefcdn|worldfcdn|bytetcdn|byte.cdn|ovscdns|pitaya|ttlive|bytefcdn|overseas|ovscdns|pitaya|worldfcdn|byte.cdn|bytedance|-webcast-|tiqcdn|ttcdn|ttwstatic|ttoversea|sgsnssdk|byteimg|ibyteimg|musical\.ly|isnssdk|ibyteimg|cdn\.concert\.io|anitm.xyz|2to2.top|bitssec|bytedapm|-oversea|goofy-cdn|byteglb|byteoversea|bytesover|ibytedtos|bytedance|byted\.org|bytegecko|hypstarcdn|pstatp" 'tiktok' 'ttddnnss'
filter_names "openai\." 'openai'
filter_names "(^|\.)bing(\.)|bingads|bingapis|bingforbusiness|bi.ng|cortana|bing-int|microsoft|msft" 'bing' '' "bin|cortana"
filter_names 'twitter|twtt|twimg|twtr|(\.|^)t\.co$|twitpic|(^|\.)x\.com|tweet|periscope|pscp\.tv' 'twitter'
filter_names '(\.|-|^)ozon(\.|-)|ozonuser' 'ozon'
filter_names 'githubuser|(^|\.|-)github(\.|-)com|^github\.io' 'github'
filter_names '(\.|-)apple\.com|\.me\.com|\.mac\.com|(\.|-)aapl(\.|-)|\.icloud\.com|cdn-apple\.com|\.itunes\.com|appleschoolcontent|apple-mapkit\.com|axm-usercontent-apple.com|\.mzstatic.com|apple-cloudkit.com|icloud-content|\.apzones\.com|apple-livephotoskit|apple-cloudkit' 'apple'
filter_names '\.adobe|behance\.net|\.ftcdn\.|typekit\.com|typekit\.net|astockcdn|photoshop\.com|frame\.io|acrobat\.com|businesscatalyst.com|phonegap.com|prosite.com|myportfolio.com' 'adobe'
filter_names '(\.)pornhub(\.)|phncdn\.com' 'pornhub'
filter_names 'backblaze' 'backblaze'
echo
echo "== Save names archive"
cat dns-*.txt| grep -Ev '^-'|grep "\."|sort -u| sort -h > cache-archive.txt
