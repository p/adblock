#!/bin/sh

# Install script for adblock

usage() {
  echo "Usage: `basename $0` [-f] [-h]"
  echo "  -f  Force overwrite of adblock zone file, if it already exists"
  echo "  -h  This help text"
  exit ${1:-1}
}

force=false
while getopts ":fh" option; do
  case $option in
    f )
      force=true ;;
    h )
      usage 0 ;;
    * )
      usage ;;
  esac
done

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

# use two stages so that multiple systems can use one layout
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
    ;;
  debian )
    named_config=/etc/bind
    named_etc=$named_config
    named_etc_subdir=
    named_adblock_conf=$named_etc/named.conf.adblock
    named_conf=$named_etc/named.conf.local
    named_zone=$named_config/db.adblock
    named_restart_cmd="/etc/init.d/bind9 reload"
    adblock_dir=/usr/local/sbin
    adblock_conf_dir=/etc
    ;;
esac

install -d -m 755 $adblock_dir || exit 3
install -m 755 adblock $adblock_dir || exit 3
install -d -m 755 $adblock_conf_dir || exit 3
# -i option to sed is nonportable, and does not exist on openbsd in particular
# don't use / as separator as it occurs in paths
sed \
  -e "s:NAMED_ETC=\".*\":NAMED_ETC=\"$named_etc\":" \
  -e "s:NAMED_ADBLOCK_CONF=\"\":NAMED_ADBLOCK_CONF=\"$named_adblock_conf\":" \
  -e "s:ADBLOCK_ZONE_FILE=\"\":ADBLOCK_ZONE_FILE=\"$named_zone\":" \
  -e "s:NAMED_RESTART_CMD=\".*\":NAMED_RESTART_CMD=\"$named_restart_cmd\":" \
  adblock.conf-sample >$adblock_conf_dir/adblock.conf || exit 3
chmod 0644 $adblock_conf_dir/adblock.conf || exit 3

if [ ! -e $named_adblock_conf ]; then
  touch $named_adblock_conf || exit 3
fi

if [ $force = false ] && [ -e $named_zone ]; then
  echo "You already have adblock zone file, $named_zone."
  echo "If you want to replace it, use -f option."
else
  install -m 644 named.zone.adblock $named_zone || exit 3
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
