# Slurm Docker Cluster

This is a multi-container Slurm cluster using Kubernetes. The Slurm cluster Helm chart creates a named volume for persistent storage of MySQL data files. By default, it also installs the
RookNFS Helm chart (also in this repo) to provide shared storage across the Slurm cluster nodes.

## Dependencies

Requires:

* A Kubernetes cluster
* Local installations of
  * Helm
  * kubectl

## Containers and Volumes

The Helm chart will run the following containers:

* login
* mysql
* slurmdbd
* slurmctld
* slurmd (2 replicas by default)

The Helm chart will create the following named volumes:

* var_lib_mysql     ( -> /var/lib/mysql )

A named ReadWriteMany (RWX) volume mounted to `/home` is also expected, this can be external or can be deployed using the provided `rooknfs` chart directory (See "Deploying the Cluster").

## Configuring the Cluster

All config files in `slurm-cluster-chart/files` will be mounted into the container to configure their respective services on startup. Note that changes to these files will not all be propagated to existing deployments (see "Reconfiguring the Cluster"). Additional parameters can be found in the `values.yaml` file for the Helm chart. Note that some of these values will also not propagate until the cluster is restarted (see "Reconfiguring the Cluster").

## Deploying the Cluster

### Generating Cluster Secrets

On initial deployment ONLY, run
```console
./generate-secrets.sh [<target-namespace>]
```
This generates a set of secrets in the target namespace to be used by the Slurm cluster. If these need to be regenerated, see "Reconfiguring the Cluster"

Be sure to take note of the Open Ondemand credentials, you will need them to access the cluster through a browser

### Connecting RWX Volume

A ReadWriteMany (RWX) volume is required for shared storage across cluster nodes. By default, the Rook NFS Helm chart is installed as a dependency of the Slurm cluster chart in order to provide a RWX capable Storage Class for the required shared volume. If the target Kubernetes cluster has an existing storage class which should be used instead, then `storageClass` in `values.yaml` should be set to the name of this existing class and the RookNFS dependency should be disabled by setting `rooknfs.enabled = false`. In either case, the storage capacity of the provisioned RWX volume can be configured by setting the value of `storage.capacity`.

See the separate RookNFS chart [values.yaml](./rooknfs/values.yaml) for further configuration options when using the RookNFS to provide the shared storage volume.

### Supplying Public Keys

To access the cluster via `ssh`, you will need to make your public keys available. All your public keys from localhost can be added by running

```console
./publish-keys.sh [<target-namespace>]
```
where `<target-namespace>` is the namespace in which the Slurm cluster chart will be deployed (i.e. using `helm install -n <target-namespace> ...`). This will create a Kubernetes Secret in the appropriate namespace for the Slurm cluster to use. Omitting the namespace arg will install the secrets in the default namespace.

### Deploying with Helm

After configuring `kubectl` with the appropriate `kubeconfig` file, deploy the cluster using the Helm chart:
```console
helm install <deployment-name> slurm-cluster-chart
```

NOTE: If using the RookNFS dependency, then the following must be run before installing the Slurm cluster chart
```console
helm dependency update slurm-cluster-chart
```

Subsequent releases can be deployed using:

```console
helm upgrade <deployment-name> slurm-cluster-chart
```

## Accessing the Cluster

Retrieve the external IP address of the login node using:
```console
LOGIN=$(kubectl get service login -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
```
and connect to the cluster as the `rocky` user with
```console
ssh rocky@$LOGIN
```

From the shell, execute slurm commands, for example:

```console
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up 5-00:00:00      2   idle c[1-2]
```

## Running MPI Benchmarks

The Intel MPI Benchmarks are included in the containers. These can be run both with mpirun and srun. They can also be run as a containerised workload using apptainer.

Example job scripts:
* srun:
```console
#!/usr/bin/env bash

#SBATCH -N 2
#SBATCH --ntasks-per-node=1

echo $SLURM_JOB_ID: $SLURM_JOB_NODELIST
srun /usr/lib64/openmpi/bin/mpitests-IMB-MPI1 pingpong
```
* mpirun
```console
#!/usr/bin/env bash

#SBATCH -N 2
#SBATCH --ntasks-per-node=1

echo $SLURM_JOB_ID: $SLURM_JOB_NODELIST
/usr/lib64/openmpi/bin/mpirun --prefix /usr/lib64/openmpi mpitests-IMB-MPI1 pingpong
```
* apptainer
```console
#!/usr/bin/env bash
#SBATCH -N2
#SBATCH --ntasks-per-node=1
MPI_CONTAINER_TAG="main"
echo SLURM_JOB_NAME: $SLURM_JOB_NAME
echo $SLURM_JOB_ID: $SLURM_JOB_NODELIST
srun singularity exec docker://ghcr.io/stackhpc/mpitests-container:${MPI_CONTAINER_TAG} /usr/lib64/openmpi/bin/mpitests-IMB-MPI1 pingpong
```

Note: The mpirun script assumes you are running as user 'rocky'. If you are running as root, you will need to include the --allow-run-as-root argument

## Reconfiguring the Cluster

### Changes to config files

Changes to the Slurm configuration in `slurm-cluster-chart/files/slurm.conf` will be propagated (it may take a few seconds) to `/etc/slurm/slurm.conf` for all pods except the `slurmdbd` pod by running

```console
helm upgrade <deployment-name> slurm-cluster-chart/
```

The new Slurm configuration can then be read by running `scontrol reconfigure` as root inside a Slurm pod. The [slurm.conf documentation](https://slurm.schedmd.com/slurm.conf.html) notes that some changes require a restart of all daemons, which here requires redeploying the Slurm pods as described below.

Changes to other configuration files (e.g. Munge key etc) require a redeploy of the appropriate pods.

To redeploy pods use:
```console
kubectl rollout restart deployment <deployment-names ...>
```
for the `slurmdbd`, `login` and `mysql` pods and

```
kubectl rollout restart statefulset <statefulset-names ...>
```
for the `slurmd` and `slurmctld` pods

Generally restarts to `slurmd`, `slurmctld`, `login` and `slurmdbd` will be required.

### Changes to secrets

Regenerate secrets by rerunning
```console
./generate-secrets.sh
```
Some secrets are persisted in volumes, so cycling them requires a full teardown and reboot of the volumes and pods which these volumes are mounted on. Run
```console
kubectl delete deployment mysql
kubectl delete pvc var-lib-mysql
helm upgrade <deployment-name> slurm-cluster-chart
```
and then restart the other dependent deployments to propagate changes:
```console
kubectl rollout restart deployment slurmd slurmctld login slurmdbd
```

# Known Issues
