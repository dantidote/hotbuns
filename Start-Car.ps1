Param(
    [Parameter(Mandatory=$true)] [string]$emailAddress,
    [Parameter(Mandatory=$false)] $password,
    $threshold = 32
)

$worklat = '42.2923'
$worklon = '-83.2334'
$radius = '0.0010'


if($password.Length -eq 0){
    $password = Read-Host -AsSecureString -Prompt "Password"
    $secure = $true
}

$r = Invoke-WebRequest https://www.myfordmobile.com/content/mfm/app/site/login.html

$sessId = $r.headers.'Set-Cookie'.ToString() -match "JSESSIONID=([0-9a-z\-]*)"

$form = $r.Forms[0]

if($secure) { 
    $plainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($password))
}
else { $plainPass = $password }

$form.Fields["inputEmailAddress"] = $emailAddress
$form.Fields["inputPassword"] = $plainPass

$q = Invoke-WebRequest https://myfordmobile.com/services/webLoginPS -method Post -Body ('{"PARAMS":{"emailaddress":"' + $emailAddress + '","password":"' + $plainPass + '","persistent":"0","ck":"1408645718852","apiLevel":"1"}}') -Headers @{"Cookie" = "JSESSIONID=$($matches[1])"} -ContentType "application/json"

#print $q.Content

if( ! ($q.Content -match '"authToken":"([a-z0-9\-]*)') ) { Write-Error "Returned data doesn't contain authToken" }
$authToken = $matches[1]

if( ! ($q.Content -match '"LATITUDE":"(\d+\.\d+)","LONGITUDE":"(\-?\d+\.\d+)') ) { Write-Error "Didnt match lat+lon" }
$latitude = $matches[1]
$longitude = $matches[2]

if([math]::pow(($latitude - $worklat),2) + [math]::pow(($longitude - $worklon),2) -gt [math]::pow($radius,2)) { Write-Error "car outside radius"; exit }

$weather = New-WebServiceProxy -Uri http://www.webservicex.com/globalweather.asmx?WSDL
$data = ([xml]$weather.getWeather('Detroit, Detroit Metropolitan Wayne County Airport','United States')).CurrentWeather

if( ! $data.Temperature -match '^ (\d+\.\d+).*' ) {Write-Error "Couldn't get weather"}

$temp = $matches[1]

if($temp -le $threshold){

$URL = "https://phev.myfordmobile.com/services/webAddCommandPS"
$Content = "application/json"

$time = [Math]::ceiling((New-TimeSpan -start (get-date "01/01/1970") -end (get-date)).TotalMilliseconds)

$body = '{"PARAMS":{"SESSIONID":"' + $authToken + '","LOOKUPCODE":"START_CMD"' + ',"ck":"' + $time + '","apiLevel":"1"}}'

$z = Invoke-WebRequest -Uri $URL -WebSession $mfm -Method POST -Body $body -ContentType $content

$z.Content

Write-Host "Car Started"
}
else{ write-host "the weather is much too nice to start" }
