#!/bin/bash
function ganglia/installed() {
  yum list installed | \
  grep ganglia | \
  grep -v web | \
  grep -v gmetad | \
  awk '{print $1}'
  yum list installed | \
  grep confuse | \
  awk '{print $1}'
  yum list installed | \
  grep apr | \
  awk '{print $1}'
}

function ganglia/repoquery() {
  repoquery -ql $* | \
  grep -v /man/ | \
  grep -v /doc/ | \
  grep -v /locale/ | \
  grep -v .pyc | \
  grep -v .pyo | \
  grep -v mysql | \
  grep -v DBUtil
}

target=${1:-sl-6}

_chroot="{{warewulf.common}}/chroots/${target}/"
_opts="-avR -l --no-implied-dirs"

read -p "Sync Ganglia to ${_chroot}?"
for i in $(ganglia/repoquery $(ganglia/installed)) ; do
  if ! test -r "${i}" ; then
    echo "NOT READABLE: ${i}"
    continue
  fi
  echo "$i"
  rsync ${_opts} "${i}" "${_chroot}"
done

read -p "Sync multicast route to ${_chroot}?"
rsync ${_opts} "/etc/sysconfig/network-scripts/route-eth0" "${_chroot}"

read -p "Sync services to ${_chroot}?"
rsync ${_opts} "/etc/rc3.d/S70gmond" "${_chroot}"
rsync ${_opts} "/etc/rc6.d/K40gmond" "${_chroot}
