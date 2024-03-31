# setup-development
Scripts and files needed to setup a development environment using docker and docker-compose.

Simply run ```curl -s ./run.sh | sh``` and follow the instructions.


After that you should be good to go!

# XDebug for PHP and VSCode
## Requirements
+ VSCode
+ PHP Debug extension for VSCode

## How to configure
Install PHP Debug extension for VSCode if you don't have it already. The ```Dockerfile``` already contains the steps for making XDebug available in the environment being built. What's left to be done is for you to copy the ```./xdebug-files/launch.json``` file in this repository to the ```.vscode/``` directory in the root directory of your VSCode workspace.

## Possible problems and how to debug XDebug
You might encounter some issues so, first copy the ```./xdebug-files/xdebug-info.php``` file in this repo to your wordpress installation and open it in your browser by accessing ```http://localhost:8080/xdebug-info.php``` for example, you place it in the root directory of the Wordpress installation. If it loads, it means XDebug is installed.
Another thing you can do is access the terminal of the running docker container, and check the log file located at ```/tmp/xdebug.log```.
The most common problem with the ```.vscode/launch.json```file is the ```pathMappings``` value pair, where the first value is the path from the container, where the Wordpress files are sitting, and the second value where the same files are sitting on VSCode. VSCode needs to be able to tell what are the directories it needs to look for in order to match what's being executed and called by XDebug, and stop bring that to the UI for you to debug where you put your breaking point.

## To do List
+ Add ngrok support
+ Add dinamic ServerName support
+ Edit wp-config.php programatically
+ Run docker commands programatically
