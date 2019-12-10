#!/usr/bin/env bats

load ./../helper

@test "Namespace-wide policy" {
  info
  setup_environment(){
    kubectl apply -f katalog/tests/istio/citadel/mtls-at-foo-ns.yaml
    kubectl apply -f katalog/tests/istio/citadel/mtls-at-foo-destination-rules.yaml
  }
  run setup_environment
  [ "$status" -eq 0 ]
}

@test "Namespace-wide policy - Requests from client-without-sidecar to httpbin.foo start to fail" {
  info
  test(){
    for from in "legacy"
    do
      for to in "foo"
      do
        pod_name=$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})
        http_code=$(kubectl exec ${pod_name} -c sleep -n ${from} -- curl "http://httpbin.${to}:8000/ip" -s -o /dev/null -w "%{http_code}")
        if [ "${http_code}" -ne "000" ]; then return 1; fi
      done
    done
  }
  retry_counter=0
  max_retry=30
  ko=1
  while [[ ko -eq 1 ]]
  do
    if [ $retry_counter -ge $max_retry ]; then echo "Timeout waiting a condition"; exit 1; fi
    sleep 2 && echo "# waiting..." $retry_counter >&3
    run test
    ko=${status}
    retry_counter=$((retry_counter + 1))
  done
  [ "$status" -eq 0 ]
}

@test "Namespace-wide policy - Requests from client-with-sidecar to httpbin.foo works" {
  info
  test(){
    for from in "foo" "bar"
    do
      for to in "foo" "bar" "legacy"
      do
        pod_name=$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})
        http_code=$(kubectl exec ${pod_name} -c sleep -n ${from} -- curl "http://httpbin.${to}:8000/ip" -s -o /dev/null -w "%{http_code}")
        if [ "${http_code}" -ne "200" ]; then return 1; fi
      done
    done
  }
  retry_counter=0
  max_retry=30
  ko=1
  while [[ ko -eq 1 ]]
  do
    if [ $retry_counter -ge $max_retry ]; then echo "Timeout waiting a condition"; exit 1; fi
    sleep 2 && echo "# waiting..." $retry_counter >&3
    run test
    ko=${status}
    retry_counter=$((retry_counter + 1))
  done
  [ "$status" -eq 0 ]
}

@test "Service-specific policy" {
  info
  setup_environment(){
    kubectl apply -f katalog/tests/istio/citadel/mtls-at-bar-httpbin-service.yaml
    kubectl apply -f katalog/tests/istio/citadel/mtls-at-bar-httpbin-service-destination-rules.yaml
  }
  run setup_environment
  [ "$status" -eq 0 ]
}

@test "Service-specific policy - request from sleep.legacy to httpbin.bar starts failing" {
  info
  test(){
    for from in "legacy"
    do
      for to in "bar"
      do
        pod_name=$(kubectl get pod -l app=sleep -n ${from} -o jsonpath={.items..metadata.name})
        http_code=$(kubectl exec ${pod_name} -c sleep -n ${from} -- curl "http://httpbin.${to}:8000/ip" -s -o /dev/null -w "%{http_code}")
        if [ "${http_code}" -ne "000" ]; then return 1; fi
      done
    done
  }
  retry_counter=0
  max_retry=30
  ko=1
  while [[ ko -eq 1 ]]
  do
    if [ $retry_counter -ge $max_retry ]; then echo "Timeout waiting a condition"; exit 1; fi
    sleep 2 && echo "# waiting..." $retry_counter >&3
    run test
    ko=${status}
    retry_counter=$((retry_counter + 1))
  done
  [ "$status" -eq 0 ]
}

@test "Namespace-wide policy and Service-specific policy - Cleanup" {
  info
  setup_environment(){
    kubectl delete -f katalog/tests/istio/citadel/mtls-at-foo-ns.yaml
    kubectl delete -f katalog/tests/istio/citadel/mtls-at-bar-httpbin-service.yaml
    kubectl delete -f katalog/tests/istio/citadel/mtls-at-foo-destination-rules.yaml
    kubectl delete -f katalog/tests/istio/citadel/mtls-at-bar-httpbin-service-destination-rules.yaml
  }
  run setup_environment
  [ "$status" -eq 0 ]
}
