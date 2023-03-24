#!/command/with-contenv sh
set -e;

export TRAEFIK_DEFAULT_DOMAIN=${BASE_DOMAIN/#.}

# Replace environment variables in template files
#envs=`printf '${%s} ' $(sh -c "env|cut -d'=' -f1")`;
envs='${TRAEFIK_DEFAULT_DOMAIN}'
for filename in $(find /etc/traefik -name '*.tmpl'); do
    envsubst "$envs" < "$filename" > ${filename: :-5};
    rm "$filename";
done
