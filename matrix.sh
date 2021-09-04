#!/bin/sh

curld () {
	curl -L --connect-timeout 10 --max-time 5 --retry 2 \
		--retry-delay 0 --retry-max-time 10 \
		--compressed --keepalive --tlsv1.2 \
		-A 'Mozilla/5.0 (Windows NT 10.0; rv:68.0) Gecko/20100101 Firefox/68.0' \
		-H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8' \
		-H 'Accept-Language: en-US,en;q=0.5' \
		-H 'Accept-Encoding: gzip, deflate' \
		-H 'Connection: keep-alive' \
		-H 'Upgrade-Insecure-Requests: 1' "$@"
	}

# Get version
stable=$(curl -s 'https://github.com/matrix-org/synapse' | grep 'class="css-truncate css-truncate-target text-bold mr-2"' | sed "s/[<][^>]*[>]//g;s/[[:blank:]]//g;s/v//")
echo "Stable v: $stable"
develop=$(curl -s 'https://github.com/matrix-org/synapse/releases' | grep 'href="/matrix-org/synapse/releases/tag/v1.42.0rc1"' | sed "s/[<][^>]*[>]//g;s/[[:blank:]]//g;s/v//")
echo "Dev v: $develop"
vers=$(printf "%s\n%s\n" "$stable" "$develop" | sort -u | wc -l)

if [[ "$vers" == "2" ]] ; then
	ver=".version == \"$stable\" or .version == \"$develop\""
else
	ver=".version == \"$stable\""
fi

echo "ver = $ver"

# Get list of servers
list=$(curl --compressed 'https://the-federation.info/graphql?query=query%20Platform(%24name%3A%20String)%20%7B%0A%20%20platforms(name%3A%20%24name)%20%7B%0A%20%20%20%20name%0A%20%20%20%20code%0A%20%20%20%20displayName%0A%20%20%20%20description%0A%20%20%20%20tagline%0A%20%20%20%20website%0A%20%20%20%20icon%0A%20%20%20%20__typename%0A%20%20%7D%0A%20%20nodes(platform%3A%20%24name)%20%7B%0A%20%20%20%20id%0A%20%20%20%20name%0A%20%20%20%20version%0A%20%20%20%20openSignups%0A%20%20%20%20host%0A%20%20%20%20platform%20%7B%0A%20%20%20%20%20%20name%0A%20%20%20%20%20%20icon%0A%20%20%20%20%20%20__typename%0A%20%20%20%20%7D%0A%20%20%20%20countryCode%0A%20%20%20%20countryFlag%0A%20%20%20%20countryName%0A%20%20%20%20services%20%7B%0A%20%20%20%20%20%20name%0A%20%20%20%20%20%20__typename%0A%20%20%20%20%7D%0A%20%20%20%20__typename%0A%20%20%7D%0A%20%20statsGlobalToday(platform%3A%20%24name)%20%7B%0A%20%20%20%20usersTotal%0A%20%20%20%20usersHalfYear%0A%20%20%20%20usersMonthly%0A%20%20%20%20localPosts%0A%20%20%20%20localComments%0A%20%20%20%20__typename%0A%20%20%7D%0A%20%20statsNodes(platform%3A%20%24name)%20%7B%0A%20%20%20%20node%20%7B%0A%20%20%20%20%20%20id%0A%20%20%20%20%20%20__typename%0A%20%20%20%20%7D%0A%20%20%20%20usersTotal%0A%20%20%20%20usersHalfYear%0A%20%20%20%20usersMonthly%0A%20%20%20%20localPosts%0A%20%20%20%20localComments%0A%20%20%20%20__typename%0A%20%20%7D%0A%7D%0A&operationName=Platform&variables=%7B%22name%22%3A%22matrix%7Csynapse%22%7D' \
  | jq -r ".data.nodes[] | select($ver) | select(.openSignups == true) | .name")

printf "%s" "Initial: "
echo "$list" | wc -l

# Check for no recaptcha and no mail
goodreg=$( while IFS= read -r line ; do
if curld "https://$line/_matrix/client/r0/register"  -H "authority: $line"  -H 'sec-ch-ua: "Chromium";v="91", " Not;A Brand";v="99"'  -H 'accept: application/json'  -H 'dnt: 1'  -H 'sec-ch-ua-mobile: ?0'  -H 'user-agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Safari/537.36'  -H 'content-type: application/json'  -H 'origin: https://app.element.io'  -H 'sec-fetch-site: cross-site'  -H 'sec-fetch-mode: cors'  -H 'sec-fetch-dest: empty'  -H 'accept-language: en-US,en;q=0.9'  --data-raw '{"initial_device_display_name":"app.element.io (Mobile Safari, iOS)"}'  --compressed \
  | grep -q "m.login.recaptcha\|m.login.email.identity" ; then
	true
else
	echo "$line"
fi
done <<< "$list" )

printf "%s" "With no recaptcha an no mail: "
echo "$goodreg" | wc -l

# Prerunning SSL test
while IFS= read -r line ; do
	curl -s "https://www.ssllabs.com/ssltest/analyze.html?d=$line" > /dev/null
done <<< "$goodreg"

sleep 60

# Parse SSL results
goodlist=$( while IFS= read -r line ; do
printf "%s" "$line "
curl -s "https://www.ssllabs.com/ssltest/analyze.html?d=$line" | sed '/^$/d' | sed '/^[[:blank:]]\+$/d' | pcregrep -M 'div class="percentage_|div id="rating".*\n.*\n.*\n.*' | sed "s/[<][^>]*[>]//g" | sed '/^$/d' | sed '/^[[:blank:]]\+$/d' | sed 's/^[[:blank:]]\+//' | tail -n1
done <<< "$goodreg" )

printf "%s" "A+ number: "
echo "$goodlist" | grep "A+" | wc -l

# No cuck
nocuck=$( while IFS= read -r line ; do
if echo | openssl s_client -showcerts -servername $line -connect $line:443 2>/dev/null | openssl x509 -inform pem -noout -text | grep -q -i "cloudflare" ; then
	true
else
	echo "$line"
fi
done <<< "$(echo "$goodlist" | G "A+"   | awk '{print $1}')" )

pinglist=$( while IFS= read -r line ; do echo -n "$line " && ping -c 4 $line | tail -1| awk '{print $4}' | cut -d '/' -f 2 ; done <<< "$nocuck" )

echo
echo "$pinglist" | sort -nk2,2
