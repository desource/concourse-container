#!/usr/bin/env bash
#
# Download and create a rootfs for concourse container
set -euo pipefail

declare -r src=${PWD}/container
declare -r glibc=${PWD}/glibc
declare -r rootfs=${PWD}/rootfs
declare -r out=${PWD}/out

declare -r iptables=${PWD}/iptables

_init() {
    dnf install -y \
        bzip2 \
        libuuid-devel \
        libattr-devel \
        zlib-devel \
        libacl-devel \
        e2fsprogs-devel \
        libblkid-devel \
        lzo-devel \
        asciidoc \
        xmlto \
        glibc-static
}

_iptables() {
    curl -sS -L "http://www.netfilter.org/projects/iptables/files/iptables-1.4.21.tar.bz2"
}

_lzo2() {
  curl -OL http://www.oberhumer.com/opensource/lzo/download/lzo-2.09.tar.gz
}

_btrfs() {
  curl https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v4.4.tar.gz
}

_libseccomp() {
  curl -L https://github.com/seccomp/libseccomp/releases/download/v2.3.1/libseccomp-2.3.1.tar.gz
}

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

_download 2.4.0 834fdcaab9aa2e7c5a186d301975a8916bbaa3e179d25ad1033ade86cd43dd13
_build
_dockerfile 2.4.0
