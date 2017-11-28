#!/bin/bash

set -ex

## Manually push or trigger a build with bldr.habitat.sh

## Download example app
curl -sL 'https://github.com/robertgzr/it_works/archive/master.tar.gz' | tar xvzf -
exec ./it_works/export-k8s.sh

## Download kube-spawn
curl -sL 'https://github.com/kinvolk/kube-spawn/archive/nhlfr/redirect-apiserver-port.tar.gz' | tar xvzf -
exec ./kube-spawn-nhlfr-redirect-apiserver-port/vagrant-all.sh

## Deploy habitat-operator
kubectl create -f https://raw.githubusercontent.com/kinvolk/habitat-operator/master/examples/rbac/rbac.yml
kubectl create -f https://raw.githubusercontent.com/kinvolk/habitat-operator/master/examples/rbac/habitat.yml 

## Deploy the manifest
kubectl create -f manifest.yml
