# Logstash with JDBC input and PostgreSQL driver
FROM docker.elastic.co/logstash/logstash:8.13.4

# Install JDBC input plugin and download PostgreSQL JDBC driver
USER root
RUN set -euo pipefail \ 
    && logstash-plugin install logstash-input-jdbc \ 
    && microdnf install -y curl ca-certificates || true \ 
    && mkdir -p /usr/share/logstash/logstash-core/lib/jars \ 
    && curl -fSL -o /usr/share/logstash/logstash-core/lib/jars/postgresql.jar https://jdbc.postgresql.org/download/postgresql-42.7.4.jar \ 
    && chown -R logstash:root /usr/share/logstash/logstash-core/lib/jars \ 
    && microdnf clean all || true

USER logstash

# Default pipeline path is /usr/share/logstash/pipelines via our volume
