#!/usr/bin/env bash
#
# Download and create a rootfs for concourse container
set -euo pipefail

declare -r version=2.0.0
declare -r sha256=e9f9cbc71bc04cc00d4d9092df69a77b7b865aa0cfd0d61d21bf89d250b739d5

declare -r src=${PWD}/container
declare -r glibc=${PWD}/glibc
declare -r rootfs=${PWD}/rootfs
declare -r out=${PWD}/out

download() {
  mkdir -p ${rootfs}/bin
  curl -L "https://github.com/concourse/concourse/releases/download/v${version}/concourse_linux_amd64" \
       -o ${rootfs}/bin/concourse
  echo "${sha256}  ${rootfs}/bin/concourse" | sha256sum -c
  chmod +x ${rootfs}/bin/concourse
}

build_rootfs() {
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
  tar -cf ${out}/{rootfs}.tar -C ${rootfs} .
    
  cat <<EOF > ${out}/tag
${version}
EOF

  cat <<EOF > ${out}/Dockerfile
FROM scratch

ADD {rootfs}.tar /

ENV \
  PATH=/bin \
  LD_LIBRARY_PATH=/lib

ENTRYPOINT [ "/bin/concourse" ]
EOF
}

download
build_rootfs
dockerfile
