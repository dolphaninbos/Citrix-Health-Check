Import-Module credentialmanager
asnp citrix*
$creds = Get-XDCredentials -ProfileName CloudAdmin
Get-XDAuthentication -ProfileName CloudAdmin
$nsip="ENTER IP ADDRESS HERE FOR ADC"
$KMS_SERVER ="servername"

#   StoreFront Check directly against ADC
$path1 = Resolve-Path "ENTER PATH HERE\nitro.dll" 
[System.Reflection.Assembly]::LoadFile($path1) |out-null
$path2 = Resolve-Path "ENTER PATH HERE\Newtonsoft.Json.dll"
[System.Reflection.Assembly]::LoadFile($path2) |out-null
$BodyChunk3 = $null

#Pull creds from credential manager
#PUT CREDS INTO CRED MANAGER - New-StoredCredential -Comment 'Citrix ADC' -Credentials $(Get-Credential) -Target 'Citrix ADC'
$temppass = get-storedcredential -Target 'Citrix ADC'
$pass=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto( [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($temppass.Password))

$nitrosession = new-object com.citrix.netscaler.nitro.service.nitro_service($nsip,"http")
# creating a session with Netscaler
        
        #Login to Netscaler
        $session = $nitrosession.login($temppass.username,$pass)
        #Get status of virtual servers
        $result = [com.citrix.netscaler.nitro.resource.config.lb.lbvserver]::get($nitrosession, "lb_StoreFront");
            $BodyChunk3 +="STOREFRONT SERVICES AS PER ADC:"
            $BodyChunk3 +="<br>Current State: "+$result.curstate
            $BodyChunk3 +="<br>Effective State: "+$result.effectivestate
            $BodyChunk3 +="<br>Health of ALL StoreFronts: "+$result.health+"%"
            $BodyChunk3 +="<br>Total StoreFronts: "+$result.TotalServices
            $BodyChunk3 +="<br>Active StoreFronts: "+$result.ActiveServices
            $BodyChunk3 +="<br><br>Get ssl certkey"
        $result = [com.citrix.netscaler.nitro.resource.config.ssl.sslcertkey]::get($nitrosession)
        for ($i = 0; $i -lt $result.Length; $i++)
        {
            $BodyChunk3 +="<br>sslcert name: "+$result[$i].cert+".... EXPIRES IN (x) DAYS: "+$result[$i].daystoexpiration+".... Linked to->"+$result[$i].linkcertkeyname
        }
        #logging out the Session
        $session = $nitrosession.logout()

#   RDS License check
$fileName = (Invoke-WmiMethod Win32_TSLicenseReport -Name GenerateReportEx -ComputerName $KMS_SERVER).FileName
$summaryEntries = (Get-WmiObject Win32_TSLicenseReport -ComputerName $KMS_SERVER|Where-Object FileName -eq $fileName).FetchReportSummaryEntries(0,0).ReportSummaryEntries
if ($summaryEntries.IssuedLicenses -ge ($summaryEntries.InstalledLicenses -10))
{
$RDSLiceCheck = "Installed RDS Licenses:" + $summaryEntries.InstalledLicenses +'<br><h1 style="color:Tomato;">Issued RDS Licenses:' + $summaryEntries.IssuedLicenses + " </h1>"
}
ELSE
{
$RDSLiceCheck = "Installed RDS Licenses:" + $summaryEntries.InstalledLicenses +"<br>Issued RDS Licenses: " + $summaryEntries.IssuedLicenses 
}

#   Machine Detail calculation
$BRCat = Get-BrokerCatalog
$BodyChunk1 = $NULL
$BodyChunk2 = $NULL
foreach ($item in $BRCat){
$BodyChunk1 += "<tr><td>" + $item.name + "</td><td>" + $item.usedcount + "</td><td>" + $item.zonehealthy + "</td></tr>" 
}
$BRMach = get-brokermachine
foreach ($item in $BRMach) 
{
if ($item.MaintenanceModeReason -eq "None") {$MainMode = "<td>NO"} else {$MainMode = "<td bgcolor=#F9FF33 >YES"}
if ($item.poweractionpending -eq $False) {$Power = "<td>NO"} else {$Power = "<td bgcolor=#F9FF33 >YES"}
if ($item.PowerState  -eq "On") {$Powerstate = "<td>ON"} else {$Powerstate = "<td bgcolor=#F9FF33 >OFF"}
if ($item.HypervisorConnectionName -eq "Amazon EC2 East 1") {$BodyChunk2 += "<tr><td>" + $item.Hostedmachinename + "</td>" + $MainMode + "</td>" + $Power + "</td><td>" + $item.Sessioncount + "</td>" + $Powerstate + "</td><td>AWS</td></tr>"}
if ($item.HypervisorConnectionName -ne "Amazon EC2 East 1") {$BodyChunk2 += "<tr><td>" + $item.Hostedmachinename + "</td>" + $MainMode + "</td>" + $Power + "</td><td>" + $item.Sessioncount + "</td>" + $Powerstate + "</td><td>" + $item.hostingservername + "</td></tr>"}
}
#   SESSION CALCULATION
$history = @()
$spin = -24
$TopSessionCount = 0
Do{
$when =(get-date  -Hour 0 -Minute 00).AddHours($spin)
$hist =Get-BrokerConnectionLog -Filter {(BrokeringTime -lt $when) -and (EndTime -gt $when)}
$history +=$hist.count
if ($hist.count -gt $TopSessionCount){$TopSessionCount = $hist.count}
$spin+=1
}while($spin -le 0)

#Chart setup
[void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[Void][Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms.Datavisualization")
$chart = New-Object System.Windows.Forms.Datavisualization.charting.chart
$chart.width = 1000
$chart.Height = 600
$chart.Top = 40
$chart.Left = 30
$chartArea = New-Object System.windows.Forms.Datavisualization.charting.chartArea
$chart.chartAreas.Add($chartArea)
$date = get-date ((get-date ).AddDays(-1)) -Format "MM_dd_yy"
$ChartTitle = "Citrix Session Count for " + $date
[Void]$chart.Titles.Add($ChartTitle)
$chartArea.AxisX.Title = "Time"
$chartArea.AxisY.Title = "Sessions"
$chart.Titles[0].Font = "Arial,13pt"
$chartArea.AxisX.TitleFont = "Arial,13pt"
$chartArea.AxisY.TitleFont = "Arial,13pt"
$chartArea.AxisY.Interval = 10
$chartArea.AxisX.Interval = 1
#Legend
$legend = New-Object system.Windows.Forms.DataVisualization.Charting.Legend
$legend.name = "Legend"
$chart.Legends.Add($legend)

#Populate data series into x,y coordinates
$x = $Null
$y = $Null
$x = @()
$y=@()
$count = 0
foreach ( $i in $history )
{
  $x += $count
  $y += $i
  $count+=1
}

# data series  
[void]$chart.Series.Add("Demand")  
$chart.Series["Demand"].ChartType = "Column"  
$chart.Series["Demand"].BorderWidth = 3  
$chart.Series["Demand"].IsVisibleInLegend = $False  
$chart.Series["Demand"].chartarea = "ChartArea1"  
$chart.Series["Demand"].Legend = "Legend"  
$chart.Series["Demand"].color = "#62B5CC"  
$chart.Series["Demand"].Points.DataBindXY($x,$y)
$date = get-date ((get-date ).AddDays(-1)) -Format "MM_dd_yy"
$file = "C:\temp\" + $date + "_Citrix_Graph.jpeg"
$file2 = $date + "_Citrix_Graph.jpeg"
$Chart.SaveImage($file, "JPEG")

#   EMAIL BODY
$Body = @"
    <html>
        <head>
            <style>
                table, th, td {
                     border: 1px solid black;
                     border-collapse: collapse;
                }
                tr:nth-child(even) {
                    background-color: #D6EEEE;
                }
                th, td {
                    padding: 5px;
                }
                th {
                    text-align: left;
                }
            </style>
         </head>
        <body> 
        <h2>Storefront check against ADC:</h2>
        $BodyChunk3
        <h2>RDS Licenses:</h2>
        $RDSLiceCheck<br><br>
        <h2>Citrix Machine Catalogs:</h2><br>
        <table>
            <tr style="background-color: #DDDDDD">
            <th>Machine Catalog  </th>
            <th>Total Servers Available  </th>
            <th>Zone Health  </th>
            </tr>
$bodychunk1
        </table>
        <BR>
        <h2>Citrix Worker Servers:</h2>
        <table>
            <tr style="background-color: #DDDDDD">
            <th>Machine Name  </th>
            <th>Maint Mode Enabled  </th>
            <th>Power Action Pending  </th>
            <th>Current Session Count  </th>
            <th>Current Power State </th>
            <th>Host Server</th>
            </tr>
$bodychunk2
        </table>
        <h2>Session Data:</h2>
        Top Session Count - $TopSessionCount
            <img src='cid:$file2'>
        </body>
    </html>
"@


function Email-now 
{
Param (
[string]$subject,
[string]$body,
[string]$attach
)
$emailusername = (get-storedcredential -Target 'Email').username
[SecureString]$securepassword  = (get-storedcredential -Target 'Email').password 
$credential = New-Object System.Management.Automation.PSCredential -ArgumentList $emailusername, $securepassword
send-mailmessage -from "no-reply@contoso.com" -to "it-serveradmin@contoso.com" -subject $subject -Attachments $attach -smtpserver "smtp.office365.com" -port 587 -UseSsl -BodyAsHtml -Priority High -credential $credential -body $body

}
Email-now -subject "Citrix Server Farm Health for $date" -body $Body -attach $file
