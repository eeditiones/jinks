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

# Build tei-publisher-app
COPY . [[$pkg?abbrev]]/
RUN  cd  [[$pkg?abbrev]] \
    && sed -i 's/$config:webcomponents :=.*;/$config:webcomponents := "local";/' modules/config.xqm \
    && ant xar-local

ADD http://exist-db.org/exist/apps/public-repo/public/roaster-${ROUTER_VERSION}.xar 001.xar
ADD http://exist-db.org/exist/apps/public-repo/public/jwt-${JWT_VERSION}.xar 002.xar
ADD https://exist-db.org/exist/apps/public-repo/public/expath-crypto-module-${CRYPTO_VERSION}.xar 003.xar

FROM duncdrum/existdb:${EXIST_VERSION} AS build_local

ARG USR=root
USER ${USR}

ONBUILD COPY --from=builder /tmp/*.xar /exist/autodeploy/
ONBUILD COPY --from=builder /tmp/jinks-templates/build/*.xar /exist/autodeploy/004.xar
ONBUILD COPY --from=builder /tmp/tei-publisher-lib/build/*.xar /exist/autodeploy/005.xar
ONBUILD COPY --from=builder /tmp/[[$pkg?abbrev]]/build/*.xar /exist/autodeploy/006.xar

# TODO(DP): Tagging scheme add EXIST_VERSION to the tag
FROM  ghcr.io/jinntec/base:main AS build_prod

# NOTE the start URL http://localhost:8080/exist/apps/tei-publisher/index.html 
ARG PUBLISHER_VERSION

ARG USR=nonroot
USER ${USR}

# Copy EXPATH dependencies
# DP: TBD see Jinntec/tp-app-base#4
ONBUILD ADD --chown=${USR} https://github.com/eeditiones/jinks-templates/releases/latest/download/jinks-templates.xar /exist/autodeploy/004.xar

# This assumes that local xar file is persent for building prod images
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