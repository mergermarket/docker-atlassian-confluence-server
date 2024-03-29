FROM openjdk:8-jre

# Setup useful environment variables
ENV CONFLUENCE_HOME     /var/atlassian/application-data/confluence
ENV CONFLUENCE_INSTALL  /opt/atlassian/confluence
ENV CONF_VERSION 6.15.8

LABEL Description="This image is used to start Atlassian Confluence" Vendor="Atlassian" Version="${CONF_VERSION}"

ENV CONFLUENCE_DOWNLOAD_URL http://www.atlassian.com/software/confluence/downloads/binary/atlassian-confluence-${CONF_VERSION}.tar.gz

ENV MYSQL_VERSION 5.1.45
ENV MYSQL_DRIVER_DOWNLOAD_URL http://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_VERSION}.tar.gz
ENV XWORK_DOWNLOAD_URL https://iona-atlassian-files.s3.eu-west-1.amazonaws.com/xwork-1.0.3-atlassian-10.jar
ENV WEBWORK_DOWNLOAD_URL https://iona-atlassian-files.s3.eu-west-1.amazonaws.com/webwork-2.1.5-atlassian-4.jar
ENV CACHED_CONFIG_DOWNLOAD_URL https://confluence.atlassian.com/doc/files/1130377146/1137639562/3/1654274890463/CachedConfigurationProvider.class


# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
ENV RUN_USER            daemon
ENV RUN_GROUP           daemon


# Install Atlassian Confluence and helper tools and setup initial home
# directory structure.
RUN set -x \
    && apt-get update --quiet \
    && apt-get install --quiet --yes --no-install-recommends libtcnative-1 xmlstarlet \
    && apt-get clean \
    && mkdir -p                           "${CONFLUENCE_HOME}" \
    && chmod -R 700                       "${CONFLUENCE_HOME}" \
    && chown ${RUN_USER}:${RUN_GROUP}     "${CONFLUENCE_HOME}" \
    && mkdir -p                           "${CONFLUENCE_INSTALL}/conf" \
    && curl -Ls                           "${CONFLUENCE_DOWNLOAD_URL}" | tar -xz --directory "${CONFLUENCE_INSTALL}" --strip-components=1 --no-same-owner \
    && curl -Ls                           "${MYSQL_DRIVER_DOWNLOAD_URL}" | tar -xz --directory "${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib" --strip-components=1 --no-same-owner "mysql-connector-java-${MYSQL_VERSION}/mysql-connector-java-${MYSQL_VERSION}-bin.jar" \
    && rm                                 "${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib/xwork-1.0.3.6.jar" \ 
    && rm                                 "${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib/webwork-2.1.5-atlassian-3.jar" \ 
    && wget -O                            "${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib/xwork-1.0.3-atlassian-10.jar" "${XWORK_DOWNLOAD_URL}" \
    && wget -O                            "${CONFLUENCE_INSTALL}/confluence/WEB-INF/lib/webwork-2.1.5-atlassian-4.jar" "${WEBWORK_DOWNLOAD_URL}" \
    && wget -P                            "${CONFLUENCE_INSTALL}/confluence/WEB-INF/classes/com/atlassian/confluence/setup/webwork/" "${CACHED_CONFIG_DOWNLOAD_URL}" \    
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/conf" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/temp" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/logs" \
    && chmod -R 700                       "${CONFLUENCE_INSTALL}/work" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/conf" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/confluence" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/temp" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/logs" \
    && chown -R ${RUN_USER}:${RUN_GROUP}  "${CONFLUENCE_INSTALL}/work" \
    && echo -e                            "\nconfluence.home=${CONFLUENCE_HOME}" >> "${CONFLUENCE_INSTALL}/confluence/WEB-INF/classes/confluence-init.properties" \
    && xmlstarlet                         ed --inplace \
        --delete                          "Server/@debug" \
        --delete                          "Server/Service/Connector/@debug" \
        --delete                          "Server/Service/Connector/@useURIValidationHack" \
        --delete                          "Server/Service/Connector/@minProcessors" \
        --delete                          "Server/Service/Connector/@maxProcessors" \
        --delete                          "Server/Service/Engine/@debug" \
        --delete                          "Server/Service/Engine/Host/@debug" \
        --delete                          "Server/Service/Engine/Host/Context/@debug" \
                                          "${CONFLUENCE_INSTALL}/conf/server.xml" \
    && touch -d "@0"                      "${CONFLUENCE_INSTALL}/conf/server.xml"

# Use the default unprivileged account. This could be considered bad practice
# on systems where multiple processes end up being executed by 'daemon' but
# here we only ever run one process anyway.
USER ${RUN_USER}:${RUN_GROUP}

# Expose default HTTP connector port.
EXPOSE 8090
EXPOSE 8091

# Set volume mount points for installation and home directory. Changes to the
# home directory needs to be persisted as well as parts of the installation
# directory due to eg. logs.
VOLUME ["${CONFLUENCE_INSTALL}", "${CONFLUENCE_HOME}"]

# Set the default working directory as the Confluence installation directory.
WORKDIR ${CONFLUENCE_INSTALL}

# Run Atlassian Confluence as a foreground process by default.
CMD ["./bin/catalina.sh", "run"]
