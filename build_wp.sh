#!/bin/sh

# DOWNLOADS
wp_version="6.4.3"
wp_files="wordpress-$wp_version.tar.gz"
wp_files_url="https://wordpress.org/$wp_files"
wp_repo_url=""

# CONTAINER NAMES
db_container=""
wp_container=""

# VARIABLES
user_email="admin@example.com"
user_passwd=""
db_root_passwd=""
db_user="$USER"
db_name="wordpress-db"
table_prefix=""

maybe_download_wp()
{
	echo "[ WP ] Looking for Wordpress"
	if [ "$(find . -name 'wordpress')" ]
	then
		echo "[ WP ] Wordpress found"
		return
	fi
	echo "[ WP ] Wordpress not found, downloading it"
	if [ ! "$(command -v tar)" ]
	then
		echo "[ WP ] E: Tar binnary not found, required for wordpress download." &&
		echo "[ WP ] E: Please download and extract manually and run this script with the '--skip-wp-dl' flag to skip this step. Exiting" &&
		exit
	else
		[ ! "$(find . -name "$wp_files")" ] &&
			curl -LO $wp_files_url &&
			echo "[ WP ] Wordpress Downloaded!"

		echo "[ WP ] Extracting tar"
		tar -zxf "$wp_files"
		echo "[ WP ] Tar extracted, deleting .tar.gz file"
		rm "$wp_files"
	fi
}

get_wp_repo_url()
{
	[ "" = "$wp_repo_url" ] || return

	echo "Type the repository url: (blank for skipping this step)"
	read -r aux
	[ ! "" = "$aux" ] && wp_repo_url="$aux"
}

maybe_clone_wp_repo()
{
	get_wp_repo_url

	[ "" = "$wp_repo_url" ] && return

	[ ! "$(find . -name "wordpress")" ] && {
		echo "[ GIT ] E: wordpress not yet downloaded, exiting" &&
		exit
	}

	[ "$(find wordpress/wp-content -name ".git")" ] && {
		echo "[ GIT ] E: wp-content already has a git repository, exiting" &&
		exit
	}

	echo "[ GIT ] Cloning $wp_repo_url repository"
	echo "[ GIT ] W: removing wp-content"
	rm -rf ./wordpress/wp-content &&
	git clone "$wp_repo_url" ./wordpress/wp-content
}

get_variables()
{
	echo "[ ENV ] Setting up environtment variables"
	echo "[ ENV ] Input from user"
	while [ "$db_root_passwd" = "" ]
	do
		echo "Type database root password:"
		stty -echo
		read -r db_root_passwd
		stty echo
	done

	echo

	aux=""
	echo "Type database name: (default wordpress-db)"
	read -r aux
	[ ! "" = "$aux" ] && db_name="$aux"

	aux=""
	echo "Type database username: (default $USER)"
	read -r aux
	[ ! "" = "$aux" ] && db_user="$aux"

	while [ "$user_passwd" = "" ]
	do
		echo "Type database password for $db_user:"
		stty -echo
		read -r user_passwd
		stty echo
	done

	echo

	aux=""
	echo "Type user email for wordpress $USER: (default admin@example.com)"
	read -r aux
	[ ! "" = "$aux" ] && user_email="$aux"

	echo

	while [ "$table_prefix" = "" ]
	do
		echo "Type table prefix for $db_name: (example abc_)"
		read -r table_prefix
	done
}

get_servername()
{
	servername='localhost'
	echo "Type the apache ServerName: (default $servername)"
	read -r aux
	[ ! "" = "$aux" ] && servername="$aux"

	echo "ServerName $servername" > servername.conf
}

update_compose_file()
{
	sed "s/++DATABASE_NAME++/$db_name/" < docker-compose.yml > docker-compose.yml.aux &&
	mv -f docker-compose.yml.aux docker-compose.yml
	sed "s/++DATABASE_USER++/$db_user/" < docker-compose.yml > docker-compose.yml.aux &&
	mv -f docker-compose.yml.aux docker-compose.yml
	sed "s/++DATABASE_PASSWORD++/$user_passwd/" < docker-compose.yml > docker-compose.yml.aux &&
	mv -f docker-compose.yml.aux docker-compose.yml
	sed "s/++DATABASE_ROOT_PASSWORD++/$db_root_passwd/" < docker-compose.yml > docker-compose.yml.aux &&
	mv -f docker-compose.yml.aux docker-compose.yml
}

update_wp_config()
{
	#inject getenv_docker function on wp-config"
	sed "20q" ./wordpress/wp-config-sample.php > ./wordpress/wp-config.php
	{
		echo '// a helper function to lookup "env_FILE", "env", then fallback'
		echo 'if (!function_exists("getenv_docker")) {'
		echo '	// https://github.com/docker-library/wordpress/issues/588 (WP-CLI will load this file 2x)'
		echo '	function getenv_docker($env, $default) {'
		echo '		if ($fileEnv = getenv($env . "_FILE")) {'
		echo '			return rtrim(file_get_contents($fileEnv), "\r\n");'
		echo '		}'
		echo '		else if (($val = getenv($env)) !== false) {'
		echo '			return $val;'
		echo '		}'
		echo '		else {'
		echo '			return $default;'
		echo '		}'
		echo '	}'
		echo '}'
	} >> ./wordpress/wp-config.php

	awk 'NR>20 {print $0}' ./wordpress/wp-config-sample.php >> ./wordpress/wp-config.php

	cd wordpress || return

	sed "s/define( 'DB_NAME', 'database_name_here' );/define( 'DB_NAME', '$db_name' );/" < wp-config.php > aux.php &&
	mv -f aux.php wp-config.php
	sed "s/define( 'DB_USER', 'username_here' );/define( 'DB_USER', '$db_user' );/" < wp-config.php > aux.php &&
	mv -f aux.php wp-config.php
	sed "s/define( 'DB_PASSWORD', 'password_here' );/define( 'DB_PASSWORD', '$user_passwd' );/" < wp-config.php > aux.php &&
	mv -f aux.php wp-config.php
	sed "s/define( 'DB_HOST', 'localhost' );/define( 'DB_HOST', 'db:3306' );/" < wp-config.php > aux.php &&
	mv -f aux.php wp-config.php

	sed "s/table_prefix = 'wp_'/table_prefix = getenv_docker('WORDPRESS_TABLE_PREFIX', '$table_prefix')/" < wp-config.php > aux.php &&
	mv -f aux.php wp-config.php

	sed "/put your unique phrase here/d" < wp-config.php > aux.php &&
	mv -f aux.php wp-config.php

	cd ..
}

