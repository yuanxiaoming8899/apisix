#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

. ./t/cli/common.sh

# control server
echo '
apisix:
  enable_control: true
' > conf/config.yaml

make init

if ! grep "listen 127.0.0.1:9090;" conf/nginx.conf > /dev/null; then
    echo "failed: find default address for control server"
    exit 1
fi

make run

sleep 0.1

times=1
code=000
while [ $code -eq 000 ] && [ $times -lt 10 ]
do
  code=$(curl -v -k -i -m 20 -o /dev/null -s -w %{http_code} http://127.0.0.1:9090/v1/schema)
  sleep 0.2
  times=$(($times+1))
done

if [ ! $code -eq 200 ]; then
    echo "failed: access control server"
    exit 1
fi

code=$(curl -v -k -i -m 20 -o /dev/null -s -w %{http_code} http://127.0.0.1:9090/v0/schema)

if [ ! $code -eq 404 ]; then
    echo "failed: handle route not found"
    exit 1
fi

make stop

echo '
apisix:
  enable_control: true
  control:
    ip: 127.0.0.2
' > conf/config.yaml

make init

if ! grep "listen 127.0.0.2:9090;" conf/nginx.conf > /dev/null; then
    echo "failed: customize address for control server"
    exit 1
fi

make run

sleep 0.1

times=1
code=000
while [ $code -eq 000 ] && [ $times -lt 10 ]
do
  code=$(curl -v -k -i -m 20 -o /dev/null -s -w %{http_code} http://127.0.0.2:9090/v1/schema)
  sleep 0.2
  times=$(($times+1))
done

if [ ! $code -eq 200 ]; then
    echo "failed: access control server"
    exit 1
fi

make stop

echo '
apisix:
  enable_control: true
  control:
    port: 9092
' > conf/config.yaml

make init

if ! grep "listen 127.0.0.1:9092;" conf/nginx.conf > /dev/null; then
    echo "failed: customize address for control server"
    exit 1
fi

make run

sleep 0.1

times=1
code=000
while [ $code -eq 000 ] && [ $times -lt 10 ]
do
  code=$(curl -v -k -i -m 20 -o /dev/null -s -w %{http_code} http://127.0.0.1:9092/v1/schema)
  sleep 0.2
  times=$(($times+1))
done

if [ ! $code -eq 200 ]; then
    echo "failed: access control server"
    exit 1
fi

make stop

echo '
apisix:
  enable_control: false
' > conf/config.yaml

make init

if grep "listen 127.0.0.1:9090;" conf/nginx.conf > /dev/null; then
    echo "failed: disable control server"
    exit 1
fi

echo '
apisix:
  node_listen: 9090
  enable_control: true
  control:
    port: 9090
' > conf/config.yaml

out=$(make init 2>&1 || true)
if ! echo "$out" | grep "http listen port 9090 conflicts with control"; then
    echo "failed: can't detect port conflicts"
    exit 1
fi

echo '
apisix:
  node_listen: 9080
  enable_control: true
  control:
    port: 9091
plugin_attr:
  prometheus:
    export_addr:
      ip: "127.0.0.1"
      port: 9091
' > conf/config.yaml

out=$(make init 2>&1 || true)
if ! echo "$out" | grep "prometheus port 9091 conflicts with control"; then
    echo "failed: can't detect port conflicts"
    exit 1
fi

echo "pass: access control server"
