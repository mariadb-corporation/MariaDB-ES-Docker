#
# Copyright (c) 2020, MariaDB Corporation. All rights reserved.
#
FROM centos:8
#
LABEL maintainer="MariaDB Corporation Ab"
#
ARG GOSU_VERSION=1.12
ARG ES_TOKEN
ARG ES_VERSION=10.5
ARG SETUP_SCRIPT=https://dlm.mariadb.com/enterprise-release-helpers/mariadb_es_repo_setup
ARG CLEAR_REPOSITORY
ARG REPOSITORY
ARG REPOSITORY_KEY
#
# Add script to setup the private repository
COPY scripts/setup-custom-repository.sh /tmp/setup-custom-repository.sh
#
RUN echo ${REPOSITORY}
RUN if [ -z "${REPOSITORY}" ]; then \
        curl -L ${SETUP_SCRIPT} > /tmp/es_repo_setup && chmod +x /tmp/es_repo_setup && \
        /tmp/es_repo_setup  --token=${ES_TOKEN} --apply --verbose --skip-maxscale \
        --mariadb-server-version=${ES_VERSION} && rm -fv /tmp/es_repo_setup; \
    else \
        chmod +x /tmp/setup-custom-repository.sh && \
        /tmp/setup-custom-repository.sh --repository ${REPOSITORY} --repository-key ${REPOSITORY_KEY}; \
    fi
#
RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm && \
    yum -y install http://mirror.centos.org/centos/8/AppStream/x86_64/os/Packages/boost-program-options-1.66.0-10.el8.x86_64.rpm && \
    yum -y install jemalloc hostname && \
    yum -y install MariaDB-server MariaDB-client MariaDB-backup && \
    yum clean all && rm -fv /etc/yum.repos.d/mariadb.repo && rm -fr /var/lib/mysql && \
    mkdir /var/lib/mysql && echo "ES_VERSION=${ES_VERSION}" >> /etc/IMAGEINFO
    
# Remove repository configuration
RUN if [ "${CLEAR_REPOSITORY}" = "true" ]; then \
        rm /etc/yum.repos.d/mariadb.repo; \
    fi    
#
# add gosu for easy step-down from root
RUN gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
    && curl -o /usr/local/bin/gosu -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64" \
    && curl -o /usr/local/bin/gosu.asc -SL "https://github.com/tianon/gosu/releases/download/${GOSU_VERSION}/gosu-amd64.asc" \
    && gpg --verify /usr/local/bin/gosu.asc \
    && rm /usr/local/bin/gosu.asc \
    && rm -fr /root/.gnupg/ \
    && chmod +x /usr/local/bin/gosu
#
RUN mkdir /es-initdb.d
#
VOLUME /var/lib/mysql
COPY es-entrypoint.sh /es-entrypoint.sh
COPY zz_es-docker.cnf /etc/my.cnf.d/
ENTRYPOINT ["/es-entrypoint.sh"]
EXPOSE 3306/tcp
