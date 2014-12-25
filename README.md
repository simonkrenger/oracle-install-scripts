# Simons Oracle Installation Scripts
This repository contains scripts to automate an Oracle database installation. The scripts are self-contained and allow you to perform installation and configuration of a new Oracle database on a vanilla Oracle Linux distribution. The scripts install the software according to the Optimal Flexible Architecture (OFA).

I mainly use these scripts for my own personal database setups. Currently, the following scripts are available (for detailed description, see below):
* pandora-ks.cfg (Kickstart file)
* install_db_software.sh
* mkoradb.sh

## Guide
### Prerequisites
Before starting, make sure you have the following software available:
* An ISO for Oracle Linux 6 (for example V52218-01.iso)
* Oracle Database 12c Release 1 archives ([linuxamd64_12c_database_1of2.zip, linuxamd64_12c_database_2of2.zip](http://www.oracle.com/technetwork/database/enterprise-edition/downloads/database12c-linux-download-2240591.html))
* Oracle Database 12c Release 1 Grid Infrastructure archives ([linuxamd64_12c_grid_1of2.zip, linuxamd64_12c_grid_2of2.zip](http://www.oracle.com/technetwork/database/en    terprise-edition/downloads/database12c-linux-download-2240591.html))

### How-to
1. Create a new virtual machine with 1 disk and at least 1GB of RAM
2. Start the VM and at the initial prompt, press TAB. Then, append the kick start parameter:

	`ks=https://raw.github.com/simonkrenger/oracle-install-scripts/master/oracle-linux-kickstart/pandora-ks.cfg`

3. Your VM will now be automatically set up.
4. After the installation finished, copy the 4 install ZIP files (linuxamd64_12c_database_1of2.zip, linuxamd64_12c_database_2of2.zip, linuxamd64_12c_grid_1of2.zip, linuxamd64_12c_grid_2of2.zip) to "/home/oracle/".
5. As "root", execute "/root/install_db_software.sh"
6. Then, as "oracle", execute "/home/oracle/mkoradb.sh"
7. Enjoy your newly installed Oracle database

## Script Description
### pandora-ks.cfg
This is a kickstart file to automatically set up an Oracle Linux virtual machine with all prerequisites to install Oracle Database.

### install_db_software.sh
In its current form, this script allows you to automatically install the Oracle 12c Grid Infrastructure (GI) and Oracle 12c Database Software on a Linux server (plus there are scripts for Oracle 11g R2). For prerequisites, see the header of the script itself. Execute this script as the `root` user. There are a few variables that you can tweak:

Variable | Description
--- | ---
ORACLE_USER | User that will perform the Oracle installation and be the owner of the Oracle software directory
ORACLE_HOME | Installation directory (defaults to OFA)
ORACLE_BASE | Oracle software base directory (defaults to OFA)
ORACLE_BASE_MOUNTS | Mountpoints that are used for the installation (defaults to OFA)
ORACLE_INVENTORY_LOCATION | Location of the Oracle software inventory
ORACLE_INSTALLFILES_LOCATION | Location of the Oracle software ZIP files
GRID_USER | User that will own the GI software directory
GRID_BASE | GI base directory
GRID_HOME | GI Installation directory
ORACLE_MEMORY_SIZE | Size of the shared memory pool (shmfs)

### mkoradb.sh
This script allows you to create a new Oracle 12c database or Oracle 11g database on a server where the Oracle software was already installed. The script will create the necessary folders (according to OFA), prepare all necessary files for database configuration and will then create a new database. Execute this script as the `oracle` user. There are a few variables that you can tweak:

Variable | Description
--- | ---
ORACLE_SID | Name of the database you want to create (will be the name of the instance as well as the DB_NAME)
ORACLE_HOME | Installation directory (defaults to OFA)
ORACLE_BASE | Oracle software base directory (defaults to OFA)
MY_ORACLE_PASSWD | Password for the SYS and SYSTEM user
MY_MEMORY_TARGET | Value for MEMORY_TARGET
MY_REDO_SIZE | Size of a single redo file
MY_CHARSET | Character set to use for the database (default AL32UTF8)
MY_NCHARSET | National character set to use for the database (default AL16UTF16)

## Work in progress
These scripts are far from perfect, I just like to keep them handy for my own reference. Use with caution and at your own risk.
