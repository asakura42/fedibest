#!/bin/sh
list=$(curl -s "https://raw.githubusercontent.com/xnaas/nitter-instances/master/history/summary.json" | json2tsv | grep "^\[\].name\|^\[\].uptime[[:blank:]]" | sed 's/\[\].uptime[[:blank:]]\+s[[:blank:]]//;s/\[\].name[[:blank:]]\+s[[:blank:]]//;s/%//' | paste -d " "  - - | awk '$2>99 {print $1}')
# echo "$list"

# Check certificate
while IFS= read -r line ; do
        if echo | openssl s_client -showcerts -servername $line -connect $line:443 2>/dev/null | openssl x509 -inform pem -noout -text | grep -q -i "cloudflare" ; then
                true
        else
                servers="$servers|$line"
        fi
done <<< "$list"

servers=$(echo "$servers" | sed 's/^|//' | tr '|' '\n')

# Check version
while IFS= read -r line ; do
        number=$(curl -s "https://$line/about" -H 'Accept-Language: en-US,en;q=0.5' --compressed | grep "Commit" | grep -o ">[[:alnum:]]\+<" | sed 's/>//;s/<//')
        if [ -z "$number" ] ; then
                continue
        fi
        commitdate=$(curl -s "https://github.com/zedeus/nitter/commit/$number" | grep -m1 -A1 committed  | tail -n1 | grep -o ">.*<" | sed 's/>//;s/<//')
        if [ -z "$commitdate" ] ; then
                continue
        fi
        commit=$(date --date="$commitdate"  +"%y%m%d")
        recent="$recent|$line $commit"
done <<< "$servers"
recent=$(echo "$recent" | sed 's/^|//' | tr '|' '\n')
echo "$recent" | grep " $(date "+%y%m")\|$(date --date="last month" "+%y%m")" | sort -nk2,2
