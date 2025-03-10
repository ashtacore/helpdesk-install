#!/bin/bash

set -eu -o pipefail

BACKUP_DIR="backup"
TIMESTAMP=$(date +%Y-%m-%d-%H-%M-%S)
TEMP_BACKUP_DIR="/tmp/tmp-backups/${TIMESTAMP}"
FILESYSTEM_BACKUP_NAME="filesystem-${TIMESTAMP}.tar.gz"
APP_BACKUP_NAME="app-${TIMESTAMP}.tar.gz"

# Determine command path. Some commands moved to app-manager in v4.2.0
GTE_v420="$(podman exec supportpal php -r "\$release = require '/var/www/supportpal/config/release.php'; echo (int) version_compare(\$release['version'], '4.2.0', '>=');")"
if [[ "$GTE_v420" = "0" ]]; then COMMAND_PATH="/var/www/supportpal"; else COMMAND_PATH="/var/www/supportpal/app-manager"; fi

echo "Stopping services..."
podman exec supportpal bash -c "find -L /etc/service -maxdepth 1 -mindepth 1 -type d ! -name 'redis' ! -name 'mysql' -printf '%f\n' -exec sv stop {} \;"  > /dev/null

echo 'Backing up filesystem...'
podman exec supportpal bash -c "mkdir -p ${TEMP_BACKUP_DIR}/filesystem-${TIMESTAMP}/config/production" # create the farthest directory
podman exec supportpal bash -c "cp -r /var/www/supportpal/config/production ${TEMP_BACKUP_DIR}/filesystem-${TIMESTAMP}/config"
podman exec supportpal bash -c "cp -r /var/www/supportpal/storage ${TEMP_BACKUP_DIR}/filesystem-${TIMESTAMP}"
podman exec supportpal bash -c "cp -r /var/www/supportpal/addons ${TEMP_BACKUP_DIR}/filesystem-${TIMESTAMP}"
podman exec supportpal bash -c "cd ${TEMP_BACKUP_DIR} && tar -czf ${FILESYSTEM_BACKUP_NAME} filesystem-${TIMESTAMP}"

echo 'Backing up database...'
DB_BACKUP_PATH=$(podman exec supportpal bash -c "cd ${COMMAND_PATH} && php artisan db:backup | grep -oE '/var/www/supportpal/.*/database-.*'")
DB_FILE_NAME=$(echo "${DB_BACKUP_PATH}" | xargs basename)
podman exec supportpal bash -c "mv ${DB_BACKUP_PATH} ${TEMP_BACKUP_DIR}/"

echo 'Backing up volume data...'
podman exec supportpal bash -c "mkdir -p ${TEMP_BACKUP_DIR}/volumes-monolithic/cache && cp -r /redis-data/ ${TEMP_BACKUP_DIR}/volumes-monolithic/cache"
podman exec supportpal bash -c "mkdir -p ${TEMP_BACKUP_DIR}/volumes-monolithic/caddy && cp -r /caddy/ ${TEMP_BACKUP_DIR}/volumes-monolithic/caddy"

echo 'Combining backups...'
podman exec supportpal bash -c "cd ${TEMP_BACKUP_DIR} && tar -czf ${APP_BACKUP_NAME} ${FILESYSTEM_BACKUP_NAME} ${DB_FILE_NAME} volumes-monolithic/"

echo 'Copying backup to host...'
mkdir -p "${BACKUP_DIR}/"
podman cp "supportpal:${TEMP_BACKUP_DIR}/${APP_BACKUP_NAME}" "${BACKUP_DIR}/"
podman exec supportpal bash -c "rm -rf ${TEMP_BACKUP_DIR}/"

echo "Restarting services..."
podman restart supportpal 2> /dev/null

echo "Backup created successfully at ${PWD}/${BACKUP_DIR}/${APP_BACKUP_NAME}"
