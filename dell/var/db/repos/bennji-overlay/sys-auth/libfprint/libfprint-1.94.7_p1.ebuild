# Copyright 1999-2025 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Canonical's libfprint branch: upstream 1.94.7 plus the Touch-OEM-Driver
# loader (meson option 'tod', on by default here). Stock upstream libfprint has
# no TOD support at all, so a Dell/Canonical TOD blob such as
# libfprint-2-tod1-broadcom.so can never be loaded by it. Same SONAME and slot
# as sys-auth/libfprint, so fprintd works unchanged.

EAPI=8

inherit meson udev

MY_PV="1.94.7+tod1"

DESCRIPTION="Library to add support for consumer fingerprint readers (TOD build)"
HOMEPAGE="
	https://fprint.freedesktop.org/
	https://gitlab.freedesktop.org/libfprint/libfprint
"
SRC_URI="http://archive.ubuntu.com/ubuntu/pool/main/libf/libfprint/libfprint_${MY_PV}.orig.tar.bz2 -> libfprint-${MY_PV}.orig.tar.bz2"

LICENSE="LGPL-2.1+"
SLOT="2"
KEYWORDS="~amd64"
IUSE="examples gtk-doc +introspection"

RDEPEND="
	dev-libs/glib:2
	dev-libs/libgudev
	dev-libs/nss
	dev-python/pygobject
	dev-libs/libgusb
	x11-libs/pixman
	examples? (
		x11-libs/gdk-pixbuf:2
		x11-libs/gtk+:3
	)
"

DEPEND="${RDEPEND}"

BDEPEND="
	dev-util/glib-utils
	sys-devel/gettext
	virtual/pkgconfig
	gtk-doc? ( dev-util/gtk-doc )
	introspection? (
		>=dev-libs/gobject-introspection-1.82.0-r2
		dev-libs/libgusb[introspection]
	)
"

S="${WORKDIR}/libfprint-v${MY_PV}"

src_configure() {
	local emesonargs=(
		$(meson_use examples gtk-examples)
		$(meson_use gtk-doc doc)
		$(meson_use introspection introspection)
		-Ddrivers=all
		-Dtod=true
		-Dinstalled-tests=false
		-Dudev_rules=enabled
		-Dudev_rules_dir=$(get_udevdir)/rules.d
	)

	meson_src_configure
}

pkg_postinst() {
	udev_reload
}

pkg_postrm() {
	udev_reload
}
