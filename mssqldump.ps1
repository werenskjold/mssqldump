################################################################################################################################
#
# Script Name : SmoDb
# Version     : 1.0
# Author      : Øyvind Wærenskjold
# Purpose     :	This script generates a sql dump file that drops and recreates database with all content
#
# Usage       : Set variables at the top of the script then execute.
#
# Note        : Only tested on SQL Server 2008r2 and SQL Server 2014
#                 
################################################################################################################################
$lf = "`r`n"
$go = "GO" + $lf;

$server 			= "localhost"
$database 			= "dbname"
$currentDir         = (Get-Item -Path ".\" -Verbose).FullName
$filename 			=  $currentDir  + "\" + $database + ".sql"
$schema 			= "dbo"


[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SMO") | out-null

$srv 		= New-Object "Microsoft.SqlServer.Management.SMO.Server" $server
$db 		= New-Object ("Microsoft.SqlServer.Management.SMO.Database")
$tbl 		= New-Object ("Microsoft.SqlServer.Management.SMO.Table")
$scripter 	= New-Object ("Microsoft.SqlServer.Management.SMO.Scripter") ($server)

# Get the database and table objects
$db = $srv.Databases[$database]

$tbl		 	= $db.tables | Where-object { $_.schema -eq $schema  -and -not $_.IsSystemObject } 
$storedProcs	= $db.StoredProcedures | Where-object { $_.schema -eq $schema -and -not $_.IsSystemObject } 
$views 			= $db.Views | Where-object { $_.schema -eq $schema } 
$udfs		 	= $db.UserDefinedFunctions | Where-object { $_.schema -eq $schema -and -not $_.IsSystemObject } 
$catlog			= $db.FullTextCatalogs
$udtts		 	= $db.UserDefinedTableTypes | Where-object { $_.schema -eq $schema } 
	
# Set scripter options to ensure only data is scripted
$scripter.Options.ScriptSchema 	= $true;

$scripter.Options.IncludeHeaders 		= $false;
$scripter.Options.NoCommandTerminator 	= $false;
$scripter.Options.AllowSystemObjects 	= $false
$scripter.Options.Permissions 			= $true
$scripter.Options.SchemaQualify 		= $true
$scripter.Options.AnsiFile 				= $false


$scripter.Options.SchemaQualifyForeignKeysReferences = $true
$scripter.Options.DriAll 				= $false
$scripter.Options.Indexes 				= $true
$scripter.Options.NonClusteredIndexes 	= $true
$scripter.Options.ClusteredIndexes 		= $true
$scripter.Options.FullTextIndexes 		= $true
$scripter.Options.EnforceScriptingOptions = $true


function ScriptObjects($objects) {
	
	foreach ($o in $objects) { 
	
		if ($o -ne $null) {
			
			$schemaPrefix = ""
			
			if ($o.Schema -ne $null -and $o.Schema -ne "") {
				$schemaPrefix = $o.Schema + "."
			}
			Write-Host "Writing "  $schemaPrefix$o 

			$content += $scripter.EnumScript($o) 
		}
	}
	return $content
}


function ScriptObjectsInsertGo($objects){
	$content = ScriptObjects($objects)
	$content = $content | ForEach-Object {$_ -replace "SET ANSI_NULLS ON",  ("GO " + $lf + "SET ANSI_NULLS ON") } | ForEach-Object {$_ -replace "CREATE",  ("GO " + $lf + "CREATE") }
	return $content
}



# Output the scripts

#script database 
Write-Host "Writing " $db "to " $filename
"EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'"+ $db.Name +"'
GO
USE [master]
GO
ALTER DATABASE "+ $db +" SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
GO
USE [master]
GO
DROP DATABASE  "+ $db +"
GO" > $filename
$scripter.script($db) + $go >> $filename

#use database
"USE " +  $db + "
 GO" >>  $filename



#disable all constraints
"EXEC sp_msforeachtable ""ALTER TABLE ? NOCHECK CONSTRAINT all"" 
"  >> $filename 

#script schema and data
$scripter.Options.ScriptData			= $true;
ScriptObjects $tbl >> $filename
$go >> $filename

# enable all constraints
"exec sp_msforeachtable @command1=""print '?'"", @command2=""ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all"" 
" >> $filename

#script views
ScriptObjectsInsertGo $views >> $filename


#script stored procedures
ScriptObjectsInsertGo $storedProcs >> $filename

#script stored udfs
ScriptObjectsInsertGo $udfs >> $filename

#script stored catlog
ScriptObjectsInsertGo $catlog >> $filename

#script stored udtts
ScriptObjectsInsertGo $udtts >> $filename

#convert content to UTF-8
$filecontent = Get-Content $filename
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
[System.IO.File]::WriteAllLines($filename, $filecontent, $Utf8NoBomEncoding)


Write-Host "Finished at" (Get-Date)


