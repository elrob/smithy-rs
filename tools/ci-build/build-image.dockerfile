#
# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0.
#
ARG base_image=public.ecr.aws/amazonlinux/amazonlinux:2
FROM ${base_image} AS bare_base_image

#
# Node Installation Stage
#
FROM bare_base_image AS install_node
ARG node_version=v16.14.0
ARG node_bundle_sha256=0570b9354959f651b814e56a4ce98d4a067bf2385b9a0e6be075739bc65b0fae
ENV DEST_PATH=/opt/nodejs \
    PATH=/opt/nodejs/bin:${PATH}
RUN yum -y updateinfo && \
    yum -y install \
        ca-certificates \
        curl \
        tar \
        xz && \
    yum clean all
WORKDIR /root
RUN set -eux; \
    curl https://nodejs.org/dist/${node_version}/node-${node_version}-linux-x64.tar.xz --output node.tar.xz; \
    echo "${node_bundle_sha256}  node.tar.xz" | sha256sum --check; \
    mkdir -p "${DEST_PATH}"; \
    tar -xJvf node.tar.xz -C "${DEST_PATH}"; \
    mv "${DEST_PATH}/node-${node_version}-linux-x64/"* "${DEST_PATH}"; \
    rmdir "${DEST_PATH}"/node-${node_version}-linux-x64; \
    rm node.tar.xz; \
    node --version

#
# Rust & Tools Installation Stage
#
FROM bare_base_image AS install_rust
ARG rust_stable_version=1.56.1
ARG rust_nightly_version=nightly-2022-03-03
ARG cargo_udeps_version=0.1.27
ARG cargo_hack_version=0.5.12
ARG smithy_rs_revision=main
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo \
    PATH=/opt/cargo/bin/:${PATH}
WORKDIR /root
RUN yum -y updateinfo && \
    yum -y install \
        autoconf \
        automake \
        binutils \
        ca-certificates \
        curl \
        gcc \
        gcc-c++ \
        git \
        make \
        openssl-devel \
        pkgconfig && \
    yum clean all
RUN set -eux; \
    curl https://static.rust-lang.org/rustup/archive/1.24.3/x86_64-unknown-linux-gnu/rustup-init --output rustup-init; \
    echo "3dc5ef50861ee18657f9db2eeb7392f9c2a6c95c90ab41e45ab4ca71476b4338 rustup-init" | sha256sum --check; \
    chmod +x rustup-init; \
    ./rustup-init -y --no-modify-path --profile minimal --default-toolchain ${rust_stable_version}; \
    rm rustup-init; \
    rustup --version; \
    rustup install ${rust_nightly_version}; \
    cargo --version; \
    cargo +${rust_nightly_version} --version;
RUN set -eux; \
    cargo +${rust_nightly_version} install cargo-udeps --version ${cargo_udeps_version}; \
    cargo install cargo-hack --version ${cargo_hack_version}; \
    git clone https://github.com/awslabs/smithy-rs.git; \
    cd smithy-rs; \
    git checkout ${smithy_rs_revision}; \
    cargo install --path tools/publisher; \
    cargo +${rust_nightly_version} install --path tools/api-linter;

#
# Final image
#
FROM bare_base_image AS final_image
ARG rust_stable_version=1.56.1
ARG rust_nightly_version=nightly-2022-03-03
WORKDIR /root
RUN yum -y updateinfo && \
    yum -y install \
        ca-certificates \
        git \
        java-11-amazon-corretto-headless \
        python3 && \
    yum clean all && \
    rm -rf /var/cache/yum
COPY --from=install_node /opt/nodejs /opt/nodejs
ENV PATH=/opt/nodejs/bin:$PATH
COPY --from=install_rust /opt/cargo /opt/cargo
COPY --from=install_rust /opt/rustup /opt/rustup
ENV PATH=/opt/cargo/bin:$PATH \
    CARGO_HOME=/opt/cargo \
    RUSTUP_HOME=/opt/rustup \
    RUST_NIGHTLY_VERSION=${rust_nightly_version}
COPY ./scripts /root/scripts
RUN /root/scripts/sanity-test
