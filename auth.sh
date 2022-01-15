# Configure Bootstrap Password
BootstrapPassword="topsecret"

  curl -u "elastic:${BootstrapPassword}" -XPOST "http://${ip}:9200/_xpack/security/user/elastic/_password" -d'{"password":"password"}' -H "Content-Type: application/json"

echo "elastic password is set"