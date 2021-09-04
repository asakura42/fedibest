#!/bin/sh

base=$(curl -s "https://searx.space/data/instances.json" | json2tsv)
file=$(echo "$base" | grep "^.instances." | sed 's/^.instances.//')


curltor () {
	curl -L --connect-timeout 20 --max-time 10 --retry 5 \
  --retry-delay 0 --retry-max-time 40 \
  --compressed --keepalive --tlsv1.2 -x socks5h://localhost:9050 \
  -A 'Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0' \
  -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
  -H 'Accept-Language: en-US,en;q=0.5' \
  -H 'Accept-Encoding: gzip, deflate' \
  -H 'Connection: keep-alive' \
  -H 'Upgrade-Insecure-Requests: 1' "$@"
}

# shit filtering
cloudflare=$(echo "$base" | grep -i "cloudflare" | grep -o "^.*/\." | sort -u | tr '\n' '|' | sed 's/\.instances\.//g;s/\.|$//;s/\.|/\\\|/g;s/$/\n/')
others=$(echo "$base" | grep -i "^.cidrs." | grep -i "microsoft\|google\|aws\|amazon" | sed 's/^.cidrs\.//;s/.asn_description.*//' | tr '\n' '|' | sed 's/|$//;s/|/\\\|/g;s/$/\n/')
others=$(echo "$file" | grep "$others" | grep -o "^.*/\." | sort -u | tr '\n' '|' | sed 's/\.|$//;s/\.|/\\\|/g;s/$/\n/')

file=$(echo "$file" | grep -v "$others\|$cloudflare")

privacy=$(echo "$file" | grep ".network.asn_privacy.*[[:blank:]]0$" | sed 's/.network.asn_privacy.*//')
http=$(echo "$file" | grep ".http.grade.*[[:blank:]]A+$" | sed 's/.http.grade.*//')
tls=$(echo "$file" | grep ".tls.grade.*[[:blank:]]A+$" | sed 's/.tls.grade.*//')
grade=$(echo "$file" | grep ".html.grade.*" | grep "[[:blank:]]V$\|[[:blank:]]C$" | sed 's/.html.grade.*//')
version=$(echo "$file" | grep ".version.*1\.0\.0.*" | sed 's/\.version.*//')

# Engines
google_time=$(echo "$file" | grep ".timing.search_go.all.median" | awk -F'\t' '$3<1' | sed 's/.timing.search_go.all.median.*//')
all_time=$(echo "$file" | grep ".timing.search.all.median" | awk -F'\t' '$3<1.5' | sed 's/.timing.search.all.median.*//')



domains=$(printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$grade" "$privacy" "$http" "$tls" "$google_time" "$version" "$all_time" | sed '/^$/d' | sort | uniq -c | awk '$1==7' | sed 's/^[[:blank:]]\+7 //')

if [[ "$1" == "-l" ]] ; then
	printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$grade" "$privacy" "$http" "$tls" "$google_time" "$version" "$all_time" | sed '/^$/d' | sort | uniq -c
elif [[ "$1" == "-d" ]] ; then
	echo "$file" | grep "$2" | grep ".network.asn_privacy.*[[:blank:]]0$\|.http.grade.*[[:blank:]]A+$\|.tls.grade.*[[:blank:]]A+$\|.html.grade.*[[:blank:]]V$\|.version.*1\.0\.0.*\|.engines.google.enabled.*true$\|.timing.search_go.all.median\|.timing.search.all.median"
else
	while IFS= read -r line ; do
		realgoogle=$(curltor -Ls "https://$(echo $line | awk -F/ '{print $3}')$(curltor -Ls "${line}" | grep 'form' | grep -o 'action="[^"]\+"' | sed 's/"$//;s/^.*"//')?q=\!go+google&category_general=on&time_range=&language=en-US" | grep -i -m1 -o "we didn't find any results")
		if [ ! -z "$realgoogle" ] ; then
			continue
		fi
		morty=$(curltor -Ls "https://$(echo $line | awk -F/ '{print $3}')$(curltor -Ls "${line}" | sed 's||\n|g' | grep -m1 -o "a href=.*>" | sed 's/">//;s/^.*"//' | sed 's|https://[0-9A-Za-z.-]\+||')search?q=test&category_general=on&time_range=&language=en-US" | grep -m1 -o "mortyhash" | sed 's/mortyhash/yes/')
		if [ -z "$morty" ] ; then
			morty="no"
		fi
		printf "%s %s %s %s\n" "$line" "$(echo "$file" | grep ".engines.*.enabled.*true" | grep "$line" | wc -l)" "$(echo "$file" | grep ".timing.search_go.all.median" | grep "$line" | awk -F'\t' '{print $NF}')" "$morty"
		
	done <<< "$domains" | sort -nk3,3 | sed '1i\@    @' | sed '1i\link engines google_time proxying' | column -t -s' ' -o'  |  ' | sed 's/^@.*//g'
fi
