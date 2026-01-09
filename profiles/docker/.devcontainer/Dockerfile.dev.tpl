FROM mcr.microsoft.com/devcontainers/java:8-bullseye

ARG EXIST_VERSION=[[ $docker?eXist ]]
ARG PUBLISHER_LIB_VERSION=[[ $docker?tei-publisher-lib ]]
ARG JINKS_TEMPLATES_VERSION=[[ $docker?jinks-templates ]]
ARG ROUTER_VERSION=[[ $docker?roaster ]]
ARG EDITOR_VERSION=1.0.1
ARG JWT_VERSION=[[ $docker?jwt ]]
ARG CRYPTO_VERSION=[[ $docker?crypto ]]
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
RUN curl -L -o /usr/local/exist/autodeploy/expath-crypto-module-${CRYPTO_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/expath-crypto-module-${CRYPTO_VERSION}.xar
RUN curl -L -o /usr/local/exist/autodeploy/jwt-${JWT_VERSION}.xar https://exist-db.org/exist/apps/public-repo/public/jwt-${JWT_VERSION}.xar

[% if exists($docker?externalXar) and map:size($docker?externalXar) > 0 %]
# Additional external XAR dependencies
[% for $fileName in map:keys($docker?externalXar) %]
[% let $dep := $docker?externalXar($fileName) %]
[% let $url := if ($dep instance of xs:string) then $dep else $dep?url %]
[% let $tokenName := if ($dep instance of map(*) and exists($dep?token)) then $dep?token else () %]
[% if exists($tokenName) %]
# Private repository - using environment variable: [[ $tokenName ]]
# Note: For devcontainer, set the token as a build arg or environment variable
ARG [[ $tokenName ]]=
RUN if [ -n "${[[ $tokenName ]]}" ]; then \
      curl -H "Authorization: token ${[[ $tokenName ]]}" -L -o /usr/local/exist/autodeploy/[[ $fileName ]].xar "[[ $url ]]"; \
    else \
      echo "Warning: Token [[ $tokenName ]] not provided, attempting public download"; \
      curl -L -o /usr/local/exist/autodeploy/[[ $fileName ]].xar "[[ $url ]]" || true; \
    fi
[% else %]
# Public repository
RUN curl -L -o /usr/local/exist/autodeploy/[[ $fileName ]].xar "[[ $url ]]"
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
