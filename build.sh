#!/usr/bin/env bash
#
# Download and create a rootfs for concourse container
set -euo pipefail

declare -r src=${PWD}/container
declare -r glibc=${PWD}/glibc
declare -r rootfs=${PWD}/rootfs
declare -r out=${PWD}/out

# _download "version" "sha256"
_download() {
  mkdir -p ${rootfs}/opt/bin
  curl -sS -L "https://github.com/concourse/concourse/releases/download/v${1}/concourse_linux_amd64" \
       -o ${rootfs}/opt/bin/concourse
  echo "${2}  ${rootfs}/opt/bin/concourse" | sha256sum -c
  chmod +x ${rootfs}/opt/bin/concourse
}

_build() {
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

# _dockerfile "version"
_dockerfile() {
  tar -cf ${out}/rootfs.tar -C ${rootfs} .

  cat <<EOF > ${out}/tag
${1}
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

_download 2.2.1 1166d6b7923d54e97e07f8980a2b6a30da39d6120762f2fde65b62691956b5ea
_build
_dockerfile 2.2.1
