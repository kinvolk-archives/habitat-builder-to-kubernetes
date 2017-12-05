# Habitat Builder to Kubernetes

An experimental demo of Habitat Builder integrated with Kubernetes.

**NB**: the README is *work-in-progress* and subject to change.

## Setup

### Setup a local Habitat Builder instance

Use the following branch: https://github.com/kinvolk/habitat/tree/schu/robertgzr-kubernetes-exporter-integration-test
(This is the *work-in-progress* Kubernetes exporter + the Vagrant patches cherry-picked.)

The setup is described in detail here: https://github.com/kinvolk/habitat/blob/schu/vagrant/BUILDER_VAGRANT.md

Make sure you can connect a plan, build it and export to docker before
proceeding.

### Prepare a Kubernetes cluster

Use https://github.com/kinvolk/kube-spawn/pull/224 for the time being.

See `doc/vagrant.md`.

Apply this patch before:

```
diff --git a/Vagrantfile b/Vagrantfile
index 3a01d77..6038571 100644
--- a/Vagrantfile
+++ b/Vagrantfile
@@ -88,4 +88,5 @@ Vagrant.configure("2") do |config|
   end

   config.vm.network "forwarded_port", guest: 6443, host: 6443
+  config.vm.network "private_network", ip: "192.168.123.4"
 end
```

And the following if you want to use virtualbox:

```
diff --git a/vagrant-all.sh b/vagrant-all.sh
index 6caab29..3cb40eb 100755
--- a/vagrant-all.sh
+++ b/vagrant-all.sh
@@ -4,7 +4,7 @@ set -eo pipefail

 export KUBESPAWN_AUTOBUILD="true"
 export KUBESPAWN_REDIRECT_TRAFFIC="true"
-vagrant up
+vagrant up --provider virtualbox

 ./vagrant-fetch-kubeconfig.sh

```

At the end, after a succesful run of `vagrant-all.sh`, you should find
a `kubeconfig` file for the kube-spawn cluster running in the VM.

Currently (that might will be fixed soon), you need to manually change the IP
address in the `kubeconfig` file to the public IP of your kube-spawn VM,
i.e. here `192.168.123.4`. To make sure this has worked, run the following
command **from the host**:

```
kubectl --kubeconfig ./kubeconfig get nodes
```

### Make sure both Vagrant VMs can reach each other

* Ping `192.168.123.4` from the Habitat Builder box
* Ping `192.168.198.7` from the kube-spawn box

### Install kubectl

The Habitat VM requires kubectl in `/usr/local/bin`, i.e. `/usr/local/bin/kubectl`.

### Provide a kubeconfig

The Habitat VM requires the kubeconfig file under `/opt/kubeconfig`. If
you have used the kube-spawn VM above, copy the one from the kube-spawn
directory.

### Make sure `/src/target/debug/hab-pkg-export-kubernetes` exists

```
ls -l /src/target/debug/hab-pkg-export-kubernetes
```

If it does not exist do the following:

```
cd /src
sh -c 'cd components/pkg-export-kubernetes && cargo build'
```

Verify before proceeding.


### Build habitat operator

Use the following branch: https://github.com/kinvolk/habitat-operator/pull/128

Example:

```
make REPO=schu image
docker push schu/habitat-operator:v0.2.0-4-g5256ef2
```

### Install it on the k8s cluster

Use the following instructions: https://github.com/kinvolk/habitat-operator/tree/master/examples/rbac

**But** first make sure to update the image name in https://github.com/kinvolk/habitat-operator/blob/master/examples/rbac/habitat.yml
(I used `schu/habitat-operator:v0.2.0-4-g5256ef2`).

Example:

```
kubectl --kubeconfig ./kubeconfig apply -f ~/code/go/src/github.com/kinvolk/habitat-operator/examples/rbac/rbac.yml
kubectl --kubeconfig ./kubeconfig apply -f ~/code/go/src/github.com/kinvolk/habitat-operator/examples/rbac/habitat.yml
```

Verify it worked:

```
kubectl --kubeconfig ./kubeconfig get pods
NAME                                READY     STATUS    RESTARTS   AGE
habitat-operator-3880967423-v1qpb   1/1       Running   0          7m
```

Also check the logs (e.g. `kubectl --kubeconfig ./kubeconfig logs -f habitat-operator-3880967423-v1qpb`).

## Test

Trigger a new build in Habitat Builder ("Build latest version").

Wait, watch the output. It should look something like this:

```
★ Local Docker image 'schu/zero-dep' with tags: 0.1.0-20171201155205, 0.1.0, latest cleaned up
--- END: Docker export ---
--- BEGIN: Kubernetes export ---
--- END: Kubernetes export ---
```

The build should be successful.

`worker.1` log output shoud look like this:

```
worker.1    | DEBUG:habitat_builder_worker::runner::docker: terminated dockerd                                                                                                                                                                                                                                                                              
worker.1    | DEBUG:habitat_builder_worker::runner: Found runnable package, running kubernetes export                                                                                                    
worker.1    | DEBUG:habitat_builder_worker::runner::kubernetes: building kubernetes export command, cmd=building kubernetes export command, cmd="/src/target/debug/hab-pkg-export-kubernetes" "--count" "1" "--output" "-" "schu/zero-dep"                                                                                                                  
worker.1    | DEBUG:habitat_builder_worker::runner::kubernetes: spawning kubernetes export command                                                                                                                                                                                                                                                          
worker.1    | DEBUG:habitat_builder_worker::runner::kubernetes: building kubectl command, cmd="/usr/local/bin/kubectl" "--kubeconfig" "/opt/kubeconfig" "apply" "-f" "-"                                                                                                                                                                                    
worker.1    | DEBUG:habitat_builder_worker::runner::kubernetes: spawning kubectl command                                                                                
worker.1    | DEBUG:habitat_builder_worker::runner::kubernetes: deploying to cluster, status=ExitStatus(ExitStatus(0))                                                              
worker.1    | DEBUG:habitat_builder_worker::runner::kubernetes: completed kubernetes export command, status=ExitStatus(ExitStatus(0))
```

i.e. be successful (`status=ExitStatus(ExitStatus(0)`)

See also:

```
kubectl --kubeconfig ./kubeconfig get pods
NAME                                READY     STATUS    RESTARTS   AGE
habitat-operator-3880967423-91bmm   1/1       Running   0          7m
zero-dep-stable-1716167208-srhs3    1/1       Running   0          7m
```
