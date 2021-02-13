#!/bin/sh

LOCAL='/usr/bin:/usr/local/bin:/usr/local/sbin'
FILEOWNER=$USER
GROUPOWNER='www-data'
CURUSER=`ps -o user= -p $$ | awk '{print $1}'`
CONTAINERHOMEDIR='/var/www/html'

echo "File owner: $FILEOWNER"
echo "Current owner: $CURUSER"


init () 
{
    if [ $1 -eq 0 ]
    then
        echo "You must specify a site"
        echo "Parameter 1 is required to be a site name that will be copied to a container."
        exit 1

    elif [ $1 -eq 1 ]
        then 
            check_dir_exists $2
    else
        echo "Only one argument is allowed"
        exit 1
    fi
}

check_dir_exists () 
{
    TARGETDIR="$1"

    if [ ! -d "/home/$USER/$TARGETDIR" ] ;
        then 
        echo "$TARGETDIR is not a directory"
        exit 1 
    else
        check_multisite
        prepare_docker_copy
    fi

}

get_table_prefix () 
{
    WPDBTABLEPREFIX=`cat /home/$USER/$TARGETDIR/wp-config.php | grep table_prefix | cut -d "'" -f 2 `
}

check_multisite () 
{
    echo "Is this a multisite installation of Wordpress? [No/y]" 
    read response

    if [ -z "$response" ] || [ "$response" = 'n' ];
    then
        echo "Proceeding with single-site installation"
    elif [ $response = "y" ];
    then
        MULTISITE=true
        echo "Proceeding with multi-site installation"
    else
        check_multisite
    fi

    get_table_prefix

    echo ISMULTISITE=$MULTISITE > .env

    echo WPDBTABLEPREFIX=$WPDBTABLEPREFIX >> .env
}

prepare_docker_copy () 
{
    remove_wpengine_files
}

start_containers ()
{
    docker-compose up --build -d 

    CURDIR=${PWD##*/} 

    WPCONTAINER=`docker ps -a --no-trunc --filter name=^/${CURDIR}_wordpress_1$ | awk  'NR>1{print $1}'`
    DBCONTAINER=`docker ps -a --no-trunc --filter name=^/${CURDIR}_db_1$ | awk  'NR>1{print $1}'` 
    ELASTICCONTAINER=`docker ps -a --no-trunc --filter name=^/${CURDIR}_elasticsearch_1$ | awk  'NR>1{print $1}'` 

    echo "Current db container: $DBCONTAINER"
    echo "Current WP container: $WPCONTAINER"
    echo "Current Elastic container: $ELASTICCONTAINER"

}

copy_to_container ()
{
    docker cp /home/$USER/$TARGETDIR/wp-content "$WPCONTAINER:$CONTAINERHOMEDIR"

    if [ -z "$MULTISITE" ]
    then
        docker cp ${PWD}/.htaccess "$WPCONTAINER:$CONTAINERHOMEDIR"
    fi

}

dump_sql_into_container ()
{
    docker exec -i $DBCONTAINER mysql -uexampleuser -pexamplepass exampledb < /home/$USER/$TARGETDIR/wp-content/mysql.sql

    echo "Data successfully dumped into db container: $DBCONTAINER"
}

restore_permissions () 
{
    echo "Resetting $CONTAINERHOMEDIR permissions"

    docker exec -it $WPCONTAINER  chmod -R 770 $CONTAINERHOMEDIR
    docker exec -it $WPCONTAINER  chown -R $GROUPOWNER:$GROUPOWNER $CONTAINERHOMEDIR
    docker exec -it $WPCONTAINER  chmod 755 wp-content/
    docker exec -it $WPCONTAINER  chmod 644 wp-config.php
}
        
run_scripts ()
{

    if [ -f /var/www/html/package-lock.json ]:
        then
            npm install
            grunt
        else
           echo "No package-lock.json found in root" 
    fi
}

install_composer () 
{
    docker exec -it $WPCONTAINER composer install 
    docker exec -it $WPCONTAINER chown -R $GROUPOWNER:$GROUPOWNER vendor
}


remove_wpengine_files ()
{
    rm -f $TARGETDIR/wp-content/mu-plugins/mu-plugin.php
    rm -f $TARGETDIR/wp-content/mu-plugins/wpengine-common/
    rm -f $TARGETDIR/wp-content/mu-plugins/slt-force-strong-passwords.php
    rm -f $TARGETDIR/wp-content/mu-plugins/force-strong-passwords/
    rm -f $TARGETDIR/wp-content/mu-plugins/stop-long-comments.php
    rm -f $TARGETDIR/wp-content/advanced-cache.php
    rm -f $TARGETDIR/wp-content/object-cache.php
    rm -f $TARGETDIR/wp-content/mu-plugins/wpe-wp-sign-on-plugin/
    rm -f $TARGETDIR/wp-content/mu-plugins/wpe-wp-sign-on-plugin.php
    rm -f $TARGETDIR/wp-content/mu-plugins/wpengine-security-auditor.php
    rm -rf $TARGETDIR/wp-content/plugins/wflogs
    rm -rf $TARGETDIR/wp-content/plugins/wordfence
    rm -rf $TARGETDIR/wp-content/plugins/hello.php

    start_containers
    copy_to_container
    restore_permissions
    run_scripts  

    sleep 10

    if [ -z "$MULTISITE" ] 
        then
        dump_sql_into_container
        install_composer

    else
        echo "Database created without dumpfile"
        install_composer
        docker exec -it $WPCONTAINER wp core multisite-install --allow-root --title="${TARGETDIR}" --admin_user="admin" --admin_password="admin" --admin_email="admin@example.com"  
    fi

}

init $# $@


