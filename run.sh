#!/bin/sh

clone_repo()
{
	git clone git@github.com:luccaugusto/setup-wordpress-env.git
}

bootstrap_wp()
{
	#cp -r setup-development/xdebug-files "$install_dir/"
	cp setup-development/php.ini "$install_dir/"
	cp setup-development/build_wp.sh "$install_dir/"
	cp setup-development/docker-compose.yml "$install_dir/"
	cp setup-development/Dockerfile "$install_dir/"
}

build_wp()
{
	echo "REMEMBER TO MOVE DB DUMP TO $install_dir TOO"

	cd "$install_dir" || exit
	./build_wp.sh
}

[ "$1" ] || { echo "Usage: $0 <install_dir>"; exit 1; }
install_dir="$1"; shift
echo "Installing in $install_dir directory"
mkdir "$install_dir"

clone_repo && bootstrap_wp && build_wp
