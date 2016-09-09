#!/usr/bin/env bash
#
# Download and create a rootfs for concourse container
set -euo pipefail

declare -r version=2.1.0
declare -r sha256=ee8f17cca506bcf7f40ed4c23823f98551a1d5e5961155d0c47785ff34978dde

declare -r src=${PWD}/container
declare -r glibc=${PWD}/glibc
declare -r rootfs=${PWD}/rootfs
declare -r out=${PWD}/out

download() {
  mkdir -p ${rootfs}/opt/bin
  curl -L "https://github.com/concourse/concourse/releases/download/v${version}/concourse_linux_amd64" \
       -o ${rootfs}/opt/bin/concourse
  echo "${sha256}  ${rootfs}/opt/bin/concourse" | sha256sum -c
  chmod +x ${rootfs}/opt/bin/concourse
}

build() {
  mkdir -p ${rootfs}/lib64 ${rootfs}/etc/ssl/certs
  cp \
    ${glibc}/libc.so.* \
    ${glibc}/nptl/libpthread.so.* \
    ${glibc}/elf/ld-linux-x86-64.so.* \
    ${rootfs}/lib64

  ln -s /lib64 ${rootfs}/lib

  cp /etc/pki/tls/certs/ca-bundle.crt ${rootfs}/etc/ssl/certs/ca-certificates.crt

  cat <<EOF > ${rootfs}/etc/nsswitch.conf
hosts: files mdns4_minimal dns [NOTFOUND=return] mdns4
EOF

  cat <<EOF > ${rootfs}/etc/passwd
root:x:0:0:root:/:/dev/null
nobody:x:65534:65534:nogroup:/:/dev/null
EOF

  cat <<EOF > ${rootfs}/etc/group
root:x:0:
nogroup:x:65534:
EOF
}

dockerfile() {
  tar -cf ${out}/rootfs.tar -C ${rootfs} .

  cat <<EOF > ${out}/tag
${version}
EOF

  cat <<EOF > ${out}/Dockerfile
FROM scratch

ADD rootfs.tar /

ENV \
  PATH=/opt/bin:/bin \
  LD_LIBRARY_PATH=/lib64

ENTRYPOINT [ "/opt/bin/concourse" ]
EOF
}

download
build
dockerfile
