# Copyright 1999-2017 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

EAPI=6
CMAKE_MAKEFILE_GENERATOR="ninja"
PYTHON_COMPAT=( python2_7 )
USE_RUBY="ruby21 ruby22 ruby23 ruby24"

inherit check-reqs cmake-utils eutils flag-o-matic gnome2 pax-utils python-any-r1 ruby-single toolchain-funcs versionator virtualx

MY_P="webkitgtk-${PV}"
DESCRIPTION="Open source web browser engine"
HOMEPAGE="http://www.webkitgtk.org/"
SRC_URI="http://www.webkitgtk.org/releases/${MY_P}.tar.xz"

LICENSE="LGPL-2+ BSD"
SLOT="4/37" # soname version of libwebkit2gtk-4.0
KEYWORDS="~alpha ~amd64 ~arm ~arm64 ~ia64 ~ppc ~ppc64 ~sparc ~x86 ~amd64-fbsd ~x86-fbsd ~amd64-linux ~x86-linux ~x86-macos"

IUSE="aqua coverage doc +egl +geolocation gles2 gnome-keyring +gstreamer +introspection +jit libnotify nsplugin +opengl spell wayland +webgl X"

# webgl needs gstreamer, bug #560612
REQUIRED_USE="
	geolocation? ( introspection )
	gles2? ( egl )
	introspection? ( gstreamer )
	nsplugin? ( X )
	webgl? ( ^^ ( gles2 opengl ) )
	!webgl? ( ?? ( gles2 opengl ) )
	webgl? ( gstreamer )
	wayland? ( egl )
	|| ( aqua wayland X )
"

# Tests fail to link for inexplicable reasons
# https://bugs.webkit.org/show_bug.cgi?id=148210
RESTRICT="test"

# use sqlite, svg by default
# Aqua support in gtk3 is untested
# Dependencies found at Source/cmake/OptionsGTK.cmake
# Various compile-time optionals for gtk+-3.22.0 - ensure it
RDEPEND="
	dev-db/sqlite:3=
	>=dev-libs/glib-2.36:2
	dev-libs/hyphen
	>=dev-libs/icu-3.8.1-r1:=
	>=dev-libs/libxml2-2.8:2
	>=dev-libs/libxslt-1.1.7
	>=media-libs/fontconfig-2.8:1.0
	>=media-libs/freetype-2.4.2:2
	>=media-libs/harfbuzz-1.3.3:=[icu(+)]
	>=media-libs/libpng-1.4:0=
	media-libs/libwebp:=
	dev-libs/libgcrypt:0=
	>=net-libs/libsoup-2.42:2.4[introspection?]
	>=x11-libs/cairo-1.10.2:=
	>=x11-libs/gtk+-3.22:3[introspection?]
	>=x11-libs/pango-1.30.0
	virtual/jpeg:0=

	aqua? ( >=x11-libs/gtk+-3.14:3[aqua] )
	egl? ( media-libs/mesa[egl] )
	geolocation? ( >=app-misc/geoclue-2.1.5:2.0 )
	gles2? ( media-libs/mesa[gles2] )
	gnome-keyring? ( app-crypt/libsecret )
	gstreamer? (
		>=media-libs/gstreamer-1.2.3:1.0
		>=media-libs/gst-plugins-base-1.2.3:1.0
		>=media-libs/gst-plugins-bad-1.8:1.0[opengl?] )
	introspection? ( >=dev-libs/gobject-introspection-1.32.0:= )
	libnotify? ( x11-libs/libnotify )
	nsplugin? ( >=x11-libs/gtk+-2.24.10:2 )
	opengl? ( virtual/opengl
		x11-libs/cairo[opengl] )
	spell? ( >=app-text/enchant-0.22:= )
	wayland? ( >=x11-libs/gtk+-3.14:3[wayland] )
	webgl? (
		x11-libs/cairo[opengl]
		x11-libs/libXcomposite
		x11-libs/libXdamage )
	X? (
		x11-libs/cairo[X]
		>=x11-libs/gtk+-3.14:3[X]
		x11-libs/libX11
		x11-libs/libXcomposite
		x11-libs/libXrender
		x11-libs/libXt )
