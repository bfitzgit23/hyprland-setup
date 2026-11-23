# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# guru ships 4.17.1, which imports proton.vpn.core.vpnconnector -- a module that
# dev-python/proton-vpn-api-core dropped when it went to 4.19 (VPNConnector now
# lives in proton.vpn.core.connection). Since api-core 0.46.x is python3_13-only
# the 4.19 line is what gets installed, so the app has to be 4.19 too.

EAPI=8

DISTUTILS_SINGLE_IMPL=true
DISTUTILS_USE_PEP517=setuptools

PYTHON_COMPAT=( python3_{13..14} )

inherit desktop distutils-r1

DESCRIPTION="Proton VPN GTK app"
HOMEPAGE="https://github.com/ProtonVPN/proton-vpn-gtk-app"
SRC_URI="https://github.com/ProtonVPN/proton-vpn-gtk-app/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"
RESTRICT="test"

RDEPEND="
	$(python_gen_cond_dep '
		dev-python/dbus-python[${PYTHON_USEDEP}]
		dev-python/distro[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
		dev-python/proton-core[${PYTHON_USEDEP}]
		dev-python/proton-keyring-linux[${PYTHON_USEDEP}]
		>=dev-python/proton-vpn-api-core-4.19.1[${PYTHON_USEDEP}]
		dev-python/proton-vpn-local-agent[${PYTHON_USEDEP}]
		dev-python/proton-vpn-network-manager[${PYTHON_USEDEP}]
		dev-python/pycairo[${PYTHON_USEDEP}]
		dev-python/pygobject[${PYTHON_USEDEP}]
		dev-python/requests[${PYTHON_USEDEP}]
	')
"

src_install() {
	distutils-r1_src_install

	doicon rpmbuild/SOURCES/proton-vpn-logo.svg
	domenu rpmbuild/SOURCES/proton.vpn.app.gtk.desktop
}
