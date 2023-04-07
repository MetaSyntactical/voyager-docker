#!/command/with-contenv sh
set -e;

DNSMASQ_DOMAINS=$BASE_DOMAIN
export DNSMASQ_DOMAINS

# Replace environment variables in template files
#envs=`printf '${%s} ' $(sh -c "env|cut -d'=' -f1")`;
for filename in $(find /etc/dnsmasq.d -name '*.tmpl'); do
    gomplate --file "$filename" --out "${filename: :-5}";
    rm "$filename";
done