"

# paxctl needed for bug #407085
# Need real bison, not yacc
DEPEND="${RDEPEND}
	${PYTHON_DEPS}
	${RUBY_DEPS}
	>=dev-lang/perl-5.10
	>=app-accessibility/at-spi2-core-2.5.3
	>=dev-libs/atk-2.8.0
	>=dev-util/gtk-doc-am-1.10
	>=dev-util/gperf-3.0.1
	>=sys-devel/bison-2.4.3
	|| ( >=sys-devel/gcc-4.9 >=sys-devel/clang-3.3 )
	sys-devel/gettext
	virtual/pkgconfig

	dev-lang/perl
	virtual/perl-Data-Dumper
	virtual/perl-Carp

	doc? ( >=dev-util/gtk-doc-1.10 )
	geolocation? ( dev-util/gdbus-codegen )
	introspection? ( jit? ( sys-apps/paxctl ) )
	test? (
		dev-lang/python:2.7
		dev-python/pygobject:3[python_targets_python2_7]
		x11-themes/hicolor-icon-theme
		jit? ( sys-apps/paxctl ) )
"

S="${WORKDIR}/${MY_P}"

CHECKREQS_DISK_BUILD="18G" # and even this might not be enough, bug #417307

PATCHES=(
	# https://bugs.gentoo.org/show_bug.cgi?id=555504
	"${FILESDIR}"/${PN}-2.8.5-fix-ia64-build.patch

	# https://bugs.gentoo.org/show_bug.cgi?id=564352
	# https://bugs.webkit.org/show_bug.cgi?id=167283
	"${FILESDIR}"/${PN}-2.8.5-fix-alpha-build.patch
)

pkg_pretend() {
	if [[ ${MERGE_TYPE} != "binary" ]] ; then
		if is-flagq "-g*" && ! is-flagq "-g*0" ; then
			einfo "Checking for sufficient disk space to build ${PN} with debugging CFLAGS"
			check-reqs_pkg_pretend
		fi

		if ! test-flag-CXX -std=c++11 ; then
			die "You need at least GCC 4.9.x or Clang >= 3.3 for C++11-specific compiler flags"
		fi

		if tc-is-gcc && [[ $(gcc-version) < 4.9 ]] ; then
			die 'The active compiler needs to be gcc 4.9 (or newer)'
		fi
	fi
}

pkg_setup() {
	if [[ ${MERGE_TYPE} != "binary" ]] && is-flagq "-g*" && ! is-flagq "-g*0" ; then
		check-reqs_pkg_setup
	fi

	python-any-r1_pkg_setup
}

