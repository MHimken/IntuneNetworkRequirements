<#
This script is not done!
.SYNOPSIS
This script will retrieve the RSS for M365 endpoints (via https://endpoints.office.com/version/worldwide) and publish it to GitHub
.DESCRIPTION
This script will retrieve the RSS feed for M365 endpoints and publish it to a GitHub repository.
#>
$GUID = (New-Guid).Guid
$total = foreach ($item in Invoke-RestMethod -Uri "https://endpoints.office.com/version/worldwide?clientRequestId=$GUID&allVersions=true&format=RSS&ServiceAreas=MEM" ) {
    [PSCustomObject]@{
        guid = $item.guid
        date = $item.pubDate
        title = $item.Title
        link = $item.Link
    }
}

$total | Sort-Object { $_.date -as [datetime] }