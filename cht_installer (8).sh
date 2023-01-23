#!/bin/bash

echo "##################################################"
echo "# CLOUDHEALTH"
echo "# Aggregator 1.7.31"
echo "# SCRIPT VERSION: 1.0"
echo "# GENERATED ON: 2023-01-23T17:40:37+00:00"
echo "#"
echo "# Copyright 2023 All Rights Reserved."
echo "# https://www.cloudhealthtech.com"
echo "##################################################"
echo ""

command_exists () {
  command -v "$1" >/dev/null 2>&1
}

debug () {
  if [ -n "${CHT_DEBUG:+w}" ]; then
    echo " *** $@"
  fi
}

command_exists "curl" || { echo "Missing package 'curl'"; exit 404; }
command_exists "openssl" || { echo "Missing package 'openssl'"; exit 404; }

if command_exists java ; then
  _java="java"
elif [ -n "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ];  then
  _java="$JAVA_HOME/bin/java"
else
  echo "Missing java. Please install Java OpenJDK. Minimum version: 1.7"
  exit 404
fi

version=$("$_java" -version 2>&1 | grep " version " | awk '{ print substr($3, 2, length($3)-2); }' | sed -e 's;[._];0;g')
if [ "$version" -lt 10700000 ]; then
  echo "Java version $version is too old. Please install Java OpenJDK. Minimum version: 1.7"
  exit 404
fi

debug "Proxy host '${PROXY_HOST}', Proxy port '${PROXY_PORT}', Proxy user '${PROXY_USER}', Proxy pass '${PROXY_PASS}'"
debug "http_proxy '${http_proxy}'"

if [ -z "${PROXY_HOST:+w}" ]; then # if host undefined
  read -p "Enter hostname for proxy server - for example 'proxy.company.com' (default: none): " PROXY_HOST
  debug "Proxy host '${PROXY_HOST}'"
fi
if [ -n "${PROXY_HOST:+w}" ]; then # if host defined, then port needed
  PROXY_HOST="${PROXY_HOST/http:///}"

  if [ -z "${PROXY_PORT:+w}" ]; then # if port undefined
    read -p "Enter port number for proxy server (default: 3128): " PROXY_PORT
    if [ -z "${PROXY_PORT:+w}" ]; then
      PROXY_PORT='3128'
    fi
    debug "Proxy port '${PROXY_PORT}'"
  fi
  # so far host and port OK
  if [ -z "${PROXY_USER:+w}" ]; then # if user undefined
    read -p "Enter username for proxy server authentication (default: none): " PROXY_USER
    debug "Proxy user '${PROXY_USER}'"
  fi
  if [ -n "${PROXY_USER:+w}" ]; then # where there is user, there is password
    if [ -z "${PROXY_PASS:+w}" ]; then # if password undefined
      read -p "Enter password for proxy server authentication (default: none): " PROXY_PASS
      debug "Proxy pass '${PROXY_PASS}'"
    fi
    if [ -z "${PROXY_PASS:+w}" ]; then # if password still undefined
      echo "Proxy username provided without a password. Setup cannot continue..."
      exit 404
    fi
    # http_proxy is what curl uses by default from environment variables, so if the param passing somehow fails, this can be used
    export http_proxy="http://${PROXY_USER}:${PROXY_PASS}@${PROXY_HOST}:${PROXY_PORT}"
    debug "Using auth proxy string '${http_proxy}'"
  else # proxy without auth
    export http_proxy="http://${PROXY_HOST}:${PROXY_PORT}"
    debug "Using no auth proxy string '${http_proxy}'"
  fi
fi

if [ -z "$INSTALL_FOLDER" ]; then # if INSTALL_FOLDER is not already defined
  read -p "Please enter the installation folder (default: `pwd`/aggregator_25af0b23): " INSTALL_FOLDER

  if [ -z "$INSTALL_FOLDER" ]; then
    INSTALL_FOLDER="`pwd`/aggregator_25af0b23"
  fi
fi

mkdir -p "$INSTALL_FOLDER" && cd "$INSTALL_FOLDER"

if [ $? -ne 0 ]; then
  sudo mkdir -p "$INSTALL_FOLDER"
  if [ $? -ne 0 ]; then
    exit 1
  fi
  sudo chown $USER:$USER "$INSTALL_FOLDER"
  cd "$INSTALL_FOLDER"
fi

mkdir -p lib/java

echo "Downloading JRuby 1.7.25..."
if [ -z "${http_proxy:+w}" ]; then
  echo "Not using proxy to download jruby 1.7.25"
  curl -s "https://remote-collector.s3.amazonaws.com/lib/jruby-complete-1.7.25.jar" -o "lib/java/jruby-complete-1.7.25.jar"
else
  echo "Using proxy to download jruby 1.7.25"
  debug "proxy is '${http_proxy}'"
  # when proxy, skip certificate validation -k
  curl -x $http_proxy -k -s "https://remote-collector.s3.amazonaws.com/lib/jruby-complete-1.7.25.jar" -o "lib/java/jruby-complete-1.7.25.jar"
fi

JRUBY_HASH=`cat lib/java/jruby-complete-1.7.25.jar | openssl sha256 | sed 's/^.* //'`
if [ "$JRUBY_HASH" != "94521e6004092e59c298802d2144f062cbc9c1dcb347de12057acf623032a1b8" ]; then
  echo "The downloaded lib/java/jruby-complete-1.7.25.jar file does not have the correct hash."
  exit 1
fi

echo "Downloading CloudHealth Tech Remote Aggregator..."
if [ -z "${http_proxy:+w}" ]; then
  echo "Not using proxy to download cht_aggregator.jar"
  curl -s "https://remote-collector.s3.amazonaws.com/1.7/cht_aggregator-1.7.31.68-linux.jar" -o cht_aggregator.jar
else
  echo "Using proxy to download cht_aggregator.jar"
  # when proxy, skip certificate validation -k
  curl -x $http_proxy -k -s "https://remote-collector.s3.amazonaws.com/1.7/cht_aggregator-1.7.31.68-linux.jar" -o cht_aggregator.jar
fi

INSTALLER_HASH=`cat cht_aggregator.jar | openssl sha256 | sed 's/^.* //'`
if [ "$INSTALLER_HASH" != "dc7f0bcd614065d9b45f8de1755d42e95d90f615b0c3f6f141ae34dabe10872a" ]; then
  echo "The downloaded aggregator file does not have the correct hash."
  exit 1
fi

if [ -z "${http_proxy:+w}" ]; then
  echo "Registering with CloudHealth Tech (without proxy)..."
  java -jar cht_aggregator.jar setup --endpoint="https://api.cloudhealthtech.com" --token="25af0b23-0fc4-4ece-a643-2c2ade3ddc8a" --output=cht_aggregator
else
  echo "Registering with CloudHealth Tech (using proxy: ${http_proxy})..."
  debug "Proxy host '${PROXY_HOST}'"
  debug "Proxy port '${PROXY_PORT}'"
  debug "Proxy user '${PROXY_USER}'"
  debug "Proxy pass '${PROXY_PASS}'"
  debug java -jar cht_aggregator.jar setup --endpoint="https://api.cloudhealthtech.com" --token="25af0b23-0fc4-4ece-a643-2c2ade3ddc8a" --output=cht_aggregator --proxy_host="${PROXY_HOST}" --proxy_port="${PROXY_PORT}" --proxy_user="${PROXY_USER}" --proxy_pass="${PROXY_PASS}"
  java -jar cht_aggregator.jar setup --endpoint="https://api.cloudhealthtech.com" --token="25af0b23-0fc4-4ece-a643-2c2ade3ddc8a" --output=cht_aggregator --proxy_host="${PROXY_HOST}" --proxy_port="${PROXY_PORT}" --proxy_user="${PROXY_USER}" --proxy_pass="${PROXY_PASS}"
fi

if [ $? -ne 0 ]; then
  echo "Failed to register. View logs for errors."
  exit 1
fi

# Setup as a service
sudo mv "$INSTALL_FOLDER/cht_aggregator" /etc/init.d
sudo chmod 770 /etc/init.d/cht_aggregator

if command_exists update-rc.d ; then
  sudo update-rc.d cht_aggregator defaults
elif command_exists chkconfig ; then
  sudo chkconfig --add cht_aggregator
  sudo chkconfig --level 2345 cht_aggregator on
fi

sudo /etc/init.d/cht_aggregator start

WatchdogScript=${INSTALL_FOLDER}/cht_aggregator_watchdog.sh
echo "Creating watchdog script: ${WatchdogScript}..."
AGG_INIT_SCRIPT=/etc/init.d/cht_aggregator

cat > ${WatchdogScript} <<_EOF
#!/bin/bash

${AGG_INIT_SCRIPT} status >/dev/null 2>&1
if [ \$? = 0 ]; then
    echo "\$(date +"%F-%T"): Restarting CloudHealth Aggregator..."
    ${AGG_INIT_SCRIPT} restart >/dev/null 2>&1

fi
_EOF

sudo chmod 770 ${WatchdogScript}

# Create cron job: This will be dropped into /etc/cron.d
# /etc/cron.d does not run files that contain a dot, so using underscore
CronFile=${INSTALL_FOLDER}/cht_aggregator_cron
CronJobLog=${INSTALL_FOLDER}/logs/cht_aggregator_watchdog.log

# This is in minutes, derived from (ping_interval * N)/60
CronTimeSlice=3
echo "Creating crontab: ${CronFile}..."
echo "Cron time slice is set to ${CronTimeSlice} minutes"
cat > ${CronFile} <<_EOF
*/${CronTimeSlice} * * * * root ${WatchdogScript} >> ${CronJobLog} 2>&1
_EOF


echo "Installing new watchdog cron..."
sudo chmod 644 ${CronFile}
sudo cp ${CronFile} /etc/cron.d/

LogrotateFile=${INSTALL_FOLDER}/cht_watchdog_logrotate
echo "Creating logrotate file: ${LogrotateFile}..."
cat > ${LogrotateFile} <<_EOF
${CronJobLog} {
        rotate 4
        size 1M
}
_EOF

# See status via: /var/lib/logrotate.status
echo "Installing logrotate file ${LogrotateFile}..."
sudo chmod 664 ${LogrotateFile}
sudo cp ${LogrotateFile} /etc/logrotate.d/

