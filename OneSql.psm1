#######################################################################################################################
# File:             OneSql.psm1                                                                                       #
# Author:           Jing Ding                                                                                         #
# Publisher:        OSU Wexner Medical Center                                                                         #
# Copyright:        © 2015 OSU Wexner Medical Center. All rights reserved.                                            #
#######################################################################################################################

Set-StrictMode -Version latest
if(Test-Path $PSScriptRoot\DbDictionary.ps1){
  . $PSScriptRoot\DbDictionary.ps1
}

Function Invoke-DbCmd {
<#
	.SYNOPSIS
		Execute a SQL statement.

	.DESCRIPTION
		Execute a SQL statement using ExecuteReader().

	.PARAMETER  Connection
		Database connection.

	.PARAMETER  SetupCmd
		A script block to setup a DbCommand object, which is passed in as a 
		parameter. Typical setup includes CommandText and Parameters. 

	.PARAMETER  SQLText
		An alternative way to setup DbCommand is to give the SQL text.

	.PARAMETER  ProcessResult
		A script block to process the query result, a DataTable object pass in
		as a parameter. If ProcessResult is not provided, the DataTable object
		is directly returned to the caller.

	.PARAMETER  Timeout
		The time in seconds to wait for the command to execute. The default is
		30 seconds. A value of 0 indicates no limit (an attempt to execute a 
		command will wait indefinitely).

#>

[CmdletBinding()]
[OutputType([System.Data.DataRow[]])]
param (
    [parameter(Mandatory=$true)]
    [System.Data.Common.DbConnection] $Connection,

    [parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true, ParameterSetName="Callback")]
    [ScriptBlock] $SetupCmd,

    [parameter(Mandatory=$true, ValueFromPipeline=$true, ParameterSetName="SQLText")]
    [string] $SQLText,

    [parameter(ValueFromPipelineByPropertyName=$true)]
    [ScriptBlock] $ProcessResult = $null,

    [int] $Timeout = 30
)

begin {
    $com = $Connection.CreateCommand()
    $com.CommandTimeout = [Math]::Max($Timeout, 0)
    $curr_state = $Connection.State
    if($curr_state -ne [System.Data.ConnectionState]::Open) {
        $Connection.Open()
    }
}

process {
    if($SQLText){
        $com.CommandText = $SQLText
    } else {
        & $SetupCmd $com
    }

    $rd = $com.ExecuteReader()
	if($rd.HasRows) {
	    $dt = New-Object System.Data.DataTable
	    $dt.Load($rd)
	} else {
		$dt = $null
	}
	$rd.Close()
    $rd.Dispose()

	if($dt){
	    if($ProcessResult) {
	        & $ProcessResult $dt
	    } else {
	        $dt
	    }
	}
}

end {
    if($curr_state -ne [System.Data.ConnectionState]::Open) {
        $Connection.Close()
    }
    $com.Dispose()
}
} # End Function Invoke-DbCmd

