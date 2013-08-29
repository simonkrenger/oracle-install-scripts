# Simons Oracle Installation Scripts
This repository contains scripts to automate an Oracle database installation. The scripts are self-contained and allow you to perform installation and configuration of a new Oracle database on a vanilla Linux distribution. The scripts install the software according to the Optimal Flexible Architecture (OFA).

I mainly use these scripts for my own personal database setups. Currently, the following scripts are available (for detailed description, see below):
* install_db_software.sh
* mkoradb.sh

## Description
### install_db_software.sh
In its current form, this script allows you to automatically install the Oracle 12c Grid Infrastructure (GI) and Oracle 12c Database Software on a Linux server. For prerequisites, see the header of the script itself. Execute this script as the `root` user. There are a few variables that you can tweak:
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
This script allows you to create a new Oracle 12c database on a server where the Oracle software was already installed. The script will create the necessary folders (according to OFA), prepare all necessary files for database configuration and will then create a new database. Execute this script as the `oracle` user. There are a few variables that you can tweak:
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
These scripts are far from perfect, I just like to keep them handy for my own reference. Use with caution.
