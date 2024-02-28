#!/bin/sh

# Install script for adblock

usage() {
  echo "Usage: `basename $0` [-d] [-f] [-h]"
  echo "  -d  Install dhclient-exit-hooks to switch between local and network DNS server based on the network"
  echo "  -f  Force overwrite of adblock zone file, if it already exists"
  echo "  -h  This help text"
  exit ${1:-1}
}

dhclient=false
force=false
while getopts ":dfh" option; do
  case $option in
    d )
      dhclient=true ;;
    f )
      force=true ;;
    h )
      usage 0 ;;
    * )
      usage ;;
  esac
done
shift $((OPTIND-1))

layout=unknown
case `uname -s` in
  FreeBSD )
    layout=freebsd ;;
  OpenBSD )
    layout=openbsd ;;
  Linux )
    if test -f /etc/debian_version || test -f /etc/devuan_version; then
      layout=debian
    fi
    ;;
esac

if [ $layout = unknown ]; then
  echo "Sorry, I don't know how to install adblock on your system." 1>&2
  exit 2
fi

# use two stages so that multiple systems can use the same layout.
echo Using $layout layout.
case $layout in
  freebsd )
    if test -d /usr/local/etc/namedb; then
      named_config=/usr/local/etc/namedb
    else
      named_config=/etc/namedb
    fi
    named_etc=$named_config
    named_etc_subdir=
    named_adblock_conf=$named_etc/named-adblock.conf
    named_conf=$named_etc/named.conf
    named_zone=$named_config/master/adblock
    named_restart_cmd="rndc reload"
    adblock_dir=/usr/local/sbin
    adblock_conf_dir=/usr/local/etc
    if $dhclient; then
      echo "Don't know where dhclient exit hooks file should be placed' 1>&2
      exit 1
    fi
    dhclient_exit_hooks=
    ;;
  openbsd )
    named_config=/var/named
    named_etc=$named_config/etc
    named_etc_subdir=etc/
    named_adblock_conf=$named_etc/named-adblock.conf
    named_conf=$named_etc/named.conf
    # openbsd runs bind in chroot, path is relative to chroot here
    named_zone=master/adblock
    named_restart_cmd="rndc reload"
    adblock_dir=/usr/local/sbin
    adblock_conf_dir=/etc
    if $dhclient; then
      echo "Don't know where dhclient exit hooks file should be placed' 1>&2
      exit 1
    fi
    dhclient_exit_hooks=
    ;;
  debian )
    named_config=/etc/bind
    named_etc=$named_config
    named_etc_subdir=
    named_adblock_conf=$named_etc/named.conf.adblock
    named_conf=$named_etc/named.conf.local
    named_zone=$named_config/db.adblock
    if test -x /etc/init.d/bind9; then
      init_script=/etc/init.d/bind9
    elif test -x /etc/init.d/named; then
      init_script=/etc/init.d/named
    else
      echo "Missing bind9 init script or it is installed in an unsupported location" 1>&2
      exit 1
    fi
    named_restart_cmd="$init_script reload"
    adblock_dir=/usr/local/sbin
    adblock_conf_dir=/etc
    dhclient_exit_hooks=/etc/dhcp/dhclient-exit-hooks.d/adblock
    ;;
esac

cd $(dirname "$0")

install_cmd="install -o root -g root"

eval $install_cmd -d -m 755 $adblock_dir || exit 3
eval $install_cmd -m 755 adblock $adblock_dir || exit 3
eval $install_cmd -d -m 755 $adblock_conf_dir || exit 3
# -i option to sed is nonportable, and does not exist on openbsd in particular
# don't use / as separator as it occurs in paths
if test -f $adblock_conf_dir/adblock.conf; then
  if $force; then
    install_conf=true
  else
    install_conf=false
    echo "You already have adblock configuration file, $adblock_conf_dir/adblock.conf." 1>&2
    echo "To replace it, use the -f option." 1>&2
  fi
else
  install_conf=true
fi

if $install_conf; then
  sed \
    -e "s:NAMED_ETC=\".*\":NAMED_ETC=\"$named_etc\":" \
    -e "s:NAMED_ADBLOCK_CONF=\"\":NAMED_ADBLOCK_CONF=\"$named_adblock_conf\":" \
    -e "s:ADBLOCK_ZONE_FILE=\"\":ADBLOCK_ZONE_FILE=\"$named_zone\":" \
    -e "s:NAMED_RESTART_CMD=\".*\":NAMED_RESTART_CMD=\"$named_restart_cmd\":" \
    adblock.conf-sample >$adblock_conf_dir/adblock.conf || exit 3
  chmod 0644 $adblock_conf_dir/adblock.conf || exit 3
fi

if [ ! -e $named_adblock_conf ]; then
  touch $named_adblock_conf || exit 3
fi

if test $dhclient; then
  eval $install_cmd -m 755 dhclient-exit-hooks $dhclient_exit_hooks
fi

if [ $force = false ] && [ -e $named_zone ]; then
  echo "You already have adblock zone file, $named_zone." 1>&2
  echo "To replace it, use the -f option." 1>&2
else
  eval $install_cmd -m 644 named.zone.adblock $named_zone || exit 3
  echo "You will probably want to edit the adblock zone file, $named_zone,"
  echo "to be appropriate for your network."
fi

if ! fgrep -q "$named_adblock_conf" $named_conf |fgrep -q include ; then
  echo
  echo "You will need to add a directive to include $named_adblock_conf into your $named_conf."
  echo "If you have a standard installation, you can do:"
  echo
  echo "echo 'include \"$named_adblock_conf\";' >> $named_conf"
fi
