#!/bin/bash
set -euo pipefail

function start_munge(){

    echo "---> Copying MUNGE key ..."
    cp /tmp/munge.key /etc/munge/munge.key
    chown munge:munge /etc/munge/munge.key

    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged "$@"
}

if [ "$1" = "slurmdbd" ]
then

    start_munge

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."

    cp /tmp/slurmdbd.conf /etc/slurm/slurmdbd.conf
    echo "StoragePass=${StoragePass}" >> /etc/slurm/slurmdbd.conf
    chown slurm:slurm /etc/slurm/slurmdbd.conf
    chmod 600 /etc/slurm/slurmdbd.conf
    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."

    exec gosu slurm /usr/sbin/slurmdbd -D "${@:2}"

elif [ "$1" = "slurmctld" ]
then

    start_munge

    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Setting permissions for state directory ..."
    chown slurm:slurm /var/spool/slurmctld

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    if /usr/sbin/slurmctld -V | grep -q '17.02' ; then
        exec gosu slurm /usr/sbin/slurmctld -D "${@:2}"
    else
        exec gosu slurm /usr/sbin/slurmctld -i -D "${@:2}"
    fi

elif [ "$1" = "slurmd" ]
then
    echo "---> Set shell resource limits ..."
    ulimit -l unlimited
    ulimit -s unlimited
    ulimit -n 131072
    ulimit -a

    start_munge

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld-0/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    exec /usr/sbin/slurmd -D "${@:2}"

elif [ "$1" = "login" ]
then
    
    chown root:root /home
    chmod 755 /home

    echo "---> Setting up ssh for user"

    mkdir -p /home/rocky/.ssh
    cp /tmp/authorized_keys /home/rocky/.ssh/authorized_keys

    echo "---> Setting permissions for user home directories"
    pushd /home > /dev/null
    for DIR in *
        do
        chown -R $DIR:$DIR $DIR || echo "Failed to change ownership of $DIR"
        chmod 700 $DIR/.ssh || echo "Couldn't set permissions for .ssh/ directory of $DIR"
        chmod 600 $DIR/.ssh/authorized_keys || echo "Couldn't set permissions for .ssh/authorized_keys for $DIR"
    done
    popd > /dev/null

    echo "---> Complete"
    echo "---> Starting sshd"
    cp /tempmounts/etc/ssh/* /etc/ssh/
    chmod 600 /etc/ssh/ssh_host_dsa_key
    chmod 600 /etc/ssh/ssh_host_ecdsa_key
    chmod 600 /etc/ssh/ssh_host_ed25519_key
    chmod 600 /etc/ssh/ssh_host_rsa_key
    /usr/sbin/sshd

    start_munge

    echo "---> Setting up self ssh capabilities for OOD"

    if [ -f /home/rocky/.ssh/id_rsa.pub ]; then
        echo "ssh keys already found"
    else
            ssh-keygen -t rsa -f /home/rocky/.ssh/id_rsa -N ""
            chown rocky:rocky /home/rocky/.ssh/id_rsa /home/rocky/.ssh/id_rsa.pub
    fi

    ssh-keyscan localhost > /etc/ssh/ssh_known_hosts
    echo "" >> /home/rocky/.ssh/authorized_keys #Adding newline to avoid breaking authorized_keys file
    cat /home/rocky/.ssh/id_rsa.pub >> /home/rocky/.ssh/authorized_keys

    echo "---> Starting Apache Server"

    # mkdir --parents /etc/ood/config/apps/shell
    # env > /etc/ood/config/apps/shell/env

    /usr/libexec/httpd-ssl-gencerts
    /opt/ood/ood-portal-generator/sbin/update_ood_portal
    mkdir --parents /opt/rh/httpd24/root/etc/httpd/

    /usr/bin/htdbm -cb /opt/rh/httpd24/root/etc/httpd/.htpasswd.dbm rocky $ROCKY_OOD_PASS
    /usr/sbin/httpd -k start -X -e debug

elif [ "$1" = "check-queue-hook" ]
then
    start_munge

    RUNNING_JOBS=$(squeue --states=RUNNING,COMPLETING,CONFIGURING,RESIZING,SIGNALING,STAGE_OUT,STOPPED,SUSPENDED --noheader --array | wc --lines)

    if [[ $RUNNING_JOBS -eq 0 ]]
    then
            exit 0
    else
            exit 1
    fi

elif [ "$1" = "debug" ]
then
    start_munge --foreground

else
    exec "$@"
fi