Function Invoke-ParamCmd {
<#
	.SYNOPSIS
		Execute a parameterized SQL statement or stored procedure.

	.DESCRIPTION
		Execute a parameterized SQL statement, usually insert/update/delete/merge,
		or stored procedure using ExecuteNonQuery(). For SQL or SP without
		parameters, call Invoke-DbCmd instead.

	.PARAMETER  Connection
		The database connection.

	.PARAMETER  SetupCmd
		A script block to setup a DbCommand object, which is passed in as a 
		parameter. Typical setup includes CommandText and Parameters. 

	.PARAMETER  SQLText
		The SQL statement or stored procedure to be executed.
		
	.PARAMETER Parameters
		The DbParameters used in the DML statement.

	.PARAMETER Values
		The value objects to fill the Parameters. Values are matched to their
		corresponding parameters by array positions. Values.Count can be less
    than or equal to Parameters.Count because of output parameters. If there
    are output parameters, put them at the end of array, or provide dummy
    values. Only one set of values can be passed via named parameter. Pipeline
    multiple sets of values.
    Alternatively, you can pass in a script block to set the parameter values.
    Return anything other than $null/$false/0 from the script block to skip
    ExecuteNonQuery().
    
  .PARAMETER SetValue
    A script block to set parameter values.

	.PARAMETER ProcessOutput
		A callback script to process output parameters if there is any.
		
	.Outputs
		Number of rows affected.
#>

[CmdletBinding()]
[OutputType([Int32])]
param (
  [parameter(Mandatory=$true)]
  [System.Data.Common.DbConnection] $Connection,

  [parameter(Mandatory=$true, ParameterSetName="SQLText")]
  [string] $SQLText,

  [parameter(Mandatory=$true, ParameterSetName="SQLCallback")]
  [ScriptBlock] $SetupCmd,

  [parameter(Mandatory=$true)]
  [System.Data.Common.DbParameter[]] $Parameters,

  [parameter(ValueFromPipeline=$true)]
  [Object[]] $Values = $null,
  
	[scriptblock] $ProcessOutput = $null
)

begin {
  $com = $Connection.CreateCommand()
	
	if($SQLText) {
  	$com.CommandText = $SQLText
	} else {
		& $SetupCmd $com
	}
	
  $com.Parameters.AddRange($Parameters)
	
	$curr_state = $Connection.State
    if($curr_state -ne [System.Data.ConnectionState]::Open) {
      $Connection.Open()
    }
}

process {
  $skip = $false
	if($Values) {
    if($Values[0] -is [ScriptBlock]){
      $skip = & $Values[0] $Parameters
    } else {
  	  0..($Values.Count - 1) | 
      ForEach { $Parameters[$_].Value = $Values[$_] }
	  }
  }
	
  if(!$skip) {
    $com.ExecuteNonQuery()
  }
  
	if($ProcessOutput) {
		& $ProcessOutput $Parameters
	}
}

end {
	$com.Parameters.Clear()
    if($curr_state -ne [System.Data.ConnectionState]::Open) {
      $Connection.Close()
    }
    $com.Dispose()
}
}

