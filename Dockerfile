###########################################
###########################################
## Dockerfile to run GitHub Super-Linter ##
###########################################
###########################################

#########################################
# Get dependency images as build stages #
#########################################
FROM cljkondo/clj-kondo:2021.12.19-alpine as clj-kondo
FROM dotenvlinter/dotenv-linter:3.1.1 as dotenv-linter
FROM mstruebing/editorconfig-checker:2.4.0 as editorconfig-checker
FROM yoheimuta/protolint:v0.35.2 as protolint
FROM golangci/golangci-lint:v1.43.0 as golangci-lint
FROM koalaman/shellcheck:v0.8.0 as shellcheck
FROM ghcr.io/terraform-linters/tflint-bundle:v0.34.1.1 as tflint
FROM alpine/terragrunt:1.1.2 as terragrunt
FROM mvdan/shfmt:v3.4.2 as shfmt
FROM accurics/terrascan:1.12.0 as terrascan
FROM hadolint/hadolint:latest-alpine as dockerfile-lint
FROM assignuser/chktex-alpine:v0.1.1 as chktex
FROM zricethezav/gitleaks:v8.2.5 as gitleaks
FROM garethr/kubeval:0.15.0 as kubeval
FROM ghcr.io/awkbar-devops/clang-format:v1.0.2 as clang-format
FROM scalameta/scalafmt:v3.3.1 as scalafmt
FROM rhysd/actionlint:1.6.8 as actionlint

##################
# Get base image #
##################
FROM python:3.10.1-alpine as base_image

################################
# Set ARG values used in Build #
################################
# Dart Linter
## stable dart sdk: https://dart.dev/get-dart#release-channels
ARG DART_VERSION='2.8.4'
## install alpine-pkg-glibc (glibc compatibility layer package for Alpine Linux)
ARG GLIBC_VERSION='2.31-r0'
# Unicode version info
ARG UNICODE_VERSION='2021-11-01-1136'

####################
# Run APK installs #
####################
RUN apk add --no-cache \
    bash \
    ca-certificates \
    cargo \
    coreutils \
    curl \
    file \
    gcc \
    g++ \
    git git-lfs\
    gnupg \
    go \
    icu-libs \
    jpeg-dev \
    jq \
    krb5-libs \
    libc-dev libcurl libffi-dev libgcc \
    libintl libssl1.1 libstdc++ \
    libxml2-dev libxml2-utils \
    linux-headers \
    lttng-ust-dev \
    make \
    musl-dev \
    net-snmp-dev \
    npm nodejs-current \
    openjdk11-jre \
    openssl-dev \
    perl perl-dev \
    py3-setuptools python3-dev \
    R R-dev R-doc \
    readline-dev \
    ruby ruby-dev ruby-bundler ruby-rdoc \
    rustup \
    zlib zlib-dev

