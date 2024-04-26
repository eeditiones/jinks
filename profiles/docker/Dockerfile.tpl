# START STAGE 1
FROM openjdk:8-jdk-slim as builder

USER root

ENV NODE_MAJOR 20
ENV ANT_VERSION [[$docker?ant]]
ENV ANT_HOME /etc/ant-${ANT_VERSION}

WORKDIR /tmp

RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    gnupg

RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg && \
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list && \
    apt-get update && \
    apt-get install nodejs -y

RUN curl -L -o apache-ant-${ANT_VERSION}-bin.tar.gz https://downloads.apache.org/ant/binaries/apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mkdir ant-${ANT_VERSION} \
    && tar -zxvf apache-ant-${ANT_VERSION}-bin.tar.gz \
    && mv apache-ant-${ANT_VERSION} ${ANT_HOME} \
    && rm apache-ant-${ANT_VERSION}-bin.tar.gz \
    && rm -rf ant-${ANT_VERSION} \
    && rm -rf ${ANT_HOME}/manual \
    && unset ANT_VERSION

ENV PATH ${PATH}:${ANT_HOME}/bin

FROM builder as tei

ARG EXIST_VERSION=[[ $docker?eXist ]]
ARG TEMPLATING_VERSION=1.1.0
ARG PUBLISHER_LIB_VERSION=[[ $docker?tei-publisher-lib ]]
ARG ROUTER_VERSION=[[ $docker?roaster ]]

# add key
RUN  mkdir -p ~/.ssh && ssh-keyscan -t rsa github.com >> ~/.ssh/known_hosts

# Build tei-publisher-lib
RUN if [ "${PUBLISHER_LIB_VERSION}" = "master" ]; then \
        git clone https://github.com/eeditiones/tei-publisher-lib.git \
        && cd tei-publisher-lib \
        && ant \
        && cp build/*.xar /tmp; \
    else \
        curl -L -o /tmp/tei-publisher-lib-${PUBLISHER_LIB_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/tei-publisher-lib-${PUBLISHER_LIB_VERSION}.xar; \
    fi

# Build tei-publisher-app
COPY . [[$pkg?abbrev]]/
RUN  cd  [[$pkg?abbrev]] \
    && sed -i 's/$config:webcomponents :=.*;/$config:webcomponents := "local";/' modules/config.xqm \
    && ant xar-local

RUN curl -L -o /tmp/roaster-${ROUTER_VERSION}.xar http://exist-db.org/exist/apps/public-repo/public/roaster-${ROUTER_VERSION}.xar
RUN curl -L -o /tmp/templating-${TEMPLATING_VERSION}.xar http://exist-db.org/exist/apps/public-repo/public/templating-${TEMPLATING_VERSION}.xar

FROM duncdrum/existdb:${EXIST_VERSION}-debug-j8

COPY --from=tei /tmp/[[$pkg?abbrev]]/build/*.xar /exist/autodeploy/
COPY --from=tei /tmp/*.xar /exist/autodeploy/

WORKDIR /exist

# ARG ADMIN_PASS=none

ARG HTTP_PORT=[[$docker?ports?http]]
ARG HTTPS_PORT=[[$docker?ports?https]]

ARG NER_ENDPOINT=http://localhost:8001
ARG CONTEXT_PATH=auto
ARG PROXY_CACHING=false

ENV JAVA_TOOL_OPTIONS \
  -Dfile.encoding=UTF8 \
  -Dsun.jnu.encoding=UTF-8 \
  -Djava.awt.headless=true \
  -Dorg.exist.db-connection.cacheSize=${CACHE_MEM:-256}M \
  -Dorg.exist.db-connection.pool.max=${MAX_BROKER:-20} \
  -Dlog4j.configurationFile=/exist/etc/log4j2.xml \
  -Dexist.home=/exist \
  -Dexist.configurationFile=/exist/etc/conf.xml \
  -Djetty.home=/exist \
  -Dexist.jetty.config=/exist/etc/jetty/standard.enabled-jetty-configs \
  -Dteipublisher.ner-endpoint=${NER_ENDPOINT} \
  -Dteipublisher.context-path=${CONTEXT_PATH} \
  -Dteipublisher.proxy-caching=${PROXY_CACHING} \
  -XX:+UseG1GC \
  -XX:+UseStringDeduplication \
  -XX:+UseContainerSupport \
  -XX:MaxRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \
  -XX:+ExitOnOutOfMemoryError

# pre-populate the database by launching it once and change default pw
RUN [ "java", "org.exist.start.Main", "client", "--no-gui",  "-l", "-u", "admin", "-P", "" ]

EXPOSE ${HTTP_PORT} ${HTTPS_PORT}