# This is also handled in the Dockerfile but it's safer to have it here than not
update_htaccess()
{
    echo '# BEGIN WordPress' > ./wordpress/.htaccess
	{
		echo '# The directives (lines) between "BEGIN WordPress" and "END WordPress" are'
		echo '# dynamically generated, and should only be modified via WordPress filters.'
		echo '# Any changes to the directives between these markers will be overwritten.'
		echo '<IfModule mod_rewrite.c>'
		echo 'RewriteEngine On'
		echo 'RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]'
		echo 'RewriteBase /'
		echo 'RewriteRule ^index\.php$ - [L]'
		echo 'RewriteCond %{REQUEST_FILENAME} !-f'
		echo 'RewriteCond %{REQUEST_FILENAME} !-d'
		echo 'RewriteRule . /index.php [L]'
		echo '</IfModule>'
		echo '# END WordPress'
	} >> ./wordpress/.htaccess
}

import_db_dump()
{
	echo
	db_dump="$(find . -name "*.sql")"
	{
		echo "[ DOCKER ] Please run the following commands to import the database:"
		if [ "" = "$db_dump" ]
		then
			db_dump="<DB_DUMP>"
			echo "[ WARNING ] No database file, get a database dump and then run the import"
		fi
		echo "docker exec -i $db_container mysql -u root -p$db_root_passwd $db_name < $db_dump"
	} >> docker_commands.txt
}

wp_search_replace()
{
	echo
	{
		echo "[ DOCKER ] if you imported a DB dump Please run this wp commands"
		echo 'docker exec -i '"$wp_container"' wp --allow-root search-replace "/data/www/<app-name>" "/var/www/html"'
		echo 'docker exec -i '"$wp_container"' wp --allow-root search-replace "https://<app-site>" "http://localhost:8080"'
		echo "docker exec -i $wp_container wp --allow-root user create $USER $user_email --role=administrator --user_pass=$user_passwd"
	} >> docker_commands.txt
}

docker_setup()
{
	echo "[ DOCKER ] Building containers"
	docker-compose build
	docker-compose up -d &&
	db_container="$(docker ps --format "{{.Names}}" | grep db)" &&
	wp_container="$(docker ps --format "{{.Names}}" | grep wordpress)" &&
	echo "[ DOCKER ] Containers built and launched"
}

show_wp_config_variables()
{

	curl -s https://api.wordpress.org/secret-key/1.1/salt/ > wp_config_variables.txt

	{
		echo ""
		echo "define('WP_CRON_LOCK_TIMEOUT', 120);"
		echo "define('AUTOSAVE_INTERVAL', 300);"
		echo "define('WP_AUTO_UPDATE_CORE', false);"
		echo ""
		echo "define('WP_DEBUG', true );"
		echo "define('WP_DEBUG_LOG', true);"
		echo "define('WP_DEBUG_DISPLAY', true);"
		echo "@ini_set('display_errors',1);"
		echo "define('SCRIPT_DEBUG', true);"
		echo ""
		echo "define( 'DISALLOW_FILE_MODS', false );"
		echo "define( 'FORCE_SSL_ADMIN', false);"
		echo ""
		echo "define('ALLOW_UNFILTERED_UPLOADS', true);"
		echo ""
		echo "//define('DISABLE_WP_CRON', true); //it's good to keep this here in case you want to disable cron jobs, all you need to do is uncomment this line"
	} >> wp_config_variables.txt
}

clean_up()
{
	rm -rf setup-wordpress-env
	rm -f build_wp.sh
}

# RUN

[ "$(basename "$0")" = "${SHELL##/bin/}" ] && {
	echo "Please run the script with './build_cs_env.sh' not 'sh build_cs_env.sh'"
	exit 1
}

[ ! "$(command -v docker)" ] || [ ! "$(command -v docker-compose)" ] && {
	echo "Docker or Docker Compose not installed, please install BOTH and then run this script"
	exit 1
}

maybe_download_wp
maybe_clone_wp_repo

get_variables
#servername is static for now
#get_servername

update_compose_file
update_htaccess
update_wp_config
show_wp_config_variables

echo "[ DOCKER ] Setting up containers"
docker_setup

clean_up
echo
echo "Now to finish your wp-config.php file, put the keys and variables"
echo "found in the file wp_config_variables.txt in your wp-config.php file"
echo
echo "After you've set the keys and variables, run these docker commands and you're good to go."
echo "The docker commands can also be found in docker_commands.txt"
echo "Don't forget to download the images to put under wp-content/uploads"
import_db_dump
wp_search_replace
cat docker_commands.txt
