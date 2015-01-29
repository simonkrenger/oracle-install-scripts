#!/bin/bash
#
# DB Software Installation script
# Installs Oracle Grid Infrastructure and Database software
#
# Prerequisites:
# - Installed package "oracle-rdbms-server-12cR1-preinstall.rpm"
# - Executed oracle-rdbms-server-12cR1-preinstall-verify
# - Copied GI and DB software (the following archives) to $ORACLE_INSTALLFILES_LOCATION
#   - linuxamd64_*_database_1of2.zip
#   - linuxamd64_*_database_2of2.zip
#   - linuxamd64_*_grid_1of2.zip
#   - linuxamd64_*_grid_2of2.zip
# - (Optional) # passwd oracle
# - Mountpoints $ORACLE_MOUNTPOINTS exist
#
# Simon Krenger <simon@krenger.ch>

ORACLE_MOUNTPOINTS=(/u01 /u02 /u03 /u04)

ORACLE_USER=oracle
ORACLE_BASE=${ORACLE_MOUNTPOINTS[0]}/app/oracle
ORACLE_HOME=${ORACLE_BASE}/product/12.1.0/db_1
ORACLE_INVENTORY_LOCATION=/etc/oraInventory
ORACLE_INSTALLFILES_LOCATION=/home/oracle

GRID_USER=oracle
GRID_BASE=${ORACLE_MOUNTPOINTS[0]}/app/grid
GRID_HOME=${GRID_BASE}/product/12.1.0/grid_1

ORACLE_MEMORY_SIZE=2048M

unset LANG

### Script start

usage()
{
cat << EOF
usage: $0 [-h] [-u ORACLE_USER] [-m ORACLE_MEMORY_SIZE] [-i INSTALLFILES_DIR]

This script is used to install Oracle Grid Infrastructure and the Oracle
database software. The default settings will install the database software
according to the OFA standard.

OPTIONS:
   -h      Show this message
   -i      Folder that contains the installation ZIP files. Defaults to "$ORACLE_INSTALLFILES_LOCATION"
   -u      User that owns the Oracle software installation. Defaults to "$ORACLE_USER"
   -m      Aggregate shared memory size for all databases on this machine.
           Defaults to $ORACLE_MEMORY_SIZE.
EOF
}

# Parse arguments
while getopts "hi:u:m:" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         i)
             ORACLE_INSTALLFILES_LOCATION=$OPTARG
             ;;
	 u)
	     ORACLE_USER=$OPTARG
	     ;;
	 m)
	     ORACLE_MEMORY_SIZE=$OPTARG
	     ;;
         ?)
             usage
             exit
             ;;
     esac
done

# Check if run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

id $ORACLE_USER 2>/dev/null
if [ $? -eq 0 ]; then
	echo "User $ORACLE_USER found, proceeding..."
else
	echo "User $ORACLE_USER not found, aborting..."
	exit 1
fi

# Check necessary programs installed
which unzip
if [ $? -eq 0 ]; then
	echo "unzip is installed"
else
	echo "unzip not found, aborting..."
	exit 1
fi

which oracle-rdbms-server-12cR1-preinstall-verify
if [ $? -eq 0 ]; then
	echo "oracle-rdbms-server-12cR1-preinstall-verify is installed"
else
	echo "oracle-rdbms-server-12cR1-preinstall-verify not found, aborting..."
	exit 1
fi

which ntpd
if [ $? -eq 0 ]; then
	echo "ntpd is installed"
else
	echo "ntpd not found, aborting..."
	exit 1
fi


which ntpdate
if [ $? -eq 0 ]; then
	echo "ntpdate is installed"
else
	echo "ntpdate not found, aborting..."
	exit 1
fi

if [ -d "$ORACLE_INSTALLFILES_LOCATION" ]; then
	echo "$ORACLE_INSTALLFILES_LOCATION exists"
	if [ `ls -l $ORACLE_INSTALLFILES_LOCATION/linuxamd64_*of2.zip | wc -l` -eq 4 ]; then
		echo "Correct amount of ZIPs found, proceeding..."
	else
		echo "No or wrong installation ZIP files found."
		echo "Please make sure linuxamd64_*_database_1of2.zip, linuxamd64_*_database_2of2.zip, linuxamd64_*_grid_1of2.zip, linuxamd64_*_grid_2of2.zip are located in $ORACLE_INSTALLFILES_LOCATION"
		exit 1
	fi
