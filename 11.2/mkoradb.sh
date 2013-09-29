#!/bin/bash
#
# DB Creation Script for Oracle 12.1
# Simon Krenger <simon@krenger.ch>
# August 2013
export ORACLE_SID=mydb01
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=${ORACLE_BASE}/product/12.1.0/db_1

export MY_ORACLE_PASSWD=tiger
export MY_MEMORY_TARGET=800M
export MY_REDO_SIZE=100M
export MY_CHARSET=AL32UTF8
export MY_NCHARSET=AL16UTF16


### Script start
echo "== Script start =="

# Create folders
echo "Creating folders..."
mkdir -p ${ORACLE_BASE}/admin/${ORACLE_SID}/{pfile,scripts,dpdump,logbook}
mkdir -p /u0{1,2,3}/app/oracle/oradata/${ORACLE_SID}

# Authentication
echo "Executing ORAPWD..."
$ORACLE_HOME/bin/orapwd file=$ORACLE_HOME/dbs/orapw$ORACLE_SID password=$MY_ORACLE_PASSWD

# Prepare files
echo "Preparing files..."

echo "control_files=('/u01/app/oracle/oradata/"${ORACLE_SID}"/control01.ctl', '/u02/app/oracle/oradata/"${ORACLE_SID}"/control02.ctl', '/u03/app/oracle/oradata/"${ORACLE_SID}"/control03.ctl')
db_name="${ORACLE_SID}"
db_domain='krenger.local'
memory_max_target="${MY_MEMORY_TARGET}"
memory_target="${MY_MEMORY_TARGET}"
remote_login_passwordfile=EXCLUSIVE" > ${ORACLE_BASE}/admin/${ORACLE_SID}/pfile/init${ORACLE_SID}.ora

echo "CREATE SPFILE FROM PFILE='"${ORACLE_BASE}"/admin/"${ORACLE_SID}"/pfile/init"${ORACLE_SID}".ora';
STARTUP NOMOUNT;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/01_spfile.sql

echo "CREATE DATABASE "${ORACLE_SID}"
	LOGFILE GROUP 1 ('/u01/app/oracle/oradata/"${ORACLE_SID}"/redo01a.rdo',
			'/u02/app/oracle/oradata/"${ORACLE_SID}"/redo01b.rdo',
			'/u03/app/oracle/oradata/"${ORACLE_SID}"/redo01c.rdo') SIZE "${MY_REDO_SIZE}",
	GROUP 2 ('/u01/app/oracle/oradata/"${ORACLE_SID}"/redo02a.rdo',
		'/u02/app/oracle/oradata/"${ORACLE_SID}"/redo02b.rdo',
		'/u03/app/oracle/oradata/"${ORACLE_SID}"/redo02c.rdo') SIZE "${MY_REDO_SIZE}",
	GROUP 3 ('/u01/app/oracle/oradata/"${ORACLE_SID}"/redo03a.rdo',
		'/u02/app/oracle/oradata/"${ORACLE_SID}"/redo03b.rdo',
		'/u03/app/oracle/oradata/"${ORACLE_SID}"/redo03c.rdo') SIZE "${MY_REDO_SIZE}"
        CHARACTER SET "${MY_CHARSET}"
        NATIONAL CHARACTER SET "${MY_NCHARSET}"
        EXTENT MANAGEMENT LOCAL
        DATAFILE '/u02/app/oracle/oradata/"${ORACLE_SID}"/system01.dbf'
	SIZE 1G AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        SYSAUX DATAFILE '/u02/app/oracle/oradata/"${ORACLE_SID}"/sysaux01.dbf'
	SIZE 1G AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        DEFAULT TEMPORARY TABLESPACE temp TEMPFILE '/u02/app/oracle/oradata/"${ORACLE_SID}"/temp01.dbf'
	SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        UNDO TABLESPACE undo DATAFILE '/u02/app/oracle/oradata/"${ORACLE_SID}"/undo01.dbf'
	SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;

CREATE TABLESPACE users DATAFILE '/u02/app/oracle/oradata/"${ORACLE_SID}"/users01.dbf'
SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/02_create_database.sql

echo "ALTER USER SYS IDENTIFIED BY "${MY_ORACLE_PASSWD}";
ALTER USER SYSTEM IDENTIFIED BY "${MY_ORACLE_PASSWD}";
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/03_sys_users.sql

echo "@?/rdbms/admin/catalog.sql
@?/rdbms/admin/catproc.sql

connect system/"${MY_ORACLE_PASSWD}"
@?/sqlplus/admin/pupbld.sql
exit;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/04_create_catalog.sql

echo "CREATE USER simon IDENTIFIED BY "${MY_ORACLE_PASSWD}";
ALTER USER simon DEFAULT TABLESPACE users;

ALTER USER dbsnmp ACCOUNT UNLOCK;
ALTER USER dbsnmp IDENTIFIED BY dbsnmptiger;

ALTER PROFILE default LIMIT password_life_time unlimited;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/05_default_users.sql

echo "SHUTDOWN IMMEDIATE;
STARTUP;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_restart_db.sql

echo "Files prepared."

# Execute
echo "Now executing SQL*Plus scripts..."
echo "NOTE: This might take some time."

$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/01_spfile.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/02_create_database.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/03_sys_users.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/04_create_catalog.sql
$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/05_default_users.sql

echo "Finished creating the data dictionary, now recompiling invalid objects..."
echo "@?/rdbms/admin/utlrp
exit;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_utlrp.sql

$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_utlrp.sql

echo "Alright, finished everything so far."
echo "Now restarting the database."
$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_restart_db.sql

# Start listener and register database
echo "ALTER SYSTEM REGISTER;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/98_system_register.sql

$ORACLE_HOME/bin/lsnrctl start
$ORACLE_HOME/bin/sqlplus / as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/98_system_register.sql

# SRVCTL and ORATAB
$ORACLE_HOME/bin/srvctl add database -d ${ORACLE_SID} -h $ORACLE_HOME
echo "${ORACLE_SID}:$ORACLE_HOME:Y" >> /etc/oratab

# Cleanup
rm ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/03_sys_users.sql
unset MY_ORACLE_PASSWD

echo DB Setup Finished!
exit 0
