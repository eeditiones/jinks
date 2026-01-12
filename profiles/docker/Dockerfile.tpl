ARG EXIST_VERSION=[[ $docker?eXist ]]
ARG BUILD=local

# START STAGE 1
FROM ghcr.io/eeditiones/builder:latest AS builder

ARG ROUTER_VERSION=[[ $docker?roaster ]]
ARG JWT_VERSION=[[ $docker?jwt ]]
ARG CRYPTO_VERSION=[[ $docker?crypto ]]

WORKDIR /tmp

# Build jinks-template
RUN git clone https://github.com/eeditiones/jinks-templates.git \
    && cd jinks-templates \
    && ant

# Build tei-publisher-lib
RUN git clone https://github.com/eeditiones/tei-publisher-lib.git \
    && cd tei-publisher-lib \
    && ant 

[% if $pkg?abbrev = "tei-publisher-docs" %]
# Build tei-publisher-app with local webcomponents (only for docs blueprint)
COPY . [[$pkg?abbrev]]/
RUN  cd  [[$pkg?abbrev]] \
    && sed -i 's/$config:webcomponents :=.*;/$config:webcomponents := "local";/' modules/config.xqm \
    && ant xar-local
[% else %]
# Build app inside container
COPY . [[$pkg?abbrev]]/
RUN  cd  [[$pkg?abbrev]] \
    && ant
[% endif %]

ADD http://exist-db.org/exist/apps/public-repo/public/roaster-${ROUTER_VERSION}.xar 001.xar
ADD http://exist-db.org/exist/apps/public-repo/public/jwt-${JWT_VERSION}.xar 002.xar
ADD https://exist-db.org/exist/apps/public-repo/public/expath-crypto-module-${CRYPTO_VERSION}.xar 003.xar

[% if exists($docker?externalXar) and map:size($docker?externalXar) > 0 %]
# Additional external XAR dependencies
[% for $fileName in map:keys($docker?externalXar) %]
[% if ($docker?externalXar($fileName) instance of map(*) and exists($docker?externalXar($fileName)?token)) %]
# Private repository - using BuildKit secret: [[ string($docker?externalXar($fileName)?token) ]]
RUN --mount=type=secret,id=[[ string($docker?externalXar($fileName)?token) ]] \
    TOKEN=$(cat /run/secrets/[[ string($docker?externalXar($fileName)?token) ]]) && \
    curl -H "Authorization: token $TOKEN" -L -o [[ $fileName ]].xar "[[ string(if ($docker?externalXar($fileName) instance of xs:string) then $docker?externalXar($fileName) else $docker?externalXar($fileName)?url) ]]"
[% else %]
# Public repository
ADD [[ string(if ($docker?externalXar($fileName) instance of xs:string) then $docker?externalXar($fileName) else $docker?externalXar($fileName)?url) ]] [[ $fileName ]].xar
[% endif %]
[% endfor %]
[% endif %]

FROM duncdrum/existdb:${EXIST_VERSION} AS build_local

ARG USR=root
USER ${USR}

ONBUILD COPY --from=builder /tmp/*.xar /exist/autodeploy/
ONBUILD COPY --from=builder /tmp/jinks-templates/build/*.xar /exist/autodeploy/004.xar
ONBUILD COPY --from=builder /tmp/tei-publisher-lib/build/*.xar /exist/autodeploy/005.xar
ONBUILD COPY --from=builder /tmp/[[$pkg?abbrev]]/build/*.xar /exist/autodeploy/006.xar

# TODO(DP): Tagging scheme add EXIST_VERSION to the tag
FROM  ghcr.io/jinntec/base:main AS build_prod

# NOTE the start URL http://localhost:8080/exist/apps/[[$pkg?abbrev]]/index.html 
ARG PUBLISHER_VERSION

ARG USR=nonroot
USER ${USR}

# Copy latest release of EXPATH dependencies
# DP: see Jinntec/tp-app-base#4
ONBUILD ADD --chown=${USR} https://github.com/eeditiones/jinks-templates/releases/latest/download/jinks-templates.xar /exist/autodeploy/004.xar
ONBUILD ADD --chown=${USR} https://github.com/eeditiones/tei-publisher-libs/releases/latest/download/tei-publisher-lib.xar /exist/autodeploy/005.xar

# This assumes that a local xar file is persent for building prodocution images
COPY --chown=${USR} ./build/*.xar /exist/autodeploy/

FROM build_${BUILD}

ARG USR
USER ${USR}

WORKDIR /exist

# ARG ADMIN_PASS=none

ARG CACHE_MEM
ARG MAX_BROKER
ARG JVM_MAX_RAM_PERCENTAGE
ARG HTTP_PORT=[[$docker?ports?http]]
ARG HTTPS_PORT=[[$docker?ports?https]]

ARG NER_ENDPOINT=http://localhost:8001
ARG CONTEXT_PATH=auto
ARG PROXY_CACHING=false

ENV JDK_JAVA_OPTIONS="\
    -Dteipublisher.ner-endpoint=${NER_ENDPOINT} \
    -Dteipublisher.context-path=${CONTEXT_PATH} \
    -Dteipublisher.proxy-caching=${PROXY_CACHING}"

# pre-populate the database by launching it once and change default pw
RUN [ "java", "org.exist.start.Main", "client", "--no-gui",  "-l", "-u", "admin", "-P", "" ]

EXPOSE ${HTTP_PORT} ${HTTPS_PORT}