else
	echo "$ORACLE_INSTALLFILES_LOCATION does not exist, aborting..."
	exit 1
fi


# Prepare filesystem

# Make sure the mountpoints exist
# This command will create them as folders if necessary
for mountpoint in ${ORACLE_MOUNTPOINTS[*]}
do
	mkdir -p $mountpoint
	chown -R ${ORACLE_USER}:oinstall $mountpoint
done

mkdir -p ${ORACLE_HOME}
mkdir -p ${GRID_HOME}
mkdir -p ${ORACLE_INVENTORY_LOCATION}
chown -R ${ORACLE_USER}:oinstall ${ORACLE_BASE}
chown -R ${ORACLE_USER}:oinstall ${GRID_BASE}
chown -R ${ORACLE_USER}:oinstall ${ORACLE_INVENTORY_LOCATION}

# Prepare groups and users
groupadd asmadmin
groupadd asmoper
groupadd dgdba
groupadd bckpdba
groupadd kmdba
usermod -a -G dba,asmoper,asmadmin,dgdba,bckpdba,kmdba ${ORACLE_USER}


# Modify NTPD
service ntpd stop
echo 'OPTIONS="-u ntp:ntp -x -p /var/run/ntpd.pid"' > /etc/sysconfig/ntpd
ntpdate pool.ntp.org
service ntpd start

# Modify /etc/hosts
# No longer needed with Kickstart file
cp /etc/hosts /etc/hosts.original
echo "127.0.0.1 `hostname -s` `hostname`" >> /etc/hosts
#cat /etc/hosts.original | awk '$1~"^127.0.0.1|^::1"{$2="'`hostname -s`' '`hostname`' "$2}1' OFS="\t" > /etc/hosts

# Modify /etc/fstab
mv /etc/fstab /etc/fstab.original
cat /etc/fstab.original | awk '$3~"^tmpfs$"{$4="size='$ORACLE_MEMORY_SIZE'"}1' OFS="\t" > /etc/fstab
mount -t tmpfs shmfs -o size=$ORACLE_MEMORY_SIZE /dev/shm

# Grid infrastructure
cd ${ORACLE_INSTALLFILES_LOCATION}
unzip ${ORACLE_INSTALLFILES_LOCATION}/linuxamd64_*_grid_1of2.zip
unzip ${ORACLE_INSTALLFILES_LOCATION}/linuxamd64_*_grid_2of2.zip
chown -R ${ORACLE_USER}:oinstall ${ORACLE_INSTALLFILES_LOCATION}/grid
#TODO: Check if everything worked as expected and only remove if no errors occured

# Installation of Grid Infrastructure
cd ${ORACLE_INSTALLFILES_LOCATION}/grid
echo "oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v12.1.0
ORACLE_HOSTNAME="`hostname`"
INVENTORY_LOCATION="${ORACLE_INVENTORY_LOCATION}"
SELECTED_LANGUAGES=en
oracle.install.option=CRS_SWONLY
ORACLE_BASE="${GRID_BASE}"
ORACLE_HOME="${GRID_HOME}"
oracle.install.asm.OSDBA=oinstall
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.installer.autoupdates.option=SKIP_UPDATES" > ${ORACLE_INSTALLFILES_LOCATION}/grid_install.rsp

echo "Now installing Grid Infrastructure. This may take a while..."
su ${ORACLE_USER} -c "cd ${ORACLE_INSTALLFILES_LOCATION}/grid; ./runInstaller -silent -waitForCompletion -responseFile ${ORACLE_INSTALLFILES_LOCATION}/grid_install.rsp"

# Register OraInventory
${ORACLE_INVENTORY_LOCATION}/orainstRoot.sh

