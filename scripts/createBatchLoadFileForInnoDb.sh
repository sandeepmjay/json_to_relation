#!/bin/bash

# Create a single file that combines all the MySQL LOAD LOCAL INFILE 
# directives from .sql files that were created by transforms
# of OpenEdX tracking log files. Those .sql files are generated 
# to be inputtable into MySQL in isolation. But if we were to 
# do this (i.e. mysql < foo.sql) then indexes would be rebuilt
# after each file was ingested. Very slow!
#
# Instead, the output of this script is a .sql file that 
# executes all LOADs of .csv files that the individual .sql
# files execute. All known InnoDB optimizations are enabled.
#
# The generated .sql script is written to stdout.
#
# Input: either an absolute path to a directory that 
# contains .sql files (usually mixed in with related
# .csv files), or a list of absolute paths to the .sql
# files.

usage="Usage: "`basename $0`" {<path/to/.sql-files>|<.sql-files-list}"

if [[ $# < 1  || $1 == "-h" || $1 == "--help" ]]
then
    echo $usage
    echo "Provide path to directory with .sql (and .csv) files that "
    echo "were created by transform, or provide .sql file list. Batch load SQL file is written to stdout."
    exit
fi

csvDirOrFirstFile=$1
# batchLoadFile=batchLoad_`$(date --utc +%FT%TZ)`.sql

echo "USE Edx;"
echo "DROP TABLE IF EXISTS EventIp;"
echo "CREATE TABLE IF NOT EXISTS EventIp ("
echo "    event_table_id varchar(40) NOT NULL PRIMARY KEY,"
echo "    event_ip varchar(16) NOT NULL DEFAULT ''"
echo ") ENGINE=InnoDB;"
echo "DROP TABLE IF EXISTS Account;"
echo "CREATE TABLE IF NOT EXISTS Account ("
echo "    account_id VARCHAR(40) NOT NULL PRIMARY KEY,"
echo "    screen_name TEXT NOT NULL,"
echo "    name TEXT NOT NULL,"
echo "    anon_screen_name TEXT NOT NULL,"
echo "    mailing_address TEXT NOT NULL,"
echo "    zipcode VARCHAR(255) NOT NULL,"
echo "    country VARCHAR(255) NOT NULL,"
echo "    gender VARCHAR(255) NOT NULL,"
echo "    year_of_birth TINYINT NOT NULL,"
echo "    level_of_education VARCHAR(255) NOT NULL,"
echo "    goals TEXT NOT NULL,"
echo "    honor_code TINYINT NOT NULL,"
echo "    terms_of_service TINYINT NOT NULL,"
echo "    course_id TEXT NOT NULL,"
echo "    enrollment_action VARCHAR(255) NOT NULL,"
echo "    email TEXT NOT NULL,"
echo "    receive_emails VARCHAR(255) NOT NULL"
echo "    ) ENGINE=InnoDB;"


echo "LOCK TABLES \`EdxTrackEvent\` WRITE, \`State\` WRITE, \`InputState\` WRITE, \`Answer\` WRITE, \`CorrectMap\` WRITE, \`LoadInfo\` WRITE, \`Account\` WRITE, \`EventIp\` WRITE, \`ABExperiment\` WRITE, \`OpenAssessment\` WRITE;"

echo "SET sql_log_bin=0;"
echo "SET autocommit=0;"
echo "SET unique_checks=0;"
echo "SET foreign_key_checks=0;"
echo "SET tx_isolation='READ-UNCOMMITTED';"

if [ -d $1 ]
then
    for fileName in ${csvDirOrFirstFile}/*.sql
    do
	echo "-- Loading data from "$(echo ${fileName} | sed -n 's/.*\(tracking.*\.gz\).*/\1/p')
	echo "$(sed -n '/LOAD DATA LOCAL INFILE/p' ${fileName});\n"
	echo "COMMIT;"
    done
else
    for fileName in $@
    do
	echo "-- Loading data from "$(echo ${fileName} | sed -n -e 's/.*\(tracking.*\.gz\).*/\1/p')
	echo "$(sed -n '/LOAD DATA LOCAL INFILE/p' ${fileName});\n"
	echo "COMMIT;"
    done
fi    

echo "UNLOCK TABLES;"
echo "REPLACE INTO EdxPrivate.Account (account_id,screen_name,name,anon_screen_name,mailing_address,zipcode,country,gender,year_of_birth,level_of_education,goals,honor_code,terms_of_service,course_id,enrollment_action,email,receive_emails) SELECT account_id,screen_name,name,anon_screen_name,mailing_address,zipcode,country,gender,year_of_birth,level_of_education,goals,honor_code,terms_of_service,course_id,enrollment_action,email,receive_emails FROM Edx.Account;"
echo "DROP TABLE Edx.Account;"
echo "REPLACE INTO EdxPrivate.EventIp (event_table_id,event_ip) SELECT event_table_id,event_ip FROM Edx.EventIp;"
echo "DROP TABLE Edx.EventIp;"
echo "COMMIT;"
echo "SET autocommit=1;"
echo "SET sql_log_bin=1;"
echo "SET unique_checks=1;"
echo "SET foreign_key_checks=1;"
echo "SET tx_isolation='REPEATABLE-READ';"

