

#get domain controllers
$dcpath = Get-ADDomain | select -expandproperty domaincontrollerscontainer
$domaincontrollers = get-adcomputer -SearchBase $dcpath -filter * | select -ExpandProperty name



#foreach ($dc in $domaincontrollers) {
#Get-ADDomainController -server $dc
#}

#collection for holding all test results
$testresults = @()

#region primary dns server check
#making sure the primary dns server is not the local dc

foreach ($dc in $domaincontrollers) {
        $dccount = $domaincontrollers.Count
    if ($dccount -gt 1) {
      $primarydns =  invoke-command -computername $dc -scriptblock {Get-NetIPConfiguration | select -ExpandProperty DNSServer |  ? addressfamily -eq "2" | select -ExpandProperty  serveraddresses}
      if ($primarydns.count -eq 1) {
         if ($primarydns -eq "127.0.0.1") {
             write-host -ForegroundColor red "There are multiple domain controllers in this environment but the primary DNS server for $dc is 127.0.0.1"
        }#if 
      }#if
        if ($primarydns[0]-eq "127.0.0.1") {
             write-host -ForegroundColor red "There are multiple domain controllers in this environment but the primary DNS server for $dc is 127.0.0.1"
        }#if

    }#if
}#foreach
#endregion

#region check dns services

    foreach ($dc in $domaincontrollers) {
        $dnsserver = get-service -ComputerName $dc -name DNS | select -ExpandProperty status
        if ($dnsserver -eq "Running") {
            write-host -ForegroundColor cyan "DNS Server is running on $dc"
        }
        elseif ($dnsserver -like "*stop*") {
            write-host -ForegroundColor red "DNS Server is NOT Running on $dc !"
        }

        $dnsclient = get-service -computername $dc -name Dnscache | select -ExpandProperty status
        if ($dnsclient -eq "Running") {
            write-host -ForegroundColor cyan "DNS client service is running on $dc"
        }
        elseif ($dnsclient -like "*stop*") {
            write-host -ForegroundColor Red "DNS client is NOT Running on $dc !"
        }

            $ntds = get-service -computername $dc -name ntds | select -ExpandProperty status
        if ($ntds -eq "Running") {
          write-host -ForegroundColor cyan "NTDS service is running on $dc"
        }
        elseif ($ntds -like "*stop*") {
         write-host -ForegroundColor Red "NTDS service is NOT Running on $dc !"
        }

            $netlogon = get-service -computername $dc -name netlogon | select -ExpandProperty status
        if ($netlogon -eq "Running") {
            write-host -ForegroundColor cyan "NETLOGON service is running on $dc"
        }
        elseif ($netlogon -like "*stop*") {
         write-host -ForegroundColor Red "NETLOGON service is NOT Running on $dc !"
        }

    }#foreach

#endregion 

#region ping and dns resolution, basic test

foreach ($dc in $domaincontrollers) {

    try {
     Test-Connection -ComputerName $dc -Count 2 -ErrorAction Stop | Out-Null
     Write-Host -ForegroundColor cyan "Basic ping and DNS resolution test passed for $dc"
    }#try
    catch {
        $errormessage = $_.exception
        if ($errormessage -like "*hostname*") {
            write-host -ForegroundColor red "DNS resolution failed, check network settings"
        }#if 
        elseif ($errormessage -like "*due to lack of resources*") {
            write-host -foregroundcolor red "Basic ping failed, check network settings."
        }#if
    }# catch
}#foreach

#endregion

#region port tests
$gcport = '3268'
$kerberosport = '88'
$kpasswordport = '464'
$ldapport = '389'

$gctesttext = "Global catalog test"
$kerberostesttext = "Kerberos test"
$kpasswordtesttext = "Kpassword test"
$ldaptesttext = "LDAP test"

$coltests = @()

$gctest = new-object system.object
$gctest | add-member -type noteproperty -name testname -value $gctesttext
$gctest | Add-Member -Type NoteProperty -Name port -Value $gcport
$coltests += $gctest

