#!/bin/bash
#
# DB Creation Script for Oracle 12.1
# Simon Krenger <simon@krenger.ch>

# Oracle mountpoints.
# OFA defines the following usages (Array indexes):
# Index 0: Software Mountpoint
# Index 1: Datafiles
# Index 2: Redo Logs
# Index 3: Redo Logs
ORACLE_USER=oracle
ORACLE_MOUNTPOINTS=(/u01 /u02 /u03 /u04)
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=${ORACLE_BASE}/product/12.1.0/db_1
export PATH=$PATH:$ORACLE_HOME/bin
export ORACLE_SID=kdb01
export ORACLE_DOMAIN=$(hostname)

MY_ORACLE_PASSWD=tiger
MY_MEMORY_TARGET=800M
MY_CHARSET=AL32UTF8
MY_NCHARSET=AL16UTF16
MY_REDO_SIZE=50M
MY_SYSTEM_SIZE=50M
MY_SYSAUX_SIZE=50M
MY_TEMP_SIZE=50M
MY_UNDO_SIZE=50M

usage()
{
cat << EOF
usage: $0 [-d "dbname"] [-c "charset"] [-n "ncharset"] [-m "memory_size"]
          [-p "password"] [-h]

Database creation script for Oracle 12.1

OPTIONS:
    -h     Show this message
    -d     Database name (defaults to '$ORACLE_SID')
    -c     Database Character Set (defaults to '$MY_CHARSET')
    -n     Database National Character Set (defaults to '$MY_NCHARSET')
    -m     MEMORY_TARGET (defaults to '$MY_MEMORY_TARGET')
    -p     Password for SYS and SYSTEM (defaults to '$MY_ORACLE_PASSWD')
EOF
}

while getopts "hd:c:n:m:p:" OPTION
do
	case $OPTION in
		h)
		    usage
		    exit 1
		    ;;
		d)
		    export ORACLE_SID=$OPTARG
		    ;;
		c)
		    MY_CHARSET=$OPTARG
		    ;;
		n)
		    MY_NCHARSET=$OPTARG
		    ;;
		m)
		    MY_MEMORY_TARGET=$OPTARG
		    ;;
		p)
		    MY_ORACLE_PASSWD=$OPTARG
		    ;;
		?)
		    usage
		    exit 1
		    ;;
	esac
done

### Script start
echo "== Script start =="

if [[ $(whoami) != $ORACLE_USER ]]; then 
	echo "Not $ORACLE_USER, aborting..."
	exit 1
fi

which nproc
if [ $? -eq 0 ]; then
        echo "nproc is available"
else
        echo "nproc not found, aborting..."
        exit 1
fi

# Create folders
echo "Creating folders..."
mkdir -p ${ORACLE_BASE}/admin/${ORACLE_SID}/{pfile,scripts,dpdump,logbook}
for mountpoint in ${ORACLE_MOUNTPOINTS[*]}
do
	mkdir -p $mountpoint/app/oracle/oradata/${ORACLE_SID}
	if [ $? -ne 0 ]; then
		echo "Error creating $mountpoint/app/oracle/oradata/${ORACLE_SID}"
		exit 1
	fi
done
mkdir -p /u02/app/oracle/oradata/${ORACLE_SID}/pdbseed

# Authentication
echo "Executing ORAPWD..."
$ORACLE_HOME/bin/orapwd file=$ORACLE_HOME/dbs/orapw$ORACLE_SID password=$MY_ORACLE_PASSWD
if [ $? -ne 0 ]; then
	echo "Error running ORAPWD."
	exit 1
fi

# Prepare files
echo "Preparing files..."

echo "control_files=('/u01/app/oracle/oradata/"${ORACLE_SID}"/control01.ctl', '/u02/app/oracle/oradata/"${ORACLE_SID}"/control02.ctl', '/u03/app/oracle/oradata/"${ORACLE_SID}"/control03.ctl')
db_name="${ORACLE_SID}"
db_domain='${ORACLE_HOSTNAME}'
memory_max_target="${MY_MEMORY_TARGET}"
memory_target="${MY_MEMORY_TARGET}"
remote_login_passwordfile=EXCLUSIVE
enable_pluggable_database=TRUE" > ${ORACLE_BASE}/admin/${ORACLE_SID}/pfile/init${ORACLE_SID}.ora

echo "CREATE SPFILE FROM PFILE='"${ORACLE_BASE}"/admin/"${ORACLE_SID}"/pfile/init"${ORACLE_SID}".ora';
STARTUP NOMOUNT;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/01_spfile.sql

