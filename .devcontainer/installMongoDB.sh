#!/bin/bash
set -euo pipefail

if command -v mongod >/dev/null 2>&1; then
	echo "MongoDB is already installed."
	exit 0
fi

source /etc/os-release
ARCH="$(dpkg --print-architecture)"

install_from_tarball() {
	local arch_label
	case "${ARCH}" in
		amd64) arch_label="x86_64" ;;
		arm64) arch_label="aarch64" ;;
		*)
			echo "Unsupported architecture for MongoDB tarball install: ${ARCH}" >&2
			return 1
			;;
	esac

	local version="7.0.26"
	local url="https://fastdl.mongodb.org/linux/mongodb-linux-${arch_label}-debian12-${version}.tgz"
	local temp_dir
	temp_dir="$(mktemp -d)"

	echo "Installing MongoDB from tarball fallback..."
	curl -fL "${url}" -o "${temp_dir}/mongodb.tgz"
	tar -xzf "${temp_dir}/mongodb.tgz" -C "${temp_dir}"

	local extracted_dir
	extracted_dir="$(find "${temp_dir}" -maxdepth 1 -type d -name 'mongodb-linux-*' | head -n 1)"
	if [[ -z "${extracted_dir}" ]]; then
		echo "Failed to extract MongoDB tarball." >&2
		return 1
	fi

	sudo install -m 0755 "${extracted_dir}/bin/mongod" /usr/local/bin/mongod
	if [[ -f "${extracted_dir}/bin/mongosh" ]]; then
		sudo install -m 0755 "${extracted_dir}/bin/mongosh" /usr/local/bin/mongosh
	fi

	rm -rf "${temp_dir}"
}

sudo mkdir -p /usr/share/keyrings
curl -fsSL https://pgp.mongodb.com/server-7.0.asc | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/mongodb-server-7.0.gpg

if [[ "${ID}" == "debian" ]]; then
	REPO_DISTRO="bookworm"
	echo "deb [ arch=${ARCH} signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/debian ${REPO_DISTRO}/mongodb-org/7.0 main" \
		| sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
elif [[ "${ID}" == "ubuntu" ]]; then
	echo "deb [ arch=${ARCH} signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu ${VERSION_CODENAME}/mongodb-org/7.0 multiverse" \
		| sudo tee /etc/apt/sources.list.d/mongodb-org-7.0.list >/dev/null
else
	echo "Unsupported distro for automatic MongoDB install: ${ID}" >&2
	exit 1
fi

set +e
sudo apt-get update
apt_update_status=$?
if [[ ${apt_update_status} -eq 0 ]]; then
	sudo apt-get install -y mongodb-org
	apt_install_status=$?
else
	apt_install_status=1
fi
set -e

if [[ ${apt_install_status} -ne 0 ]]; then
	echo "APT install failed; switching to tarball fallback."
	install_from_tarball
fi

if ! command -v mongod >/dev/null 2>&1; then
	echo "MongoDB install failed: mongod is still unavailable." >&2
	exit 1
fi

# Create a data directory owned by the current user to avoid relying on system users.
mkdir -p /data/db
sudo chown -R "$(id -u)":"$(id -g)" /data/db
