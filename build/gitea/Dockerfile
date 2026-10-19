# Wonderland's lightweight git host: Gitea, configured for the lab (installed, HTTP only, SQLite on
# the /data volume). The repositories are NOT baked into the image: their sample sources are staged
# under /opt and pushed into Gitea at run time by the Isoloom setup job (seed.sh), which also creates
# the org and users. No challenge secret lives here.
FROM gitea/gitea:1.22

ENV GITEA_WORK_DIR=/data \
    GITEA_ADMIN_USER=wonderland_admin \
    GITEA_ADMIN_PASS=W0nderland-admin

COPY app.ini /etc/gitea/app.ini
COPY app-src/ /opt/mad-hatter-src/
COPY pipeline-src/ /opt/mad-hatter-pipeline-src/
COPY entrypoint.sh /usr/local/bin/mh-gitea-entrypoint.sh
RUN chmod 0755 /usr/local/bin/mh-gitea-entrypoint.sh && chmod 0644 /etc/gitea/app.ini

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/mh-gitea-entrypoint.sh"]
