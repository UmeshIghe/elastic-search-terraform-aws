# Configure Bootstrap Password
BootstrapPassword="topsecret"
# printf "%s" "$BootstrapPassword" \
#   | bin/elasticsearch-keystore add -x "bootstrap.password"
# echo "bootstrap password is set"
# Start ES & Wait for it to be available
# bin/elasticsearch -d
# while true
# do
#   curl --fail -u "elastic:$BootstrapPassword" \
#     "http://${ip}:9200/_cluster/health?wait_for_status=yellow" \
#     && break
#   sleep 5
# done

# Set passwords for various users

  curl -u "elastic:${BootstrapPassword}" -XPOST "http://${ip}:9200/_xpack/security/user/elastic/_password" -d'{"password":"password"}' -H "Content-Type: application/json"

echo "elastic password is set"