########################################
# Copy dependencies files to container #
########################################
COPY dependencies/* /

################################
# Installs dependencies #
################################
RUN wget --tries=5 -q https://access.redhat.com/sites/default/files/find_unicode_control2--${UNICODE_VERSION}.zip -O - -q | unzip -q - \
    && mv find_unicode_control2.py /usr/local/bin/find_unicode_control2.py \
    && chmod +x /usr/local/bin/find_unicode_control2.py \
    && npm config set package-lock false \
    && npm config set loglevel error \
    ####################
    # Run NPM Installs #
    ####################
    && npm --no-cache install \
    && npm audit fix --audit-level=critical \
    ##############################
    # Installs ruby dependencies #
    ##############################
    && bundle install \
    ###############################
    # Install python dependencies #
    ############################### \
    && ./build-python-binaries.sh

##############################
# Installs Perl dependencies #
##############################
RUN curl --retry 5 --retry-delay 5 -sL https://cpanmin.us/ | perl - -nq --no-wget Perl::Critic \
    ########################
    # Install Python Black #
    ########################
    && wget --tries=5 -q -O /usr/local/bin/black https://github.com/psf/black/releases/download/21.11b1/black_linux \
    && chmod +x /usr/local/bin/black \
    #######################
    # Installs ActionLint #
    #######################
    && curl --retry 5 --retry-delay 5 -sLO https://raw.githubusercontent.com/rhysd/actionlint/main/scripts/download-actionlint.bash \
    && chmod +x download-actionlint.bash \
    && ./download-actionlint.bash \
    && rm download-actionlint.bash \
    && mv actionlint /usr/bin/actionlint

######################
# Install shellcheck #
######################
COPY --from=shellcheck /bin/shellcheck /usr/bin/

#####################
# Install Go Linter #
#####################
COPY --from=golangci-lint /usr/bin/golangci-lint /usr/bin/

##################
# Install TFLint #
##################
COPY --from=tflint /usr/local/bin/tflint /usr/bin/
COPY --from=tflint /root/.tflint.d /root/.tflint.d

#####################
# Install Terrascan #
#####################
COPY --from=terrascan /go/bin/terrascan /usr/bin/

######################
# Install Terragrunt #
######################
COPY --from=terragrunt /usr/local/bin/terragrunt /usr/bin/

######################
# Install protolint #
######################
COPY --from=protolint /usr/local/bin/protolint /usr/bin/

#####################
# Install clj-kondo #
#####################
COPY --from=clj-kondo /bin/clj-kondo /usr/bin/

################################
# Install editorconfig-checker #
################################
COPY --from=editorconfig-checker /usr/bin/ec /usr/bin/editorconfig-checker

###############################
# Install hadolint dockerfile #
###############################
COPY --from=dockerfile-lint /bin/hadolint /usr/bin/hadolint

##################
# Install chktex #
##################
COPY --from=chktex /usr/bin/chktex /usr/bin/

###################
# Install kubeval #
###################
COPY --from=kubeval /kubeval /usr/bin/

#################
# Install shfmt #
#################
COPY --from=shfmt /bin/shfmt /usr/bin/

########################
# Install clang-format #
########################
COPY --from=clang-format /usr/bin/clang-format /usr/bin/

####################
# Install GitLeaks #
####################
COPY --from=gitleaks /usr/bin/gitleaks /usr/bin/

####################
# Install scalafmt #
####################
COPY --from=scalafmt /bin/scalafmt /usr/bin/

######################
# Install actionlint #
######################
COPY --from=actionlint /usr/local/bin/actionlint /usr/bin/

#################
# Install Lintr #
#################
RUN mkdir -p /home/r-library \
    && cp -r /usr/lib/R/library/ /home/r-library/ \
    && Rscript -e "install.packages(c('lintr','purrr'), repos = 'https://cloud.r-project.org/')" \
    && R -e "install.packages(list.dirs('/home/r-library',recursive = FALSE), repos = NULL, type = 'source')"

##################
# Install ktlint #
##################
RUN curl --retry 5 --retry-delay 5 -sSLO https://github.com/pinterest/ktlint/releases/latest/download/ktlint \
    && chmod a+x ktlint \
    && mv "ktlint" /usr/bin/ \
    && terrascan init \
    && cd ~ && touch .chktexrc \
    ####################
    # Install dart-sdk #
    ####################
    && wget --tries=5 -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && wget --tries=5 -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
    && apk add --no-cache glibc-${GLIBC_VERSION}.apk \
    && rm glibc-${GLIBC_VERSION}.apk \
    && wget --tries=5 -q https://storage.googleapis.com/dart-archive/channels/stable/release/${DART_VERSION}/sdk/dartsdk-linux-x64-release.zip -O - -q | unzip -q - \
    && chmod +x dart-sdk/bin/dart* \
    && mv dart-sdk/bin/* /usr/bin/ && mv dart-sdk/lib/* /usr/lib/ && mv dart-sdk/include/* /usr/include/ \
    && rm -r dart-sdk/ \
    ################################
    # Create and install Bash-Exec #
    ################################
    && printf '#!/bin/bash \n\nif [[ -x "$1" ]]; then exit 0; else echo "Error: File:[$1] is not executable"; exit 1; fi' > /usr/bin/bash-exec \
    && chmod +x /usr/bin/bash-exec

#################################################
# Install Raku and additional Edge dependencies #
#################################################
# Basic setup, programs and init
RUN apk add --no-cache rakudo zef \
    ######################
    # Install CheckStyle #
    ######################
    && CHECKSTYLE_LATEST=$(curl -s https://api.github.com/repos/checkstyle/checkstyle/releases/latest \
    | grep browser_download_url \
    | grep ".jar" \
    | cut -d '"' -f 4) \
    && curl --retry 5 --retry-delay 5 -sSL "$CHECKSTYLE_LATEST" \
    --output /usr/bin/checkstyle \
    ##############################
    # Install google-java-format #
    ##############################
    && GOOGLE_JAVA_FORMAT_VERSION=$(curl -s https://github.com/google/google-java-format/releases/latest \
    | cut -d '"' -f 2 | cut -d '/' -f 8 | sed -e 's/v//g') \
    && curl --retry 5 --retry-delay 5 -sSL \
    "https://github.com/google/google-java-format/releases/download/v$GOOGLE_JAVA_FORMAT_VERSION/google-java-format-$GOOGLE_JAVA_FORMAT_VERSION-all-deps.jar" \
    --output /usr/bin/google-java-format \
    #################################
    # Install luacheck and luarocks #
    #################################
    && wget --tries=5 -q https://www.lua.org/ftp/lua-5.3.5.tar.gz -O - -q | tar -xzf - \
    && cd lua-5.3.5 \
    && make linux \
    && make install \
    && cd .. && rm -r lua-5.3.5/ \
    && wget --tries=5 -q https://github.com/cvega/luarocks/archive/v3.3.1-super-linter.tar.gz -O - -q | tar -xzf - \
    && cd luarocks-3.3.1-super-linter \
    && ./configure --with-lua-include=/usr/local/include \
    && make \
    && make -b install \
    && cd .. \
    && rm -r luarocks-3.3.1-super-linter/ \
    && luarocks install luacheck \
    && luarocks install argparse \
    && luarocks install luafilesystem \
    && mv /etc/R/* /usr/lib/R/etc/ \
    && find /node_modules/ -type f -name 'LICENSE' -exec rm {} + \
    && find /node_modules/ -type f -name '*.md' -exec rm {} + \
    && find /node_modules/ -type f -name '*.txt' -exec rm {} + \
    && find /usr/ -type f -name '*.md' -exec rm {} +

################################################################################
# Grab small clean image #######################################################
################################################################################
FROM alpine:3.15.0 as final_slim

############################
# Get the build arguements #
############################
ARG BUILD_DATE
ARG BUILD_REVISION
ARG BUILD_VERSION
## install alpine-pkg-glibc (glibc compatibility layer package for Alpine Linux)
ARG GLIBC_VERSION='2.31-r0'

#########################################
# Label the instance and set maintainer #
#########################################
LABEL com.github.actions.name="GitHub Super-Linter" \
    com.github.actions.description="Lint your code base with GitHub Actions" \
    com.github.actions.icon="code" \
    com.github.actions.color="red" \
    maintainer="GitHub DevOps <github_devops@github.com>" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.revision=$BUILD_REVISION \
    org.opencontainers.image.version=$BUILD_VERSION \
    org.opencontainers.image.authors="GitHub DevOps <github_devops@github.com>" \
    org.opencontainers.image.url="https://github.com/github/super-linter" \
    org.opencontainers.image.source="https://github.com/github/super-linter" \
    org.opencontainers.image.documentation="https://github.com/github/super-linter" \
    org.opencontainers.image.vendor="GitHub" \
    org.opencontainers.image.description="Lint your code base with GitHub Actions"

#################################################
# Set ENV values used for debugging the version #
#################################################
ENV BUILD_DATE=$BUILD_DATE
ENV BUILD_REVISION=$BUILD_REVISION
ENV BUILD_VERSION=$BUILD_VERSION
ENV IMAGE="slim"

######################################
# Install Phive dependencies and git #
######################################
RUN wget --tries=5 -q -O /etc/apk/keys/sgerrand.rsa.pub https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub \
    && wget --tries=5 -q https://github.com/sgerrand/alpine-pkg-glibc/releases/download/${GLIBC_VERSION}/glibc-${GLIBC_VERSION}.apk \
    && apk add --no-cache \
    bash \
    ca-certificates \
    git git-lfs \
    glibc-${GLIBC_VERSION}.apk \
    tar zstd \
    gnupg \
    php7 php7-curl php7-ctype php7-dom php7-iconv php7-json php7-mbstring \
    php7-openssl php7-phar php7-simplexml php7-tokenizer php-xmlwriter \
    && rm glibc-${GLIBC_VERSION}.apk \
    && wget -q --tries=5 -O /tmp/libz.tar.zst https://www.archlinux.org/packages/core/x86_64/zlib/download \
    && mkdir /tmp/libz \
    && tar -xf /tmp/libz.tar.zst -C /tmp/libz --zstd \
    && mv /tmp/libz/usr/lib/libz.so* /usr/glibc-compat/lib \
    && rm -rf /tmp/libz /tmp/libz.tar.zst \
    && wget -q --tries=5 -O phive.phar https://phar.io/releases/phive.phar \
    && wget -q --tries=5 -O phive.phar.asc https://phar.io/releases/phive.phar.asc \
    && PHAR_KEY_ID="0x9D8A98B29B2D5D79" \
    && gpg --keyserver hkps://keyserver.ubuntu.com --recv-keys "$PHAR_KEY_ID" \
    && gpg --verify phive.phar.asc phive.phar \
    && chmod +x phive.phar \
    && mv phive.phar /usr/local/bin/phive \
    && rm phive.phar.asc \
    && phive --no-progress install --trust-gpg-keys \
    31C7E470E2138192,CF1A108D0E7AE720,8A03EA3B385DBAA1,12CE0F1D262429A5 \
    --target /usr/bin phpstan@^1.1.1 psalm@^4.12.0 phpcs@^3.6.1

#################################
# Copy the libraries into image #
#################################
COPY --from=base_image /usr/bin/ /usr/bin/
COPY --from=base_image /usr/local/bin/ /usr/local/bin/
COPY --from=base_image /usr/local/lib/ /usr/local/lib/
COPY --from=base_image /usr/local/share/ /usr/local/share/
COPY --from=base_image /usr/lib/ /usr/lib/
COPY --from=base_image /usr/share/ /usr/share/
COPY --from=base_image /usr/include/ /usr/include/
COPY --from=base_image /lib/ /lib/
COPY --from=base_image /bin/ /bin/
COPY --from=base_image /node_modules/ /node_modules/
COPY --from=base_image /home/r-library /home/r-library
COPY --from=base_image /root/.tflint.d/ /root/.tflint.d/

####################################################
# Install Composer after all Libs have been copied #
####################################################
RUN sh -c 'curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/bin --filename=composer'

########################################
# Add node packages to path and dotnet #
########################################
ENV PATH="${PATH}:/node_modules/.bin:/root/.local/bin"

#############################
# Copy scripts to container #
#############################
COPY lib /action/lib

##################################
# Copy linter rules to container #
##################################
COPY TEMPLATES /action/lib/.automation

################################################
# Run to build version file and validate image #
################################################
RUN ACTIONS_RUNNER_DEBUG=true WRITE_LINTER_VERSIONS_FILE=true IMAGE="${IMAGE}" /action/lib/linter.sh

######################
# Set the entrypoint #
######################
ENTRYPOINT ["/action/lib/linter.sh"]

FROM final_slim as final_standard

ARG ARM_TTK_DIRECTORY='/usr/lib/microsoft'

# PowerShell & PSScriptAnalyzer
ARG PWSH_VERSION='latest'
ARG PWSH_DIRECTORY='/usr/lib/microsoft/powershell'
ARG PSSA_VERSION='latest'
# arm-ttk
ARG ARM_TTK_NAME='master.zip'
ARG ARM_TTK_URI='https://github.com/Azure/arm-ttk/archive/master.zip'
ARG ARM_TTK_DIRECTORY='/usr/lib/microsoft'

ENV IMAGE="standard"

ENV ARM_TTK_PSD1="${ARM_TTK_DIRECTORY}/arm-ttk-master/arm-ttk/arm-ttk.psd1"

ENV PATH="${PATH}:/var/cache/dotnet/tools:/usr/share/dotnet"

COPY --from=base_image /usr/libexec/ /usr/libexec/

#########################
# Install dotenv-linter #
#########################
COPY --from=dotenv-linter /dotenv-linter /usr/bin/

###################################
# Install DotNet and Dependencies #
###################################
RUN wget --tries=5 -q -O dotnet-install.sh https://dot.net/v1/dotnet-install.sh \
    && chmod +x dotnet-install.sh \
    && ./dotnet-install.sh --install-dir /usr/share/dotnet -channel Current -version latest \
    && /usr/share/dotnet/dotnet tool install --tool-path /usr/bin dotnet-format --version 5.0.211103

##############################
# Install rustfmt & clippy   #
##############################
ENV CRYPTOGRAPHY_DONT_BUILD_RUST=1
RUN ln -s /usr/bin/rustup-init /usr/bin/rustup \
    && rustup toolchain install stable-x86_64-unknown-linux-musl \
    && rustup component add rustfmt --toolchain=stable-x86_64-unknown-linux-musl \
    && rustup component add clippy --toolchain=stable-x86_64-unknown-linux-musl \
    && mv /root/.rustup /usr/lib/.rustup \
    && ln -fsv /usr/lib/.rustup/toolchains/stable-x86_64-unknown-linux-musl/bin/rustfmt /usr/bin/rustfmt \
    && ln -fsv /usr/lib/.rustup/toolchains/stable-x86_64-unknown-linux-musl/bin/rustc /usr/bin/rustc \
    && ln -fsv /usr/lib/.rustup/toolchains/stable-x86_64-unknown-linux-musl/bin/cargo /usr/bin/cargo \
    && ln -fsv /usr/lib/.rustup/toolchains/stable-x86_64-unknown-linux-musl/bin/cargo-clippy /usr/bin/cargo-clippy \
    && echo '#!/usr/bin/env bash' > /usr/bin/clippy \
    && echo 'pushd $(dirname $1)' >> /usr/bin/clippy \
    && echo 'cargo-clippy' >> /usr/bin/clippy \
    && echo 'rc=$?' >> /usr/bin/clippy \
    && echo 'popd' >> /usr/bin/clippy \
    && echo 'exit $rc' >> /usr/bin/clippy \
    && chmod +x /usr/bin/clippy

#########################################
# Install Powershell + PSScriptAnalyzer #
#########################################
# Reference: https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-7
# Slightly modified to always retrieve latest stable Powershell version
# If changing PWSH_VERSION='latest' to a specific version, use format PWSH_VERSION='tags/v7.0.2'
RUN mkdir -p ${PWSH_DIRECTORY} \
    && curl --retry 5 --retry-delay 5 -s https://api.github.com/repos/powershell/powershell/releases/${PWSH_VERSION} \
    | grep browser_download_url \
    | grep linux-alpine-x64 \
    | cut -d '"' -f 4 \
    | xargs -n 1 wget -q -O - \
    | tar -xzC ${PWSH_DIRECTORY} \
    && ln -sf ${PWSH_DIRECTORY}/pwsh /usr/bin/pwsh \
    && pwsh -c 'Install-Module -Name PSScriptAnalyzer -RequiredVersion ${PSSA_VERSION} -Scope AllUsers -Force'

#############################################################
# Install Azure Resource Manager Template Toolkit (arm-ttk) #
#############################################################
# Depends on PowerShell
# Reference https://github.com/Azure/arm-ttk
# Reference https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/test-toolkit
ENV ARM_TTK_PSD1="${ARM_TTK_DIRECTORY}/arm-ttk-master/arm-ttk/arm-ttk.psd1"
RUN curl --retry 5 --retry-delay 5 -sLO "${ARM_TTK_URI}" \
    && unzip "${ARM_TTK_NAME}" -d "${ARM_TTK_DIRECTORY}" \
    && rm "${ARM_TTK_NAME}" \
    && ln -sTf "${ARM_TTK_PSD1}" /usr/bin/arm-ttk

########################################################################################
# Run to build version file and validate image again because we installed more linters #
########################################################################################
RUN ACTIONS_RUNNER_DEBUG=true WRITE_LINTER_VERSIONS_FILE=true IMAGE="${IMAGE}" /action/lib/linter.sh