Function New-DbConnection {
<#
	.SYNOPSIS
		Create a database connection object.

	.DESCRIPTION
		Create a database connection object.

	.PARAMETER  DBDefinition
		Connection detail defined as a hashtable.

	.PARAMETER  DBName
		Connection name defined in DbDictionary.ps1.

	.PARAMETER  Credential
		A PSCredential object containing username and password.
		
	.PARAMETER Username
		Username. Default value: $env:USERNAME.
		
	.PARAMETER Password
		Password. If neither Credential or Password is provided, trusted
		connection is assumed.
		
	.PARAMETER OtherSettings
		Additional key-value pairs inserted into the connection string.

	.OUTPUTS
		System.Data.Common.DbConnection

  .NOTES
    DBDefinition hashtable has the following keys.
      # Assembly name is optional. It is necessary only if it is not in GAC.
      # It can be specified with absolute, relative or no path.
      # If without path, the assembly dll must be in the same or a sub folder.
      Assembly = "Oracle.ManagedDataAccess.dll";  
      
      # Required.
      ConnectionClass = "Oracle.ManagedDataAccess.Client.OracleConnection";
      
      # Required.
      DataSourceKey = "DATA SOURCE";
      
      # Required. TNS alias or connect descriptor.
      DataSourceValue = "";
      
      # Optional.
      UserKey = "USER ID";
      
      # Optional.
      PassKey = "PASSWORD";
      
      # Optional.
      TrustedKey = "Integrated Security";

    DBNames are defined in DbDictionary.ps1 with the following format.
    $DbDictionary = @{
      MyOracleInstance = @{
        Assembly = "Oracle.ManagedDataAccess.dll";
        ConnectionClass = "Oracle.ManagedDataAccess.Client.OracleConnection";
        DataSourceKey = "DATA SOURCE";
        DataSourceValue = "MyOraTNS";
        UserKey = "USER ID";
        PassKey = "PASSWORD";
      };
      
      MySqlServerInstance = @{
        ConnectionClass = "System.Data.SqlClient.SqlConnection";
        DataSourceKey = "Server";
        DataSourceValue = "localhost\db";
        UserKey = "USER ID";
        PassKey = "PASSWORD";
        TrustedKey = "INTEGRATED SECURITY";
      }
    }    
#>

[CmdletBinding(DefaultParameterSetName="Name+Credential")]
[OutputType([System.Data.Common.DbConnection])]
param (
  [parameter(Mandatory=$true,
             ParameterSetName="Definition+Credential",
             ValueFromPipeline=$true,
             ValueFromPipelineByPropertyName=$true)]
  [parameter(Mandatory=$true,
             ParameterSetName="Definition+Password",
             ValueFromPipeline=$true,
             ValueFromPipelineByPropertyName=$true)]
  [ValidateScript({
    $_.ContainsKey('ConnectionClass') -and
    $_.ContainsKey('DataSourceKey') -and
    $_.ContainsKey('DataSourceValue')
  })]
  [hashtable] $DbDefinition,
  
  [parameter(Mandatory=$true,
             ParameterSetName="Name+Credential",
             ValueFromPipeline=$true,
             ValueFromPipelineByPropertyName=$true)]
  [parameter(Mandatory=$true,
             ParameterSetName="Name+Password",
             ValueFromPipeline=$true,
             ValueFromPipelineByPropertyName=$true)]
  [ValidateScript({$DbDictionary.ContainsKey($_)})]
  [Alias("DSN")]
  [string] $DBName,

  [parameter(ParameterSetName="Definition+Credential",
             ValueFromPipelineByPropertyName=$true)]
  [parameter(ParameterSetName="Name+Credential",
             ValueFromPipelineByPropertyName=$true)]
  [PSCredential] $Credential,

  [parameter(ParameterSetName="Definition+Password",
             ValueFromPipelineByPropertyName=$true)]
  [parameter(ParameterSetName="Name+Password",
             ValueFromPipelineByPropertyName=$true)]
  [string] $Username = $env:USERNAME,

  [parameter(Mandatory=$true,
             ParameterSetName="Definition+Password",
             ValueFromPipelineByPropertyName=$true)]
  [parameter(Mandatory=$true,
             ParameterSetName="Name+Password",
             ValueFromPipelineByPropertyName=$true)]
  [string] $Password,

  [parameter(ValueFromPipelineByPropertyName=$true)]
  [hashtable] $OtherSettings = $null
)

process {
  if($DbDefinition){
    $db = $DbDefinition
  } else {
    $db = $DbDictionary[$DBName]
  }

#region Check if connection class exist. If not, load assembly.
  if(!($db.ConnectionClass -as [Type])) {
    $assmLoaded = $false
    if($db.Assembly) {
      if([System.IO.Path]::GetDirectoryName($db.Assembly)){
        if([System.IO.Path]::IsPathRooted($db.Assembly)){
          $assmPath = $db.Assembly -as [System.IO.FileInfo]
        } else {
          $assmPath = [System.IO.Path]::Combine($PSScriptRoot, $db.Assembly) -as [System.IO.FileInfo]
        }
      } else {
        $assmPath = Get-ChildItem -Path $PSScriptRoot -Recurse -Filter $db.Assembly
      }
      
      if($assmPath) {
        try {
          Add-Type -Path @($assmPath)[0].FullName
          $assmLoaded = $true
        } catch {}
      }
    }

    if(!$assmLoaded) {
      throw "Cannot find connection class $($db.ConnectionClass) or load its assembly."
    }
  }
#endregion Connection class check.

#region Build connection string.
  $csb = New-Object -TypeName "$($db.ConnectionClass)StringBuilder"
  if($OtherSettings){
    $OtherSettings.Keys | ForEach-Object {
      $csb[$_.ToUpper()] = $OtherSettings[$_]
    }
  }

  $csb[$db.DataSourceKey] = $db.DataSourceValue

  if($Credential) {
    $csb[$db.UserKey] = $Credential.UserName.ToUpper()
    $csb[$db.PassKey] = $Credential.GetNetworkCredential().Password
  } elseif($Password) {
    $csb[$db.UserKey] = $Username
    $csb[$db.PassKey] = $Password
  } elseif($db.ContainsKey("TrustedKey")) {
    $csb[$db.TrustedKey] = "true"
  } else {
    $csb["TRUSTED_CONNECTION"] = "true"
  }
#endregion Build connection string.

  New-Object -TypeName $db.ConnectionClass -ArgumentList $csb.ConnectionString
 
}

}

Export-ModuleMember -Function "Invoke-DbCmd", "Invoke-ParamCmd", "New-DbConnection"