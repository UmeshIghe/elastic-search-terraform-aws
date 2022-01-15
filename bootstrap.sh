# Configure Bootstrap Password
BootstrapPassword="topsecret"
printf "%s" "$BootstrapPassword" \
  | bin/elasticsearch-keystore add -x "bootstrap.password"
echo "bootstrap password is set"