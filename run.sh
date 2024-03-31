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

	./build_wp.sh
}

install_dir=""

echo "Enter the directory to install the project:"
while [ "" = "$install_dir" ]; do
	read -r install_dir
done

echo "Installing in $install_dir directory"
mkdir "$install_dir"
cd "$install_dir" || exit

clone_repo && bootstrap_wp && build_wp
