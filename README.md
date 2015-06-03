# OneSql

OneSql is a PowerShell module providing universal query interface to all relational databases through .NET data providers or ODBC drivers. Supported RDBMS includes, but not limited to,
  * Oracle
  * SQL Server
  * DB2
  * MySQL
  * PostgreSQL

The module exposes 3 Cmdlets:
  * New-DbConnection: Create a database connection object.
  * Invoke-DbCmd: Execute a SQL statement using ExecuteReader().
  * Invoke-ParamCmd: Execute a parameterized SQL statement, usually insert/update/delete/merge, or stored procedure using ExecuteNonQuery(). For SQL or SP without parameters, call Invoke-DbCmd instead.
  
Database connections are defined in DbDictionary.ps1 as hashtable entries.

    $DbDictionary = @{
      MyOracleInstance = @{
        # Assembly name is optional. It is necessary only if it is not in GAC.
        # If provided, the assembly dll must be in the same or a sub folder.
        Assembly = "Oracle.ManagedDataAccess.dll";  
        
        # Required.
        ConnectionClass = "Oracle.ManagedDataAccess.Client.OracleConnection";
        
        # Required.
        DataSourceKey = "DATA SOURCE";
        
        # Required. TNS alias or connect descriptor.
        DataSourceValue = "";
        
        # Required.
        UserKey = "USER ID";
        
        # Required.
        PassKey = "PASSWORD";
        
        # Optional.
        #TrustedKey = "Integrated Security";
      };
      
      MySqlServerInstance = @{
        ConnectionClass = "System.Data.SqlClient.SqlConnection";
        DataSourceKey = "Server";
        DataSourceValue = "localhost\db";
        UserKey = "USER ID";
        PassKey = "PASSWORD";
        TrustedKey = "INTEGRATED SECURITY";
      }
    
      # Other DBName entries
    }

Simple example:

    $db = New-DbConnection -DBName MySQLServerInstance
    Invoke-DbCmd -Connection $db -SQLText "select * from myTable"
    $db.Dispose()

Advanced example:

    $oc = New-DbConnection -DBName MyOracleInstance -Username xxx -Password yyy
    $oc.Open()
    
    'select sysdate as a from dual', 'select level as a from dual connect by level <= 5' | Invoke-DbCmd -Connection $oc
    
    65..90 | % { "select chr($_) as c from dual"} |
        Invoke-DbCmd -Connection $oc -ProcessResult {param($dt) $dt.C}
    
    1..10 | % { 
        $set_sql = {param($com) $com.CommandText = "select sysdate + $_ as dt from dual"}
        $out_rslt = {param($dt) $dt.DT.AddMonths($_).ToString()}
        New-Object PSObject -Property @{SetupCmd = $set_sql; ProcessResult = $out_rslt}
    } | Invoke-DbCmd -Connection $oc
    
    $oc.Close()
    $oc.Dispose()
