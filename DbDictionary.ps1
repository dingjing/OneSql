$DbDictionary = @{
  MyOracleDB = @{
    Assembly = "Oracle.ManagedDataAccess.dll";
    ConnectionClass = "Oracle.ManagedDataAccess.Client.OracleConnection";
    DataSourceKey = "DATA SOURCE";
    DataSourceValue = "(DESCRIPTION=(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=ora.mycompany.com)(PORT=1521)))(CONNECT_DATA=(SID=x123)))";
    UserKey = "USER ID";
    PassKey = "PASSWORD"
  };

  SERVICE_NOW = @{
    ConnectionClass = "System.Data.Odbc.OdbcConnection";
    DataSourceKey = "DSN";
    DataSourceValue = "ServiceNow";
    UserKey = "UID";
    PassKey = "PWD";
  };

  MySqlServer = @{
    ConnectionClass = "System.Data.SqlClient.SqlConnection";
    DataSourceKey = "Server";
    DataSourceValue = "Localhost\EC";
    UserKey = "USER ID";
    PassKey = "PASSWORD";
    TrustedKey = "INTEGRATED SECURITY";
  }
}