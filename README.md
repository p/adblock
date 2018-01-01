# Adblock

Adblock works in conjunction with [BIND](https://www.isc.org/downloads/bind/)
to configure and maintain a list of blocked DNS zones.
It is similar to using a [hosts file](http://someonewhocares.org/hosts/).
DNS level ad blocking comes with two advantages:

1. It is possible to block entire *zones* rather than individual hosts.
For example, blocking `doubleclick.net` drops all requests to any of their
subdomains. This saves a lot of work for companies that use multiple
subdomains to get around ad blocking or simply as a form of load balancing,
as well as improves runtime performance as the block table is much smaller.

2. The ad blocking DNS server can be installed on a network gateway and
transparently block ads on the entire network, without requiring configuration
of each computer.

## Installation

First you need to install BIND if you don't already have it.
On Debian try `apt-get install bind9`.

Adblock knows how to install itself on FreeBSD, OpenBSD and Debian GNU/Linux.
Other operating systems should be quite easy to add support for.

Clone the repository locally, then execute:

    # with root privileges:
    ./install.sh

    # without root privileges:
    sudo sh install.sh
    
Adblock will copy its configuration files and print the location where
they are installed. At the bottom of the output will be a command similar
to the following which you can run verbatim on a standard system:

    echo 'include "/etc/bind/named.conf.adblock";' >> /etc/bind/named.conf.local

You can also edit the installed adblock zone, whose path will be similar to
`/etc/bind/db.adblock`, if you wish to resolve blocked domains to a
different IP than 127.0.0.1.

Finally restart BIND for the changes to take effect
(`/etc/init.d/bind9 restart`, etc.).

If you are installing adblock on a network gateway, most likely no further
configuration is needed. Try blocking a domain:

    adblock doubleclick.net

### BIND Forwarders

If you are installing adblock on a laptop there is
an extra step which is configuring dhclient and BIND forwarders.
This makes the laptop use its local BIND instance first for DNS resolution,
providing ad blocking functionality, but then forwards DNS queries to
DNS servers specified for the local network. The last step is necessary
as some networks do not allow using external DNS servers for name resolution.

Find the BIND configuration file that contains a forwarders declaration,
it will often be commented out:

    # FreeBSD
    grep -r forwarders /etc/namedb/
    
    # Debian
    grep -r forwarders /etc/bind

As Debian splits BIND configuration files, the correct file to edit
on my system is `/etc/bind/named.conf.options`.
Edit it to have a line like this:

    forwarders { 0.0.0.0; };

Ensure that there are no extra spaces around the braces as the dhclient
hook script is fairly primitive in its matching logic.

Then place the `dhclient-exit-hooks` script that comes with adblock
into a location appropriate for your system, for example for Debian
this can be accomplished as follows:

    sudo cp dhclient-exit-hooks /etc/dhcp/dhclient-exit-hooks.d/adblock-exit-hooks

Then edit the installed file, `/etc/dhcp/dhclient-exit-hooks.d/adblock-exit-hooks`
in this case. Check that the path to `named.conf` is correct for your system
and points to the file containing the `forwarders` declaration.
You can also whitelist certain nameservers - for instance,
if you have adblock installed on your home network you may wish to
forward all queries straight to your network's DNS server when you are
on that network.

Now try restarting the network:

    sudo ifdown eth0; sudo ifup eth0

If you get any error messages from the dhclient exit hook, you can debug it
by placing the following line after the shebang:

    set -x
    
If the hook worked correctly, your `/etc/resolv.conf` will point
at the local BIND instance and will look like this:

    nameserver 127.0.0.1

... and in `/etc/bind/named.conf.options` you'll have something like the
following:

    forwarders { 192.168.10.1; };

If you got this far, enjoy a faster, leaner Web!

## Usage

Blocking a domain is easy:

    adblock facebook.com

To unblock a domain, manually remove it from adblock's BIND configuration
file, e.g. `/etc/bind/named.conf.adblock`.

## License

Adblock is released under the MIT license.
