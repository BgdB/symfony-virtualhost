#!/bin/bash

#Declaration of constants
RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
RESET=`tput sgr0`
LOCATION=`readlink -e ~/Sites/`
PATH="/trunk/server/web"
ENTRY="app.php"
VERSION=2
SITES_ENABLED="/etc/apache2/sites-enabled/"
ETC_HOSTS="/etc/hosts"
ERROR_LOG="/var/log/apache2/"
TEMPORARY_BU="temp"
VIRTUAL_HOST="<VirtualHost *:80>\n\tServerName %s\n\tDocumentRoot %s\n\tDirectoryIndex %s\n\tErrorLog %s\n\tCustomLog %s combined\n\t<Directory \"%s\">\n\t\tAllowOverride All\n\t\tAllow from All\n\t\tRequire all granted\n\t</Directory>\n</VirtualHost>\n"

#Declaration of functions
prompt_confirm() {
  while true; do
    read -r -n 1 -p "${1:-Continue?} [y/n]: " REPLY
    case $REPLY in
      [yY]) echo ; return 0 ;;
      [nN]) echo ; return 1 ;;
      *) printf " \033[31m %s \n\033[0m" "invalid input"
    esac
  done
}

printf "\n${GREEN}Hi! You have opened a virtual host creator mostly for Symfony projects${RESET}\n\n"

# TODO: read optional parameters and use them
#COUNTER=1
#while (( $COUNTER <= "$#" ))
#do
#	if [ ${!COUNTER} = "-l" ]
#	then
#        let COUNTER=COUNTER+1
#        if [ -d "${!COUNTER}" ]; then
#            location=${!COUNTER}
#        else
#            echo "${RED}Invalid location ${YELLOW}\"${!COUNTER}\"${RED}!${RESET}"
#		fi
#	elif [ ${!COUNTER} = "-h" ]
#	then
#        let COUNTER=COUNTER+1
#        host=${!COUNTER}
#	elif [ ${!COUNTER} = "-v" ]
#	then
#        let COUNTER=COUNTER+1
#        version=${!COUNTER}
#	elif [ ${!COUNTER} = "-e" ]
#	then
#        let COUNTER=COUNTER+1
#        entry=${!COUNTER}
#	elif [ ${!COUNTER} = "-p" ]
#	then
#        let COUNTER=COUNTER+1
#        path=${!COUNTER}
#	else
#		proj_name=${!COUNTER}
#	fi
#
#	let COUNTER=COUNTER+1
#done

#read location if it is not provided
if [ -z "$location" ]; then
	echo -ne "Enter the project location [${YELLOW}${LOCATION}${RESET}]: "
	read location
	location=${location:-"${LOCATION}"}
	while [ ! -d "$location/$proj_name" ] || [ -z "$proj_name" ]; do
		if [ -d "$location" ]; then
			echo -ne "Please enter a valid project name, followed by [ENTER]: "
			read proj_name
		else
			echo -ne "Please enter a valid location [${YELLOW}${LOCATION}${RESET}]: "
			read location
			location=${location:-"${LOCATION}"}
		fi
	done
fi

if [ -z "$proj_name" ]; then
    echo -ne "Please provide the project name, followed by [ENTER]: "
    read proj_name
    while [ -z "$proj_name" ]; do
	    echo -ne "Please provide the project name, followed by [ENTER]: "
	    read proj_name
    done
fi

#read host name
if [ -z "$host" ]; then
	echo -ne "Enter the host name [${YELLOW}"${proj_name,,}".local${RESET}]: "
	read hostName
	host=${hostName:-"${proj_name,,}.local"}

    while [ -f "$SITES_ENABLED$host.conf" ] || [ -z "$host" ]; do
	    echo -ne "The provided host exists, please enter another one followed by [ENTER]: "
		read hostName
		host=${hostName:-"${proj_name,,}.local"}
    done
fi

