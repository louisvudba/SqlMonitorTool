Param(
    [Parameter(mandatory=$true)][string]$TargetInstance,
    [Parameter(mandatory=$true)][string]$TargetDatabase,
    [string]$EventName = "Event_SlowQueryLog",
    [string]$TargetSchema = "dbo",
    [string]$Login,
    [string]$Password
)
Import-Module dbatools

# Deploy all SQL script found in \ArchivalDB\Tables
$SQLScripts = (Get-ChildItem -Path '..\SlowQueryLog' -Filter "*.sql") | Sort-Object
foreach($Script in $SQLScripts){
    # Replace default schema name [dbo] with [$TargetSchema]    
    $ScriptContents = Get-Content -Path $Script.FullName -Raw
    $ScriptContents = ($ScriptContents.Replace("[dbo]","[$($TargetSchema)]"))
    $ScriptContents = ($ScriptContents.Replace("{EVENT_NAME}",$EventName))

    # Deploy updated script
    if($Login){
        # Login / Password authentication
        Invoke-SqlCmd -ServerInstance $TargetInstance -Database $TargetDatabase -Username $Login -Password $Password -Query $ScriptContents
    }
    else {
        # Windows authentication
        Invoke-SqlCmd -ServerInstance $TargetInstance -Database $TargetDatabase -Query $ScriptContents
    }      
}