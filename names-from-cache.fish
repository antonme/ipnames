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
  cat cache*.txt ~/logs/*.txt| rg $filter | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|rg -v "^_"|tr -d '<\?'| rg '\.'|rg -v '\.arpa'| rg -v $antifilter| rg $forcedfilter| rg -v "^-|^[0-9]"|sort -u >dns-$name.txt
  cat list-*.txt| rg $filter | awk '{if($1!="msg")print $1;else print $2;}'|sed 's/\.$//'|rg '\.'|rg -v '\.arpa'| rg -v $antifilter| rg $forcedfilter| rg -v "^-|^[0-9]"|sort -u >ext-dns-$name.txt
  grep -Fvxf dns-$name.txt ext-dns-$name.txt > temp.txt && mv temp.txt ext-dns-$name.txt
end


echo "==Saving current cache @dns"
unbound-control dump_cache > cache-current.txt

echo "==Saving current cache @home.setia"
unbound-control -s 192.168.11.11 -c /etc/unbound/keys/home/unbound.conf dump_cache > cache-current-setia.txt

echo "==Preparing logs data"
echo "k"
cat /var/log/unbound/unbound.log| awk '{print $7}'|sort -u > ~/logs/logcache.txt
echo "s"
ssh 192.168.11.11 "tail -2000000 /var/log/unbound/unbound.log | rg IN | awk '{print \$7}'|sort -u" > ~/logs/setiacache.small.txt

echo
echo "==Preparing surfshark names"
curl https://api.surfshark.com/v4/server/clusters| jq .[].connectionName | tr -d '"'|sort|uniq > dns-surfshark.txt

echo "==Antifilter.Download names"
curl https://community.antifilter.download/list/domains.lst >> cache-antifilter.txt

echo
echo "==Certificate Transparency names (crt.sh)"
# Apex domains covering every service handled by the filters below. crt.sh
# returns all subdomains ever certified for each apex; the per-service
# filter_names regexes then sort them into the right dns-*.txt buckets.
# Keep this list in sync with those regexes: add a service's domains in both.
set -l crtsh_apexes \
	google.com googleapis.com gstatic.com googleusercontent.com \
	googlesyndication.com withgoogle.com \
	doubleclick.net googletagmanager.com google-analytics.com \
	googleadservices.com recaptcha.net \
	googlevideo.com gvt1.com youtube.com ytimg.com youtube-nocookie.com ggpht.com \
	facebook.com facebook.net instagram.com cdninstagram.com fbcdn.net fbsbx.com \
	whatsapp.net whatsapp.com messenger.com fb.com threads.net threads.com meta.com \
	tiktok.com tiktokv.com tiktokv.us tiktokcdn.com tiktokcdn-us.com \
	bytedance.com ibyteimg.com byteoversea.com \
	openai.com chatgpt.com oaiusercontent.com oaistatic.com oaistatsig.com \
	sora.com chat.com \
	bing.com microsoft.com \
	twitter.com x.com twimg.com pscp.tv \
	ozon.ru ozonusercontent.com \
	github.com githubusercontent.com githubassets.com githubcopilot.com \
	github.io ghcr.io \
	apple.com icloud.com icloud-content.com mzstatic.com cdn-apple.com \
	aaplimg.com apple-dns.net apple.news \
	adobe.com adobe.io adobelogin.com adobedc.net behance.net photoshop.com \
	typekit.net frame.io demdex.net omtrdc.net \
	pornhub.com phncdn.com \
	backblaze.com backblazeb2.com \
	huggingface.co hf.co hf.space \
	anthropic.com claude.ai claude.com claudeusercontent.com clau.de \
	x.ai grok.com

# Accumulate into a temp file and only replace cache-ct.txt if we actually got
# names, so a crt.sh outage doesn't wipe the previous run's contribution.
# Rebuilt fresh (not appended) so the list tracks currently-valid certs only.
set -l ctnew (mktemp)
for apex in $crtsh_apexes
	set -l tmp (mktemp)
	# crt.sh is flaky (timeouts, 502s, HTML error pages with 200), so retry
	# the whole fetch+validate cycle with growing backoff. curl's own --retry
	# is not enough: it skips connection resets and never sees bad bodies.
	set -l maxtries 5
	set -l status_msg "fetch failed"
	for try in (seq $maxtries)
		if curl -f -sS --compressed -A "ipnames-crtsh/1.0" \
				--max-time 120 \
				"https://crt.sh/?q=%25.$apex&exclude=expired&output=json" -o $tmp
			# crt.sh serves an HTML error page on overload; only parse real JSON.
			if jq -e 'type == "array"' $tmp >/dev/null 2>&1
				set status_msg ok
				break
			end
			set status_msg "skipped (no JSON)"
		else
			set status_msg "fetch failed"
		end
		if test $try -lt $maxtries
			echo "  $apex: $status_msg, retry $try/"(math $maxtries - 1)" in "(math 10 \* $try)"s"
			sleep (math 10 \* $try)
		end
	end
	if test $status_msg = ok
		# name_value may hold several newline-separated names; common_name
		# may be null (select drops it). Final dedup happens once below.
		jq -r '.[] | .name_value, .common_name | select(. != null)' $tmp 2>/dev/null \
			| tr '[:upper:]' '[:lower:]' \
			| sed 's/^\*\.//' \
			| rg -v '[ @*]' \
			| rg '\.' >> $ctnew
	end
	echo "  $apex: $status_msg"
	rm -f $tmp
	sleep 2
end
if test -s $ctnew
	sort -u $ctnew -o cache-ct.txt
	echo "  total CT names:" (wc -l < cache-ct.txt)
else
	echo "  crt.sh produced nothing; keeping previous cache-ct.txt"
end
rm -f $ctnew

echo
# Weekly: re-probe once the list is 6.5+ days old, so daily runs land on day 7
# whatever the run time jitter. A failed probe keeps the old file, so it simply
# retries on the next run.
if find list-youtube-probed.txt -mmin -9360 2>/dev/null | grep -q .
	echo "==Probing YouTube cache servers: skipped, list is less than a week old"
else
	echo "==Probing YouTube cache servers"
	python3 probe-youtube.py
end

echo
echo "==Extracting names"

filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com|ggpht\.com|doubleclick\.net|googletagmanager\.com|google-analytics\.com|googleadservices\.com|recaptcha\.net' 'google' 'yt|you|googlevideo|video|telegram.me\$'
filter_names 'google\.com|\.google\.$|googlesyndication|googleapis\.com|gstatic\.com|googleusercontent\.com|googlevideo|(-|\.)youtube\.|youtube-nocookie\.com|ggpht\.com|\.ytimg|\.gvt[1-3]\.com' 'youtube' 'lytics' 'yt|you|googlevideo|video|gvt[1-3]'
filter_names "fbcdn|instag|\.facebook\.|b00c|fbsbx\.com|(^|[. ])whatsapp\.(net|com)\b|(^|[. ])messenger\.com|(^|[. ])fb\.com\b|(^|[. ])threads\.(net|com)\b|(^|[. ])meta\.com\b" 'facebook'
filter_names "\.tiktok|tiktokv|(\.|-)tt|ttlive|bytefcdn|worldfcdn|bytetcdn|byte.cdn|ovscdns|pitaya|ttlive|bytefcdn|overseas|ovscdns|pitaya|worldfcdn|byte.cdn|bytedance|-webcast-|tiqcdn|ttcdn|ttwstatic|ttoversea|sgsnssdk|byteimg|ibyteimg|musical\.ly|isnssdk|ibyteimg|cdn\.concert\.io|anitm.xyz|2to2.top|bitssec|bytedapm|-oversea|goofy-cdn|byteglb|byteoversea|bytesover|ibytedtos|bytedance|byted\.org|bytegecko|hypstarcdn|pstatp" 'tiktok' 'ttddnnss|\.tt$'
filter_names "openai\.|[\. ]oai|chatgpt\.com|(^|[. ])sora\.com\b|(^|[. ])chat\.com\b" 'openai' "shofha.online"
filter_names "(^|\.)bing(\.)|bingads|bingapis|bingforbusiness|bi.ng|cortana|bing-int|microsoft|msft" 'bing' '' "bin|cortana"
filter_names 'twitter|twtt|twimg|twtr|(\.|^)t\.co$|twitpic|(^|\.)x\.com|tweet|periscope\.|pscp\.tv' 'twitter'
filter_names '(\.|-|^)ozon(\.|-)|ozonuser' 'ozon'
filter_names 'githubuser|githubassets\.com|githubcopilot\.com|(^|\.|-)github(\.|-)com|github\.io|(^|[. ])ghcr\.io' 'github'
filter_names '(\.|-)apple\.com|\.me\.com|\.mac\.com|(\.|-)aapl(\.|-)|\.icloud\.com|cdn-apple\.com|\.itunes\.com|appleschoolcontent|apple-mapkit\.com|axm-usercontent-apple.com|\.mzstatic.com|apple-cloudkit.com|icloud-content|\.apzones\.com|apple-livephotoskit|apple-cloudkit|aaplimg\.com|apple-dns\.net|(^|[. ])apple\.news' 'apple'
filter_names '\.adobe|behance\.net|\.ftcdn\.|typekit\.com|typekit\.net|astockcdn|photoshop\.com|frame\.io|acrobat\.com|businesscatalyst.com|phonegap.com|prosite.com|myportfolio.com|demdex\.net|omtrdc\.net' 'adobe'
filter_names '(\.)pornhub(\.)|phncdn\.com' 'pornhub'
filter_names 'backblaze' 'backblaze'
filter_names 'huggingface|cdn-lfs|(^|[. ])hf\.(co|space)\b' 'huggingface'
filter_names 'anthropic|claude\.ai|(^|[. ])claude\.com\b|claudeusercontent\.com|(^|[. ])clau\.de\b' 'anthropic'
filter_names '(^|[. ])x\.ai\b|(^|[. ])grok\.com\b' 'xai'
echo
echo "== Save names archive"
cat dns-*.txt| grep -Ev '^-'|grep "\."|sort -u| sort -h > cache-archive.txt
