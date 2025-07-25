#!/usr/bin/env bats

load test_helper

setup() {
  global_setup
  dokku nginx:stop
  dokku caddy:set --global letsencrypt-server https://acme-staging-v02.api.letsencrypt.org/directory
  dokku caddy:set --global letsencrypt-email
  dokku caddy:start
  create_app
}

teardown() {
  global_teardown
  destroy_app
  dokku caddy:stop
  dokku nginx:start
}

@test "(caddy) caddy:help" {
  run /bin/bash -c "dokku caddy"
  echo "output: $output"
  echo "status: $status"
  assert_output_contains "Manage the caddy proxy integration"
  help_output="$output"

  run /bin/bash -c "dokku caddy:help"
  echo "output: $output"
  echo "status: $status"
  assert_output_contains "Manage the caddy proxy integration"
  assert_output "$help_output"
}

@test "(caddy) single domain" {
  run /bin/bash -c "dokku proxy:set $TEST_APP caddy"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app python dokku@$DOKKU_DOMAIN:$TEST_APP convert_to_dockerfile
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "curl --silent $(dokku url $TEST_APP)"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output_contains "python/http.server"
}

@test "(caddy) custom label key" {
  run /bin/bash -c "dokku builder-herokuish:set $TEST_APP allowed true"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku proxy:set $TEST_APP caddy"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku caddy:set $TEST_APP label-key caddy_0"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "docker inspect $TEST_APP.web.1 --format '{{ index .Config.Labels \"caddy_0\" }}'"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "$TEST_APP.${DOKKU_DOMAIN}:80"
}

@test "(caddy) multiple domains" {
  run /bin/bash -c "dokku proxy:set $TEST_APP caddy"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku domains:add $TEST_APP $TEST_APP.${DOKKU_DOMAIN}"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku domains:add $TEST_APP $TEST_APP-2.${DOKKU_DOMAIN}"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app python dokku@$DOKKU_DOMAIN:$TEST_APP convert_to_dockerfile
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "curl --silent $TEST_APP.${DOKKU_DOMAIN}"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "python/http.server"

  run /bin/bash -c "curl --silent $TEST_APP-2.${DOKKU_DOMAIN}"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "python/http.server"
}

@test "(caddy) ssl" {
  run /bin/bash -c "dokku builder-herokuish:set $TEST_APP allowed true"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku proxy:set $TEST_APP caddy"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run deploy_app
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "docker inspect $TEST_APP.web.1 --format '{{ index .Config.Labels \"caddy\" }}'"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "$TEST_APP.${DOKKU_DOMAIN}:80"

  run /bin/bash -c "dokku caddy:set --global letsencrypt-email test@example.com"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku caddy:stop"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku caddy:start"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku ps:rebuild $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "dokku ps:inspect $TEST_APP"
  echo "output: $output"
  echo "status: $status"
  assert_success

  run /bin/bash -c "docker inspect $TEST_APP.web.1 --format '{{ index .Config.Labels \"caddy\" }}'"
  echo "output: $output"
  echo "status: $status"
  assert_success
  assert_output "$TEST_APP.${DOKKU_DOMAIN}"

  run /bin/bash -c "dokku --quiet ports:report $TEST_APP --ports-map"
  echo "output: $output"
  echo "status: $status"
  assert_output_not_exists

  run /bin/bash -c "dokku --quiet ports:report $TEST_APP --ports-map-detected"
  echo "output: $output"
  echo "status: $status"
  assert_output "http:80:5000 https:443:5000"
}
