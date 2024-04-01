#!/bin/bash

repo_name="setup-wordpress-env"

clone_repo()
{
	git clone "git@github.com:luccaugusto/$repo_name.git"
}

bootstrap_wp()
{
	#cp -r "$repo_name"/xdebug-files "$install_dir/"
	cp "$repo_name"/php.ini "$install_dir/"
	cp "$repo_name"/build_wp.sh "$install_dir/"
	cp "$repo_name"/docker-compose.yml "$install_dir/"
	cp "$repo_name"/Dockerfile "$install_dir/"
}

build_wp()
{
	echo "REMEMBER TO MOVE DB DUMP TO $install_dir TOO"

	./build_wp.sh
}

install_dir=""

echo "Enter the directory to install the project:"
while [ "" = "$install_dir" ]; do
	read install_dir
done

echo "Installing in $install_dir directory"
mkdir "$install_dir"
cd "$install_dir" || exit

clone_repo && bootstrap_wp && build_wp
