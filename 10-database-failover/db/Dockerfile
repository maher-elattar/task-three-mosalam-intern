# Versioned database image.
# The schema seed is part of the image so the DB artifact can be tagged and promoted.
FROM mysql:8.4

COPY init.sql /docker-entrypoint-initdb.d/01-init.sql

