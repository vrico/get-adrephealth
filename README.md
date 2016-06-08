# get-adrephealth

This is a very basic powershell script made for server 2012 R2 domain controllers. The tests include the following:

-Check primary DNS on DC(s)
-CHeck if AD services are running on DC(s)
-Basic Ping and DNS resolution tests
-Basic AD services responding tests
-Check for existence of SYSVOL and NETLOGON shares
-Check for AD replication failures
-Check Site Link Replication settings (makes a recommendation)
