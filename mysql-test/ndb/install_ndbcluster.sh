#!/bin/sh
# Copyright (C) 2004 MySQL AB
# For a more info consult the file COPYRIGHT distributed with this file

# This scripts starts the table handler ndbcluster

# configurable parameters, make sure to change in mysqlcluterd as well
port_base="22"  # using ports port_base{"00","01", etc}
fsdir=`pwd`
# end configurable parameters

# Are we using a source or a binary distribution?

if [ -d ../sql ] ; then
   SOURCE_DIST=1
   ndbtop=`pwd`/../ndb
   exec_ndb=$ndbtop/src/kernel/ndb-main/ndb
   exec_mgmtsrvr=$ndbtop/src/mgmsrv/mgmtsrvr
   exec_waiter=$ndbtop/tools/ndb_waiter
   exec_mgmtclient=$ndbtop/src/mgmclient/mgmtclient
else
   BINARY_DIST=1
   exec_ndb=@ndbbindir@/ndb
   exec_mgmtsrvr=@ndbbindir@/mgmtsrvr
   exec_waiter=@ndbtoolsdir@/ndb_waiter
   exec_mgmtclient=@ndbbindir@/mgmtclient
fi

pidfile=ndbcluster.pid

while test $# -gt 0; do
  case "$1" in
    --initial)
     flags_ndb=$flags_ndb" -i"
     initial_ndb=1
     ;;
    --data-dir=*)
     fsdir=`echo "$1" | sed -e "s;--data-dir=;;"`
     ;;
    --port-base=*)
     port_base=`echo "$1" | sed -e "s;--port-base=;;"`
     ;;
    -- )  shift; break ;;
    --* ) $ECHO "Unrecognized option: $1"; exit 1 ;;
    * ) break ;;
  esac
  shift
done

fs_ndb=$fsdir/ndbcluster
fs_mgm_1=$fs_ndb/1.ndb_mgm
fs_ndb_2=$fs_ndb/2.ndb_db
fs_ndb_3=$fs_ndb/3.ndb_db
fs_name_2=$fs_ndb/node-2-fs
fs_name_3=$fs_ndb/node-3-fs

NDB_HOME=
export NDB_CONNECTSTRING
if [ ! -x $fsdir ]; then
  echo "$fsdir missing"
  exit 1
fi
if [ ! -x $exec_ndb ]; then
  echo "$exec_ndb missing"
  exit 1
fi
if [ ! -x $exec_mgmtsrv ]; then
  echo "$exec_mgmtsrvr missing"
  exit 1
fi

start_default_ndbcluster() {

# do some checks

NDB_CONNECTSTRING=

if [ $initial_ndb ] ; then
  [ -d $fs_ndb ] || mkdir $fs_ndb
  [ -d $fs_mgm_1 ] || mkdir $fs_mgm_1
  [ -d $fs_ndb_2 ] || mkdir $fs_ndb_2
  [ -d $fs_ndb_3 ] || mkdir $fs_ndb_3
  [ -d $fs_name_2 ] || mkdir $fs_name_2
  [ -d $fs_name_3 ] || mkdir $fs_name_3
fi
if [ -d "$fs_ndb" -a -d "$fs_mgm_1" -a -d "$fs_ndb_2" -a -d "$fs_ndb_3" -a -d "$fs_name_2" -a -d "$fs_name_3" ]; then :; else
  echo "$fs_ndb filesystem directory does not exist"
  exit 1
fi

# set som help variables

ndb_host="localhost"
ndb_port=$port_base"00"
NDB_CONNECTSTRING_BASE="host=$ndb_host:$ndb_port;nodeid="


# Start management server as deamon

NDB_ID="1"
NDB_CONNECTSTRING=$NDB_CONNECTSTRING_BASE$NDB_ID

# Edit file system path and ports in config file

if [ $initial_ndb ] ; then
sed \
    -e s,"CHOOSE_HOSTNAME_".*,"$ndb_host",g \
    -e s,"CHOOSE_FILESYSTEM_NODE_2","$fs_name_2",g \
    -e s,"CHOOSE_FILESYSTEM_NODE_3","$fs_name_3",g \
    -e s,"CHOOSE_PORT_BASE",$port_base,g \
    < ndb/ndb_config_2_node.ini \
    > "$fs_mgm_1/config.ini"
fi

if ( cd $fs_mgm_1 ; echo $NDB_CONNECTSTRING > Ndb.cfg ; $exec_mgmtsrvr -d -c config.ini ) ; then :; else
  echo "Unable to start $exec_mgmtsrvr from `pwd`"
  exit 1
fi

cat `find $fs_ndb -name 'node*.pid'` > $pidfile

# Start database node 

NDB_ID="2"
NDB_CONNECTSTRING=$NDB_CONNECTSTRING_BASE$NDB_ID
( cd $fs_ndb_2 ; echo $NDB_CONNECTSTRING > Ndb.cfg ; $exec_ndb -d $flags_ndb & )

cat `find $fs_ndb -name 'node*.pid'` > $pidfile

# Start database node 

NDB_ID="3"
NDB_CONNECTSTRING=$NDB_CONNECTSTRING_BASE$NDB_ID
( cd $fs_ndb_3 ; echo $NDB_CONNECTSTRING > Ndb.cfg ; $exec_ndb -d $flags_ndb & )

cat `find $fs_ndb -name 'node*.pid'` > $pidfile

# Start management client

sleep 10
echo "show" | $exec_mgmtclient $ndb_host $ndb_port

# test if Ndb Cluster starts properly

NDB_ID="11"
NDB_CONNECTSTRING=$NDB_CONNECTSTRING_BASE$NDB_ID
if ( $exec_waiter ) | grep "NDBT_ProgramExit: 0 - OK"; then :; else
  echo "Ndbcluster startup failed"
  exit 1
fi

echo $NDB_CONNECTSTRING > Ndb.cfg

cat `find $fs_ndb -name 'node*.pid'` > $pidfile
}

start_default_ndbcluster

exit 0
