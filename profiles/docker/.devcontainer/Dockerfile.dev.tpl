FROM mcr.microsoft.com/devcontainers/java:8-bullseye

ARG EXIST_VERSION=[[ $docker?eXist ]]
ARG PUBLISHER_LIB_VERSION=[[ $docker?tei-publisher-lib ]]
ARG JINKS_TEMPLATES_VERSION=[[ $docker?jinks-templates ]]
ARG ROUTER_VERSION=[[ $docker?roaster ]]
ARG EDITOR_VERSION=1.0.1
[% if some $dep in $pkg?dependencies?* satisfies $dep?package = "http://existsolutions.com/ns/jwt" %]
ARG JWT_VERSION=[[ $docker?jwt ]]
[% endif %]
[% if some $dep in $pkg?dependencies?* satisfies $dep?package = "http://expath.org/ns/crypto" %]
ARG CRYPTO_VERSION=[[ $docker?crypto ]]
[% endif %]
ARG HTTP_PORT=[[ $docker?ports?http ]]
ARG HTTPS_PORT=[[ $docker?ports?https ]]

ARG INSTALL_NER="[[ string($docker?features?ner) ]]"
ARG INSTALL_TEXLIVE="[[ string($docker?features?tex) ]]"

#custom-----> Start custom code

# Install Ant for building TEI Publisher libraries
RUN su vscode -c "source /usr/local/sdkman/bin/sdkman-init.sh && sdk install ant"
ENV ANT_HOME=/usr/local/sdkman/candidates/ant/current
ENV PATH=${PATH}:${ANT_HOME}/bin

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends bzip2

# Install python pip and upgrade it to latest version
RUN if [ "${INSTALL_NER}" = "true" ]; then \
    export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends python3-pip \
    && pip3 install --upgrade pip; \
    fi

# Install the TeXLive distribution for LaTeX support
RUN if [ "${INSTALL_TEXLIVE}" = "true" ]; then \
    apt-get -y install --no-install-recommends \
    texlive-xetex \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-lang-german \
    texlive-lang-european \
    texlive-humanities \
    texlive-plain-generic \
    fonts-junicode \
    latexmk; \
    fi

WORKDIR /workspaces

RUN if [ "${INSTALL_NER}" = "true" ]; then \
    # Install tei-publisher-ner plus German and English language models
    git clone https://github.com/eeditiones/tei-publisher-ner.git \
    && cd tei-publisher-ner \
    && pip3 install --no-cache-dir --upgrade -r requirements.txt \
    && pip3 install --no-cache-dir gunicorn \
    && python3 -m spacy download de_core_news_sm \
    && python3 -m spacy download en_core_web_sm; \
    fi

# Download and install eXist-db
RUN curl -L -o exist-distribution-${EXIST_VERSION}-unix.tar.bz2 https://github.com/eXist-db/exist/releases/download/eXist-${EXIST_VERSION}/exist-distribution-${EXIST_VERSION}-unix.tar.bz2 \
    && tar xfj exist-distribution-${EXIST_VERSION}-unix.tar.bz2 -C /usr/local \
    && rm exist-distribution-${EXIST_VERSION}-unix.tar.bz2 \
    && mv /usr/local/exist-distribution-${EXIST_VERSION} /usr/local/exist

# Build jinks-templates
RUN git clone https://github.com/eeditiones/jinks-templates.git \
    && cd jinks-templates \
    && ant \
    && cp build/*.xar /usr/local/exist/autodeploy/004.xar

# If tei-publisher-lib version is "master", build it. Otherwise download the specified version.
RUN if [ "${PUBLISHER_LIB_VERSION}" = "master" ]; then \
        git clone https://github.com/eeditiones/tei-publisher-lib.git \
        && cd tei-publisher-lib \
        && ant \
        && cp build/*.xar /usr/local/exist/autodeploy/005.xar; \
    else \
        curl -L -o /usr/local/exist/autodeploy/tei-publisher-lib-${PUBLISHER_LIB_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/tei-publisher-lib-${PUBLISHER_LIB_VERSION}.xar; \
    fi

RUN curl -L -o /usr/local/exist/autodeploy/roaster-${ROUTER_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/roaster-${ROUTER_VERSION}.xar
RUN curl -L -o /usr/local/exist/autodeploy/atom-editor-${EDITOR_VERSION}.xar https://github.com/wolfgangmm/existdb-langserver/raw/master/resources/atom-editor-${EDITOR_VERSION}.xar
[% if some $dep in $pkg?dependencies?* satisfies $dep?package = "http://expath.org/ns/crypto" %]
RUN curl -L -o /usr/local/exist/autodeploy/expath-crypto-module-${CRYPTO_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/expath-crypto-module-${CRYPTO_VERSION}.xar
[% endif %]
[% if some $dep in $pkg?dependencies?* satisfies $dep?package = "http://existsolutions.com/ns/jwt" %]
RUN curl -L -o /usr/local/exist/autodeploy/jwt-${JWT_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/jwt-${JWT_VERSION}.xar
[% endif %]

[% if exists($docker?externalXar) %]
# Additional external XAR dependencies
[% for $fileName in map:keys($docker?externalXar) %]
[% if ($docker?externalXar($fileName) instance of map(*) and exists($docker?externalXar($fileName)?token)) %]
# Private repository - using environment variable: [[ string($docker?externalXar($fileName)?token) ]]
# Note: For devcontainer, set the token as a build arg or environment variable
ARG [[ string($docker?externalXar($fileName)?token) ]]=
RUN if [ -n "${[[ string($docker?externalXar($fileName)?token) ]]}" ]; then \
      curl -H "Authorization: token ${[[ string($docker?externalXar($fileName)?token) ]]}" -L -o /usr/local/exist/autodeploy/[[ $fileName ]].xar "[[ string(if ($docker?externalXar($fileName) instance of xs:string) then $docker?externalXar($fileName) else $docker?externalXar($fileName)?url) ]]"; \
    else \
      echo "Warning: Token [[ string($docker?externalXar($fileName)?token) ]] not provided, attempting public download"; \
      curl -L -o /usr/local/exist/autodeploy/[[ $fileName ]].xar "[[ string(if ($docker?externalXar($fileName) instance of xs:string) then $docker?externalXar($fileName) else $docker?externalXar($fileName)?url) ]]" || true; \
    fi
[% else %]
# Public repository
RUN curl -L -o /usr/local/exist/autodeploy/[[ $fileName ]].xar "[[ string(if ($docker?externalXar($fileName) instance of xs:string) then $docker?externalXar($fileName) else $docker?externalXar($fileName)?url) ]]"
[% endif %]
[% endfor %]
[% endif %]

WORKDIR /usr/local/exist

ENV EXIST_HOME=/usr/local/exist
ENV JAVA_HOME=/usr/local/sdkman/candidates/java/current

RUN bin/client.sh -l --no-gui --xpath "system:get-version()"

EXPOSE ${HTTP_PORT} ${HTTPS_PORT} 8001

ENV JAVA_OPTS \
    -Djetty.port=${HTTP_PORT} \
    -Djetty.ssl.port=${HTTPS_PORT} \
    -Dfile.encoding=UTF8 \
    -Dsun.jnu.encoding=UTF-8 \
    -XX:+UseG1GC \
    -XX:+UseStringDeduplication \
    -XX:+UseContainerSupport \
    -XX:MaxRAMPercentage=${JVM_MAX_RAM_PERCENTAGE:-75.0} \ 
    -XX:+ExitOnOutOfMemoryError

ENTRYPOINT [ "/usr/local/exist/bin/startup.sh" ]
