#!/usr/bin/env bash

#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

#
# Shell script for starting the Spark SQL server

# Determine the current working directory
_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [ -z "${SPARK_HOME}" ]; then
  # Preserve the calling directory
  _CALLING_DIR="$(pwd)"

  # Install the proper version of Spark for launching the SQL server
  . ${_DIR}/../thirdparty/install.sh
  install_spark

  # Reset the current working directory
  cd "${_CALLING_DIR}"
else
  SPARK_DIR=${SPARK_HOME}
fi

function usage {
  echo "Usage: ./sbin/start-sql-server.sh [options] [SQL server options]"
  "${SPARK_DIR}"/bin/spark-submit --help 2>&1 | grep -v Usage 1>&2
  echo "SQL server options:"
  echo "  --conf spark.sql.server.port=NUM            Port number of SQL server interface (Default: 5432)."
  echo "  --conf spark.sql.server.worker.threads=NUM  # of SQLServer worker threads (Default: 4)."
  echo "  --conf spark.sql.server.ssl.enabled=BOOL    Enable SSL encryption (Default: false)."
  echo
}

if [[ "$@" = *--help ]] || [[ "$@" = *-h ]]; then
  usage
  exit 0
fi

# Resolve a jar location for the SQL server
_SPARK_VERSION=`grep "<spark.version>" "${_DIR}/../pom.xml" | head -n1 | awk -F '[<>]' '{print $3}'`
_SCALA_VERSION=`grep "<scala.binary.version>" "${_DIR}/../pom.xml" | head -n1 | awk -F '[<>]' '{print $3}'`
_JAR_FILE="sql-server_${_SCALA_VERSION}-${_SPARK_VERSION}-SNAPSHOT-with-dependencies.jar"
_BUILT_JAR="$_DIR/../target/${_JAR_FILE}"
if [ -e $_BUILT_JAR ]; then
  RESOURCES=$_BUILT_JAR
else
  RESOURCES="$_DIR/../assembly/${_JAR_FILE}"
  echo "${_BUILT_JAR} not found, so use pre-compiled ${RESOURCES}"
fi

echo "Using \`spark-submit\` from path: $SPARK_DIR" 1>&2

# An entry point for the SQL server
CLASS="org.apache.spark.sql.server.SQLServer"
PROPERTY_FILE=${_DIR}/../conf/spark-defaults.conf
APP_NAME="Spark SQL Server"

exec "${SPARK_DIR}"/sbin/spark-daemon.sh submit $CLASS 1 --name "${APP_NAME}" --properties-file ${PROPERTY_FILE} "$@" ${RESOURCES}
