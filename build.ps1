param(
	[string] $verbosity="m",
	[Alias("s")][switch][bool] $skipStores=$false,
	[Alias("se")][switch][bool] $skipEs=$skipStores,
	[Alias("sc")][switch][bool] $skipCosmos=$skipStores,
	[Alias("cs")][string] $cosmosServer=$env:EQUINOX_COSMOS_CONNECTION,
	[Alias("cd")][string] $cosmosDatabase=$env:EQUINOX_COSMOS_DATABASE,
	[Alias("cc")][string] $cosmosCollection=$env:EQUINOX_COSMOS_COLLECTION,
	[Alias("scp")][switch][bool] $skipProvisionCosmos=$skipCosmos -or -not $cosmosServer -or -not $cosmosDatabase -or -not $cosmosCollection,
	[Alias("scd")][switch][bool] $skipDeprovisionCosmos=$skipProvisionCosmos,
	[string] $additionalMsBuildArgs
)

$args=@("/v:$verbosity","/fl","/bl",$additionalMsBuildArgs)

function warn ($msg) { Write-Host "$msg" -BackgroundColor DarkGreen }

# Yes, this leaves the value set on exit, but I want to keep the script legible
$env:EQUINOX_INTEGRATION_SKIP_EVENTSTORE=[string]$skipEs
if ($skipEs) { warn "Skipping EventStore tests" }

function cliCosmos($arghs) {
	Write-Host "dotnet run cli/Equinox.Cli cosmos -s $cosmosServer -d $cosmosDatabase -c $cosmosCollection $arghs"
	dotnet run cli/Equinox.Cli cosmos -s $cosmosServer -d $cosmosDatabase -c $cosmosCollection @arghs
}

if ($skipCosmos) {
	warn "Skipping Cosmos tests as requested"
} elseif ($skipProvisionCosmos) {
	warn "Skipping Provisioning Cosmos"
} else {
    warn "Provisioning cosmos..."
    dotnet run cli/Equinox.Cli cosmos $cosmosServer -d $cosmosDatabase -c $cosmosCollection provision -ru 10000
	$deprovisionCosmos=$true
}
$env:EQUINOX_INTEGRATION_SKIP_COSMOS=[string]$skipCosmos

warn "RUNNING: dotnet msbuild $args"
. dotnet msbuild build.proj @args

if( $LASTEXITCODE -ne 0) {
	warn "open msbuild.log for error info or rebuild with -v n/d/diag for more detail, or open msbuild.binlog using https://github.com/KirillOsenkov/MSBuildStructuredLog/releases/download/v2.0.40/MSBuildStructuredLogSetup.exe"
	exit $LASTEXITCODE
}

if (-not $skipDeprovisionCosmos) {
	warn "Deprovisioning Cosmos"
	throw "Deprovisioning step not implemented yet - please deallocate your resources using the Azure Portal"
}