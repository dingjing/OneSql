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
  
Database connection definition is passed to New-DbConnection as a hashtable with the following keys.

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

Frequently used connections can be pre-defined in DbDictionary.ps1, and passed to New-DbConnection by DbName.

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

Advanced example using Invoke-ParamCmd with Oracle's ArrayBind feature:

    $db = New-DbConnection -DBName myOracleInstance -Username myUseranem -Password myPassword
    Invoke-DbCmd -Connection $db -SQLText "truncate table ld_tst"
    
    $ins = @"
    insert into ld_tst(str_key, num_key, num_val) 
    values (:str_key, :num_key, dbms_random.value(1, 100))
    returning num_val into :num_val
    "@
    
    $p1 = New-Object Oracle.ManagedDataAccess.Client.OracleParameter(":str_key",
    	[Oracle.ManagedDataAccess.Client.OracleDbType]::Varchar2, 10)
    $p1.Direction = [System.Data.ParameterDirection]::Input
    $p1.Value = 1..10 | % {"A$_"}
    
    $p2 = New-Object Oracle.ManagedDataAccess.Client.OracleParameter(":num_key",
    	[Oracle.ManagedDataAccess.Client.OracleDbType]::Int32)
    $p2.Direction = [System.Data.ParameterDirection]::Input
    $p2.Value = 1..10
    
    $p3 = New-Object Oracle.ManagedDataAccess.Client.OracleParameter(":num_val",
    	[Oracle.ManagedDataAccess.Client.OracleDbType]::Int32)
    $p3.Direction = [System.Data.ParameterDirection]::Output
    
    Invoke-ParamCmd -Connection $db -SetupCmd {param($com)
    		$com.CommandText = $ins
    		$com.BindByName = $true
    		$com.ArrayBindCount = 10
    	} -Parameters $p1, $p2, $p3 `
    	-ProcessOutput {param($out) $out[2].Value | % {$_.Value}}
    	
    $db.Dispose()
