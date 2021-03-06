$NSXPath = "C:\Temp\VMware-NSX-Manager-6.1.2-2318232.ova"
$VMName = "MGMT-NSX"
$NSXIP = "10.144.99.19"
$NSXPass = "VMw@re123"

$vCenterIP = "10.144.99.15"
$vcuser = "root"
$vcpass = "VMw@re123"

$ovfconfig = @{
"vsm_cli_en_passwd_0" = "$NSXPass"
"NetworkMapping.VSMgmt" = "vDS-Main"
"vsm_gateway_0" = "10.144.99.1"
"vsm_cli_passwd_0" = "$NSXPass"
"vsm_isSSHEnabled" = "True"
"vsm_netmask_0" = "255.255.255.0"
"vsm_hostname" = "NSXManager.vtagion.local"
"vsm_ntp_0" = "0.pool.ntp.org"
"vsm_ip_0" = "$NSXIP"
"vsm_dns1_0" = "10.144.99.5"
"vsm_domain_0" = "vtagion.local"
}
Import-VApp -Source $NSXPath -OVFConfiguration $ovfconfig -Name $VMName -VMhost "10.144.99.11" -Datastore "SDT" -DiskStorageFormat "Thin"
Start-VM -VM $VMName -Confirm:$false 
$VM_View = get-vm $vmname | get-view
$toolsstatus = $VM_View.Summary.Guest.ToolsRunningStatus
write-host "waiting for $vmname to boot up" -foregroundcolor 'Yellow'
do {
Sleep -seconds 20
$VM_View = get-vm $vmname | get-view
$toolsstatus = $VM_View.Summary.Guest.ToolsRunningStatus
} Until ($toolsstatus -eq "guestToolsRunning")

Write-Host "$vmname has booted up successfully, Proceeding" -foregroundcolor 'Green'
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "admin",$NSXPass)))
$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
 $uri = "https://$NSXIP/api/2.0/vdn/controller"
do {
	Start-Sleep -Seconds 20
	$result = try { Invoke-WebRequest -Uri $uri -Headers $header -ContentType "application/xml"} catch { $_.Exception.Response}
} Until ($result.statusCode -eq "200")

Write-Host "Connected to $NSXIP successfully."	
# Connect NSX Manager to vCenter
Write-Host "Attempting to connect NSX Manager to vCenter" -ForegroundColor Yellow

#Certificate Policy
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    
    public class IDontCarePolicy : ICertificatePolicy {
        public IDontCarePolicy() {}
        public bool CheckValidationResult(
            ServicePoint sPoint, X509Certificate cert,
            WebRequest wRequest, int certProb) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = new-object IDontCarePolicy

$header = @{Authorization=("Basic {0}" -f $base64AuthInfo)}
$uri="https://$NSXIP/api/2.0/services/vcconfig"
$body="<vcInfo><ipAddress>$vCenterIP</ipAddress><userName>$vcuser</userName><password>$vcpass</password></vcInfo>"
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f "admin",$NSXPass)))

Invoke-RestMethod -Uri $uri -Method Put -Headers $header -ContentType "application/xml" -Body $body

Write-Host "Done!" -ForegroundColor Green


