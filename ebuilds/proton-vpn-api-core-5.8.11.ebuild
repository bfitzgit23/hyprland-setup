# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# Copied from guru's 4.19.1 ebuild, bumped to 5.8.11 (the release the GTK app
# 4.19.1 needs) and extended: upstream is a mixed Rust/Python project whose
# crate `proton-vpn-platform` produces platform.abi3.so, installed as
# proton/vpn/platform. The plain python-only ebuild never built it, so
# `import proton.vpn.platform` failed and the app died on start.
#
# The crate's `dependencies/protun` submodule is absent from the source tarball
# and its git URL (ProtonVPN/development/protun) returns 404, so a stub path
# dependency is generated below. It only has to satisfy cargo's resolver: the
# `protun`/`sdk` features are not enabled for this build.

EAPI=8

DISTUTILS_SINGLE_IMPL=true
DISTUTILS_USE_PEP517=setuptools

PYTHON_COMPAT=( python3_{13..14} )

inherit distutils-r1

DESCRIPTION="Proton AG VPN Core API"
HOMEPAGE="https://github.com/ProtonVPN/python-proton-vpn-api-core"
SRC_URI="https://github.com/ProtonVPN/python-proton-vpn-api-core/archive/refs/tags/v${PV}.tar.gz -> ${P}.tar.gz"

S="${WORKDIR}/python-${P}"
LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="~amd64"
IUSE="test"
RESTRICT="!test? ( test ) network-sandbox"

BDEPEND="
	virtual/rust
"
RDEPEND="
	$(python_gen_cond_dep '
		dev-python/cryptography[${PYTHON_USEDEP}]
		dev-python/dbus-fast[${PYTHON_USEDEP}]
		dev-python/distro[${PYTHON_USEDEP}]
		dev-python/fido2[${PYTHON_USEDEP}]
		dev-python/jinja2[${PYTHON_USEDEP}]
		dev-python/packaging[${PYTHON_USEDEP}]
		>=dev-python/proton-core-0.5.0[${PYTHON_USEDEP}]
		dev-python/pycairo[${PYTHON_USEDEP}]
		dev-python/pygobject[${PYTHON_USEDEP}]
		dev-python/pynacl[${PYTHON_USEDEP}]
		dev-python/sentry-sdk[${PYTHON_USEDEP}]
	')
"

distutils_enable_sphinx docs
distutils_enable_tests pytest

src_prepare() {
	# Stub for the missing submodule; see the header.
	mkdir -p dependencies/protun/src || die
	cat > dependencies/protun/Cargo.toml <<-'EOF' || die
		[package]
		name = "protun"
		version = "0.8.11"
		edition = "2021"

		[features]
		default = []
		unix = []

		[lib]
		path = "src/lib.rs"
	EOF
	: > dependencies/protun/src/lib.rs || die

	distutils-r1_src_prepare
}

python_compile() {
	# The cdylib is not produced by setup.py; build it from the crate. It is
	# installed in python_install_all below (package_data alone does not pick
	# it up reliably through the PEP517 wheel build).
	export PYO3_PYTHON="$(type -P "${EPYTHON}")"
	export CARGO_HOME="${T}/cargo-home"
	export PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1

	pushd "${S}" >/dev/null || die
	cargo build --release --no-default-features 		--features "python,core,telemetry,local_agent" || die
	popd >/dev/null || die

	distutils-r1_python_compile
}

python_install_all() {
	distutils-r1_python_install_all

	# proton/vpn/platform.abi3.so is the Python entry point for the crate.
	local sitedir
	sitedir="$(python_get_sitedir)/proton/vpn"
	insinto "${sitedir}"
	newins "${S}/target/release/libproton_vpn_platform.so" platform.abi3.so
}

python_test() {
	# VPN connection cannot be tested within sandbox
	local EPYTEST_IGNORE=(
		tests/connection
		tests/core/refresher
		tests/core/test_{connection,settings}.py
	)

	XDG_RUNTIME_DIR="${T}/python_test" epytest
}
