# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  stdenv,
  fetchFromGitHub,
  lib,
  libmicrohttpd,
  boost,
  curl,
  openssl,
  libuuid,
  mosquitto,
  gnutls,
  cyrus_sasl,
  libgcrypt,
  rapidjson,
  mongoc,
  git,
  cmake,
  callPackage,
}:
stdenv.mkDerivation {
  name = "fiware-orion";

  src = fetchFromGitHub {
    owner = "telefonicaid";
    repo = "fiware-orion";
    rev = "3.12.0";
    hash = "sha256-e2v1nB6KTu51Gvdk8OPiFqtwdcd4fAN3cMIMJ+TG0CU=";
  };

  postPatch = ''
    patchShebangs --build ./scripts/

    substituteInPlace ./CMakeLists.txt \
        --replace /usr/local/include/libmongoc-1.0 ${mongoc}/include/libmongoc-1.0 \
        --replace /usr/local/include/libbson-1.0 ${mongoc}/include/libbson-1.0 \
        --replace microhttpd.a microhttpd \
        --replace mosquitto.a mosquitto \
        --replace '"/usr/lib/x86_64-linux-gnu"' '"${mongoc}/lib" "${mosquitto.lib}/lib" "${libmicrohttpd}/lib"'

    cat CMakeLists.txt
    ./scripts/build/compileInfo.sh --release
  '';

  cmakeFlags = [ "-DCMAKE_SKIP_BUILD_RPATH=ON" ];

  buildInputs = [
    git
    cmake

    gnutls
    libgcrypt
    cyrus_sasl
    libmicrohttpd
    mosquitto
    boost
    curl
    openssl
    libuuid
    mongoc
    rapidjson
  ];
}