cat <<EOF > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/02_create_database.sql
CREATE DATABASE ${ORACLE_SID}
	LOGFILE GROUP 1 ('/u03/app/oracle/oradata/${ORACLE_SID}/redo01a.rdo',
			'/u04/app/oracle/oradata/${ORACLE_SID}/redo01b.rdo') SIZE ${MY_REDO_SIZE},
	GROUP 2 ('/u03/app/oracle/oradata/${ORACLE_SID}/redo02a.rdo',
		'/u04/app/oracle/oradata/${ORACLE_SID}/redo02b.rdo') SIZE ${MY_REDO_SIZE},
	GROUP 3 ('/u03/app/oracle/oradata/${ORACLE_SID}/redo03a.rdo',
		'/u04/app/oracle/oradata/${ORACLE_SID}/redo03b.rdo') SIZE ${MY_REDO_SIZE}
        CHARACTER SET ${MY_CHARSET}
        NATIONAL CHARACTER SET ${MY_NCHARSET}
        EXTENT MANAGEMENT LOCAL
        DATAFILE '/u02/app/oracle/oradata/${ORACLE_SID}/system01.dbf'
	SIZE ${MY_SYSTEM_SIZE} AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        SYSAUX DATAFILE '/u02/app/oracle/oradata/${ORACLE_SID}/sysaux01.dbf'
	SIZE ${MY_SYSAUX_SIZE} AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        DEFAULT TEMPORARY TABLESPACE temp TEMPFILE '/u02/app/oracle/oradata/${ORACLE_SID}/temp01.dbf'
	SIZE ${MY_TEMP_SIZE} AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        UNDO TABLESPACE undo DATAFILE '/u02/app/oracle/oradata/${ORACLE_SID}/undo01.dbf'
	SIZE ${MY_UNDO_SIZE} AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        ENABLE PLUGGABLE DATABASE
        SEED
        FILE_NAME_CONVERT = ('/u02/app/oracle/oradata/${ORACLE_SID}/', '/u02/app/oracle/oradata/${ORACLE_SID}/pdbseed/')
        SYSTEM DATAFILES SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED
        SYSAUX DATAFILES SIZE 100M
        USER_DATA TABLESPACE users DATAFILE '/u02/app/oracle/oradata/${ORACLE_SID}/pdbseed/users01.dbf'
	SIZE 100M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;

CREATE TABLESPACE users DATAFILE '/u02/app/oracle/oradata/${ORACLE_SID}/users01.dbf'
SIZE 100M AUTOEXTEND ON NEXT 50M MAXSIZE UNLIMITED;
EXIT;
EOF

echo "ALTER USER SYS IDENTIFIED BY "${MY_ORACLE_PASSWD}";
ALTER USER SYSTEM IDENTIFIED BY "${MY_ORACLE_PASSWD}";
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/03_sys_users.sql

echo "SHUTDOWN IMMEDIATE;
STARTUP;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_restart_db.sql

echo "Files prepared."

# Execute
echo "Now executing SQL*Plus scripts..."
echo "NOTE: This might take some time."

for sql in ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/01_spfile.sql \
           ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/02_create_database.sql \
           ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/03_sys_users.sql
do
	echo "$sql"
	$ORACLE_HOME/bin/sqlplus "sys/${MY_ORACLE_PASSWD}" as sysdba @$sql
done

echo "Executed SQL*Plus scripts, now creating the data dictionary."
echo "NOTE: This may take some time."

PERL5LIB=$ORACLE_HOME/rdbms/admin:$PERL5LIB; export PERL5LIB
perl $ORACLE_HOME/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${ORACLE_SID}/logbook -b catalog -u SYS/${MY_ORACLE_PASSWD} $ORACLE_HOME/rdbms/admin/catalog.sql;
perl $ORACLE_HOME/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${ORACLE_SID}/logbook -b catproc -u SYS/${MY_ORACLE_PASSWD} $ORACLE_HOME/rdbms/admin/catproc.sql;
perl $ORACLE_HOME/rdbms/admin/catcon.pl -n 1 -l ${ORACLE_BASE}/admin/${ORACLE_SID}/logbook -b pupbld -u SYSTEM/${MY_ORACLE_PASSWD} $ORACLE_HOME/sqlplus/admin/pupbld.sql;

echo "Finished creating the data dictionary, now recompiling invalid objects..."
echo "@?/rdbms/admin/utlrp
exit;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_utlrp.sql

$ORACLE_HOME/bin/sqlplus "sys/${MY_ORACLE_PASSWD}" as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_utlrp.sql



echo "Alright, finished everything so far."
echo "Now restarting the database."
$ORACLE_HOME/bin/sqlplus "sys/${MY_ORACLE_PASSWD}" as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/99_restart_db.sql

echo "ALTER SYSTEM REGISTER;
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/98_system_register.sql
$ORACLE_HOME/bin/sqlplus "sys/${MY_ORACLE_PASSWD}" as sysdba @${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/98_system_register.sql

# SRVCTL and ORATAB
echo "Now calling SRVCTL..."
$ORACLE_HOME/bin/srvctl add database -db ${ORACLE_SID} -oraclehome $ORACLE_HOME
echo "${ORACLE_SID}:${ORACLE_HOME}:Y" >> /etc/oratab

# Cleanup
echo "ALTER USER SYS IDENTIFIED BY "******";
ALTER USER SYSTEM IDENTIFIED BY "******";
EXIT;" > ${ORACLE_BASE}/admin/${ORACLE_SID}/scripts/03_sys_users.sql

unset MY_ORACLE_PASSWD

echo DB Setup Finished!
exit 0
