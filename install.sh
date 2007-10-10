#!/bin/sh

# Install script for adblock

usage() {
	echo "Usage: `basename $0` [-f] [-h]"
	echo "	-f	Force overwrite of adblock zone file, if it already exists"
	echo "	-h	This help"
	exit 1
}

force=false
while getopts ":fh" option; do
	case $option in
		f )
			force=true ;;
		h )
			usage ;;
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
esac

if [ $layout = unknown ]; then
	echo "Sorry, I don't know how to install adblock on your system." 1>&2
	exit 2
fi

# use two stages so that multiple systems can use one layout
echo Using $layout layout.
case $layout in
	freebsd )
		named_config=/etc/namedb
		named_etc=$named_config
		named_adblock_conf=$named_etc/named-adblock.conf
		named_conf=$named_etc/named.conf
		named_zone=$named_config/master/adblock
		adblock_dir=/usr/local/sbin
		adblock_conf_dir=/usr/local/etc
		;;
	openbsd )
		named_config=/var/named
		named_config_etc=$named_config/etc
		named_adblock_conf=$named_etc/named-adblock.conf
		named_conf=$named_etc/named.conf
		named_zone=$named_config/master/adblock
		adblock_dir=/usr/local/sbin
		adblock_conf_dir=/etc
		;;
esac

install -d -m 755 $adblock_dir || exit 3
install -m 755 adblock $adblock_dir || exit 3
install -d -m 755 $adblock_conf_dir || exit 3
install -m 644 adblock.conf-sample $adblock_conf_dir/adblock.conf || exit 3
sed -i "" -e 's/NAMED_ETC=".*"/NAMED_ETC="'$named_etc'"/' $adblock_conf_dir/adblock.conf || exit 3

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

if ! grep -q 'include.*named-adblock\.conf' $named_conf ; then
	echo
	echo "You will need to add a directive to include named-adblock.conf into your named.conf."
	echo "If you have a standard installation, you can do:"
	echo
	echo "echo 'include \"named-adblock.conf\";' >> $named_conf"
fi