# Configure GI (run this as root)
${GRID_HOME}/root.sh
${GRID_HOME}/perl/bin/perl -I${GRID_HOME}/perl/lib -I${GRID_HOME}/crs/install ${GRID_HOME}/crs/install/roothas.pl

echo "Finished installing Grid Infrastructure."

# Installation of Database Software

# Oracle database software
cd ${ORACLE_INSTALLFILES_LOCATION}
unzip ${ORACLE_INSTALLFILES_LOCATION}/linuxamd64_*_database_1of2.zip
unzip ${ORACLE_INSTALLFILES_LOCATION}/linuxamd64_*_database_2of2.zip
chown -R ${ORACLE_USER}:oinstall ${ORACLE_INSTALLFILES_LOCATION}/database
#TODO: Check if everything worked as expected and only remove if no errors occured


cd  ${ORACLE_INSTALLFILES_LOCATION}/database
rm -rf ${ORACLE_INSTALLFILES_LOCATION}/grid

echo "oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v12.1.0
oracle.install.option=INSTALL_DB_SWONLY
ORACLE_HOSTNAME="`hostname`"
UNIX_GROUP_NAME=oinstall
INVENTORY_LOCATION="${ORACLE_INVENTORY_LOCATION}"
SELECTED_LANGUAGES=en
ORACLE_HOME="${ORACLE_HOME}"
ORACLE_BASE="${ORACLE_BASE}"
oracle.install.db.InstallEdition=EE
oracle.install.db.DBA_GROUP=dba
oracle.install.db.BACKUPDBA_GROUP=bckpdba
oracle.install.db.DGDBA_GROUP=dgdba
oracle.install.db.KMDBA_GROUP=kmdba
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
DECLINE_SECURITY_UPDATES=true
oracle.installer.autoupdates.option=SKIP_UPDATES" > ${ORACLE_INSTALLFILES_LOCATION}/db_install.rsp

echo "Now installing Database software. This may take a while..."
su ${ORACLE_USER} -c "cd ${ORACLE_INSTALLFILES_LOCATION}/database; ./runInstaller -silent -waitForCompletion -responseFile ${ORACLE_INSTALLFILES_LOCATION}/db_install.rsp"

# Configure DB software
${ORACLE_HOME}/root.sh

# Update .bash_profile of oracle user
su ${ORACLE_USER} -c "echo '
#Oracle config
export ORACLE_HOME=${ORACLE_HOME}
export PATH=$PATH:\$ORACLE_HOME/bin' >> ~/.bash_profile"

# Create an Oracle listener in the GRID_HOME
echo "Adding listener..."

echo "[GENERAL]
RESPONSEFILE_VERSION=\"12.1\"
CREATE_TYPE=\"CUSTOM\"
SHOW_GUI=false
[oracle.net.ca]
INSTALLED_COMPONENTS={\"server\",\"net8\",\"javavm\"}
INSTALL_TYPE=\"\"typical\"\"
LISTENER_NUMBER=1
LISTENER_NAMES={\"LISTENER\"}
LISTENER_PROTOCOLS={\"TCP;1521\"}
LISTENER_START=\"\"LISTENER\"\"
NAMING_METHODS={\"TNSNAMES\",\"ONAMES\",\"HOSTNAME\"}
NSN_NUMBER=1
NSN_NAMES={\"EXTPROC_CONNECTION_DATA\"}
NSN_SERVICE={\"PLSExtProc\"}
NSN_PROTOCOLS={\"TCP;HOSTNAME;1521\"}" > ${ORACLE_INSTALLFILES_LOCATION}/netca.rsp

su ${ORACLE_USER} -c "${GRID_HOME}/bin/netca -silent -responseFile ${ORACLE_INSTALLFILES_LOCATION}/netca.rsp"
echo "Listener configured, now adding to CRS..."
su ${ORACLE_USER} -c "${GRID_HOME}/bin/srvctl add listener -endpoints TCP:1521 -oraclehome ${GRID_HOME}"
su ${ORACLE_USER} -c "${GRID_HOME}/bin/srvctl start listener"

# Cleanup
cd
rm -rf ${ORACLE_INSTALLFILES_LOCATION}/database

echo "Installation finished. Check the logfiles for errors"

