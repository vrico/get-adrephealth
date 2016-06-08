# get-adrephealth

This is a very basic powershell script made for server 2012 R2 domain controllers. 

Where should I run the script?

Run the script on a domain controller that has IP connecitivty to all other domain controllers.


                                  
The following tests are run:

-Check primary DNS on DC(s)

-Check if AD services are running on DC(s)

-Basic Ping and DNS resolution tests

-Basic AD services responding tests

-Check for existence of SYSVOL and NETLOGON shares

-Check for AD replication failures

-Check Site Link Replication settings (makes a recommendation)