$kerberostest = new-object system.object
$kerberostest | Add-Member -type NoteProperty -name testname -Value $kerberostesttext
$kerberostest | Add-Member -Type NoteProperty -name port -Value $kerberosport
$coltests += $kerberostest

$kpasswordtest = new-object system.object
$kpasswordtest | Add-Member -type NoteProperty -name testname -Value $kpasswordtesttext
$kpasswordtest | Add-Member -Type NoteProperty -name port -Value $kpasswordport
$coltests += $kpasswordtest

$ldaptest = new-object system.object
$ldaptest | add-member -type noteproperty -name testname -value $ldaptesttext
$ldaptest | Add-Member -Type NoteProperty -Name port -Value $ldapport
$coltests += $ldaptest



foreach ($test in $coltests) {
    foreach ($dc in $domaincontrollers) {
            try {
                $currenttest = Test-NetConnection -ComputerName $dc -Port $test.port -ErrorAction Stop | select -ExpandProperty tcptestsucceeded
            }#try 
             catch { 
                Write-Host -ForegroundColor red "Something is wrong with the local network settings, could not run test"
             }#catch


        if ($currenttest -eq $false) {
            Write-Host -ForegroundColor Red "The $($test.testname) test failed for $dc" 
        }#if
            elseif ($currenttest) {
                Write-Host -ForegroundColor cyan "The $($test.testname) passed for $dc"
            }#elseif
    }#foreach
}#foreach
#endregion  

#region check for shares
foreach ($dc in $domaincontrollers) {
try {
Invoke-Command -ComputerName $dc -ScriptBlock {get-smbshare netlogon} -ErrorAction stop | Out-Null
write-host -ForegroundColor Cyan "NETLOGON share exists on $dc"
}
catch {

write-host -ForegroundColor Red "Unable to find the NETLOGON share on $dc"
}

try {
Invoke-Command -ComputerName $dc -ScriptBlock {get-smbshare sysvol} -ErrorAction stop | out-null
write-host -ForegroundColor Cyan "SYSVOL share exists on $dc"
}
catch {
write-host -ForegroundColor red "Unable to find the SYSVOL share on $dc"
}
}#foreach
#endregion

#region ad partition replication
    $adrepresults = Get-ADReplicationPartnerMetadata -Target * -Partition * | select server,partition,partner,consecutivereplicationfailures,lastreplicationsuccess
    #$adrepresultsnumbers = $adrepresults | select  -ExpandProperty consecutivereplicationfailures
    foreach ($singlerepresult in $adrepresults) {
        if ($number.consecutivereplicationfailures -gt 1) {
            write-host -ForegroundColor Red "There has been at least 1 consecutive replication failure in AD on $($singlerepresult.server) for the partition $($singlerepresult.partition)"
        }#if
         elseif ($singlerepresult.consecutivereplicationfailures -eq 0) {
         write-host -ForegroundColor Cyan "There was no replication failures on $($singlerepresult.server) for the partition $($singlerepresult.partition)"
        }#elseif
    }#foreach
#endregion

#region check ad site replication time
$sitereptimeall = get-adreplicationsitelink -filter *
foreach ($sitereptime in $sitereptimeall) {
    if ($sitereptime.replicationfrequencyinminutes -ge 30) {
        write-host -ForegroundColor red "The site replication link $($sitereptime.name) has a replication time greater than 30 minutes"
    }#if
     elseif ($sitereptime.replicationfrequencyinminutes -le 29) {
        write-host -ForegroundColor Cyan "The site replication link $($sitereptime.name) has a replication time of atleast 30 minutes"
     }#elseif
}#foreach
#endregion 


#region test secure channel with the PDC
$pdc = get-addomain | select -ExpandProperty pdcemulator
$pdcsplit = $pdc.split('.')
$pdcfinal = $pdcsplit[0]
foreach ($dc in $domaincontrollers) {
   if ($dc -ne $pdcfinal) {
        Invoke-Command -ComputerName $dc -ScriptBlock { Test-ComputerSecureChannel -Server $args[0] -Verbose } -ArgumentList $pdcfinal
   }#if
}#foreach
#endregion 