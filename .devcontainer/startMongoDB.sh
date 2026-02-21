#!/bin/bash
set -euo pipefail

if ! command -v mongod >/dev/null 2>&1; then
	echo "mongod not found. Run ./.devcontainer/installMongoDB.sh first." >&2
	exit 1
fi

mkdir -p /data/db
mkdir -p /tmp/mongodb

if pgrep -x mongod >/dev/null 2>&1; then
	echo "MongoDB is already running."
else
	mongod --dbpath /data/db --bind_ip 127.0.0.1 --fork --logpath /tmp/mongodb/mongod.log
	echo "MongoDB has been started successfully!"
fi

mongod --version | head -n 1
echo "Current databases:"
if command -v mongosh >/dev/null 2>&1; then
	mongosh --quiet --eval "db.getMongo().getDBNames()"
else
	echo "mongosh is not installed; skipping database list command."
fi