src_configure() {
	# Respect CC, otherwise fails on prefix #395875
	tc-export CC

	# Arches without JIT support also need this to really disable it in all places
	use jit || append-cppflags -DENABLE_JIT=0 -DENABLE_YARR_JIT=0 -DENABLE_ASSEMBLER=0

	# It does not compile on alpha without this in LDFLAGS
	# https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=648761
	use alpha && append-ldflags "-Wl,--no-relax"

	# ld segfaults on ia64 with LDFLAGS --as-needed, bug #555504
	use ia64 && append-ldflags "-Wl,--no-as-needed"

	# Sigbuses on SPARC with mcpu and co., bug #???
	use sparc && filter-flags "-mvis"

	# https://bugs.webkit.org/show_bug.cgi?id=42070 , #301634
	use ppc64 && append-flags "-mminimal-toc"

	# Try to use less memory, bug #469942 (see Fedora .spec for reference)
	# --no-keep-memory doesn't work on ia64, bug #502492
	if ! use ia64; then
		append-ldflags "-Wl,--no-keep-memory"
	fi

	# We try to use gold when possible for this package
#	if ! tc-ld-is-gold ; then
#		append-ldflags "-Wl,--reduce-memory-overheads"
#	fi

	# older glibc needs this for INTPTR_MAX, bug #533976
	if has_version "<sys-libs/glibc-2.18" ; then
		append-cppflags "-D__STDC_LIMIT_MACROS"
	fi

	# Multiple rendering bugs on youtube, github, etc without this, bug #547224
	append-flags $(test-flags -fno-strict-aliasing)

	local ruby_interpreter=""

	if has_version "virtual/rubygems[ruby_targets_ruby24]"; then
		ruby_interpreter="-DRUBY_EXECUTABLE=$(type -P ruby24)"
	elif has_version "virtual/rubygems[ruby_targets_ruby23]"; then
		ruby_interpreter="-DRUBY_EXECUTABLE=$(type -P ruby23)"
	elif has_version "virtual/rubygems[ruby_targets_ruby22]"; then
		ruby_interpreter="-DRUBY_EXECUTABLE=$(type -P ruby22)"
	else
		ruby_interpreter="-DRUBY_EXECUTABLE=$(type -P ruby21)"
	fi

	# TODO: Check Web Audio support
	# should somehow let user select between them?
	#
	# FTL_JIT requires llvm
	#
	# opengl needs to be explicetly handled, bug #576634

	local opengl_enabled
	if use opengl || use gles2; then
		opengl_enabled=ON
	else
		opengl_enabled=OFF
	fi

	# support for webgl (aka 2d-canvas accelerating)
	local canvas_enabled
	if use webgl && ! use gles2 ; then
		canvas_enabled=ON
	else
		canvas_enabled=OFF
	fi

	local mycmakeargs=(
		-DENABLE_QUARTZ_TARGET=$(usex aqua)
		-DENABLE_API_TESTS=$(usex test)
		-DENABLE_GTKDOC=$(usex doc)
		-DENABLE_GEOLOCATION=$(usex geolocation)
		$(cmake-utils_use_find_package gles2 OpenGLES2)
		-DENABLE_GLES2=$(usex gles2)
		-DENABLE_VIDEO=$(usex gstreamer)
		-DENABLE_WEB_AUDIO=$(usex gstreamer)
		-DENABLE_INTROSPECTION=$(usex introspection)
		-DENABLE_JIT=$(usex jit)
		-DUSE_LIBNOTIFY=$(usex libnotify)
		-DUSE_LIBSECRET=$(usex gnome-keyring)
		-DENABLE_PLUGIN_PROCESS_GTK2=$(usex nsplugin)
		-DENABLE_SPELLCHECK=$(usex spell)
		-DENABLE_WAYLAND_TARGET=$(usex wayland)
		-DENABLE_WEBGL=$(usex webgl)
		$(cmake-utils_use_find_package egl EGL)
		$(cmake-utils_use_find_package opengl OpenGL)
		-DENABLE_X11_TARGET=$(usex X)
		-DENABLE_OPENGL=${opengl_enabled}
		-DENABLE_ACCELERATED_2D_CANVAS=${canvas_enabled}
		-DCMAKE_BUILD_TYPE=Release
		-DPORT=GTK
		${ruby_interpreter}
	)

	# Allow it to use GOLD when possible as it has all the magic to
	# detect when to use it and using gold for this concrete package has
	# multiple advantages and is also the upstream default, bug #585788
#	if tc-ld-is-gold ; then
#		mycmakeargs+=( -DUSE_LD_GOLD=ON )
#	else
#		mycmakeargs+=( -DUSE_LD_GOLD=OFF )
#	fi

	cmake-utils_src_configure
}

src_compile() {
	cmake-utils_src_compile
}

src_test() {
	# Prevents test failures on PaX systems
	use jit && pax-mark m $(list-paxables Programs/*[Tt]ests/*) # Programs/unittests/.libs/test*

	cmake-utils_src_test
}

src_install() {
	cmake-utils_src_install

	# Prevents crashes on PaX systems, bug #522808
	use jit && pax-mark m "${ED}usr/bin/jsc" "${ED}usr/libexec/webkit2gtk-4.0/WebKitWebProcess"
	pax-mark m "${ED}usr/libexec/webkit2gtk-4.0/WebKitPluginProcess"
	use nsplugin && pax-mark m "${ED}usr/libexec/webkit2gtk-4.0/WebKitPluginProcess"2
}
