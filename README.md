#MS SQL Dump
This is a simple PowerShell script that lets you create db exports for MS SQL similar to the way you can do with `mysqldump` and `pg_dump`
##Usage
Change `$database` to your database name and run the script from PowerShell. It will create a file in current directory with same name as your database. This contains SQL script for schema, functions and views as well as `INSERT` statements for all of your data. The generated script will try to drop any existing database with same name, so if this database do not exist on the target server, you will receive an error message. 

##Here are a few examples of what you can do with it:
- create text based backup that can be stored in SCC
- examine changes in db with a simple diff tool
- transfer schema and data between production and dev without SQL server complaining about .bak file coming from another version of SQL server