#read entry point path
if [ -z "$path" ]; then
	echo -ne "Enter the path to entry point [${YELLOW}$PATH${RESET}]: "
	read path
	path=${path:-$PATH}

    while [ ! -d "$location/$proj_name$path" ]; do
	    echo -ne "Please provide a valid path [${YELLOW}$PATH${RESET}]: "
		read path
		path=${path:-$PATH}
    done
fi

#read entry point file
if [ -z "$entry" ]; then
	echo -ne "Enter the entry point [${YELLOW}$ENTRY${RESET}]: "
	read entry
	entry=${entry:-$ENTRY}

    while [ ! -f "$location/$proj_name$path/$entry" ]; do
	    echo -ne "Please provide a valid entry point [${YELLOW}$ENTRY${RESET}]: "
		read entry
		entry=${entry:-$ENTRY}
    done
fi

#read error log file (to be set on the virtual host)
if [ -z "$error_log" ]; then
	echo -ne "Enter the error log file [${YELLOW}$ERROR_LOG${proj_name,,}-error.log${RESET}]: "
	read error_log
	error_log=${error_log:-"$ERROR_LOG${proj_name,,}-error.log"}
fi


#read custom log file (to be set on the virtual host)
if [ -z "$custom_log" ]; then
	echo -ne "Enter the custom log file [${YELLOW}$ERROR_LOG${proj_name,,}-access.log${RESET}]: "
	read custom_log
	custom_log=${custom_log:-"$ERROR_LOG${proj_name,,}-access.log"}
fi

printf -v content "$VIRTUAL_HOST" $host $location/$proj_name$path $entry $error_log $custom_log $location/$proj_name$path

#add the host in /etc/hosts with backup file
/usr/bin/sudo /bin/cp $ETC_HOSTS $TEMPORARY_BU
/usr/bin/sudo sh -c "echo 127.0.0.1'\t'$host'\n'\"$(/bin/cat $ETC_HOSTS)\" > $ETC_HOSTS"

if [ $? -eq 0 ]; then
    /usr/bin/sudo /bin/rm $TEMPORARY_BU
    echo "${GREEN}The host was written succesfully in ${YELLOW}$ETC_HOSTS${RESET}"
else
    /usr/bin/sudo /bin/mv $TEMPORARY_BU $ETC_HOSTS
    echo "${RED}The host was not written succesfully. ${YELLOW}$ETC_HOSTS${RED} restored to previous version. ${RESET}"
fi

/usr/bin/sudo sh -c "echo \"$content\" >> $SITES_ENABLED$host.conf"

/usr/bin/sudo service apache2 restart

prompt_confirm "Do you want to automatically set permissions?"

if [[ $? == 1 ]]; then
	echo "${GREEN}Setup ended successfully!${RESET}"
	exit 0
fi

#read symfony version (to know what set of commands to use for setting permissions
if [ -z "$version" ]; then
	echo -ne "Enter the version of symfony [${YELLOW}$VERSION${RESET}]: "
	read version
	version=${version:-$VERSION}
fi

#change the directoy to the project (specific to Symfony file structure)
cd $location/$proj_name$path/../

if [[ version == 2 ]]; then
	$("HTTPDUSER=`ps axo user,comm | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1`")
	$("sudo setfacl -R -m u:\"$HTTPDUSER\":rwX -m u:`whoami`:rwX app/cache app/logs")
	$("sudo setfacl -dR -m u:\"$HTTPDUSER\":rwX -m u:`whoami`:rwX app/cache app/logs")
elif [[ version == 3 ]]; then
	$("HTTPDUSER=`ps axo user,comm | grep -E '[a]pache|[h]ttpd|[_]www|[w]ww-data|[n]ginx' | grep -v root | head -1 | cut -d\  -f1`")
	$("sudo setfacl -R -m u:\"$HTTPDUSER\":rwX -m u:`whoami`:rwX var")
	$("sudo setfacl -dR -m u:\"$HTTPDUSER\":rwX -m u:`whoami`:rwX var")
fi

# TODO: Ask the user to run composer install and some other commands that we usually run when setting a project (create database, schema, etc.)
#prompt_confirm "Do you want run $ composer install?"

echo "${GREEN}Setup ended successfully!${RESET}"