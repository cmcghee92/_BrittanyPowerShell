# Summary:
# This script queries the Disney API by each princess name individually using
# /character?name=, paginates per name if needed, and outputs the same object
# shape as the catalog-based version: Name, Films, TVShows, ShortFilms.

$baseUrl = "https://api.disneyapi.dev/character"

$princessNames = @(
    "Snow White", "Cinderella", "Aurora", "Ariel", "Belle",
    "Jasmine", "Pocahontas", "Mulan", "Tiana", "Rapunzel",
    "Merida", "Moana", "Raya"
)

$allCharacters = @()

foreach ($princessName in $princessNames) {
    $builder = [System.UriBuilder]::new($baseUrl)
    $builder.Query = "name=$([uri]::EscapeDataString($princessName))&page=1&pageSize=100"
    $pageUri = $builder.Uri.AbsoluteUri

    do {
        try {
            $response = Invoke-RestMethod -Uri $pageUri -Method Get -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to retrieve '$princessName' from '$pageUri'. $($_.Exception.Message)"
            break
        }

        $count = @($response.data).Count
        if ($count -gt 0) {
            $allCharacters += $response.data
        }
        <#
        Uncomment the following line to enable progress output per princess name and page.
        Show progress per princess name and page, but only if we got results to avoid noise for names with no matches.
        This is especially helpful for debugging pagination issues, as it shows when we have multiple pages for a given name.
        The count is based on the current page's data, not cumulative, to reflect the pagination progress more accurately. 
        #>
        # Write-Host "Retrieved $count characters for '$princessName' from: $pageUri"

        $nextPage = $response.info.nextPage
        if ([string]::IsNullOrWhiteSpace($nextPage)) {
            $pageUri = $null
        }
        elseif ($nextPage -match '^https?://') {
            $pageUri = $nextPage
        }
        else {
            $nextBuilder = [System.UriBuilder]::new($baseUrl)
            $nextBuilder.Query = "name=$([uri]::EscapeDataString($princessName))&page=$nextPage&pageSize=100"
            $pageUri = $nextBuilder.Uri.AbsoluteUri
        }
    } while ($pageUri)
}

# Keep only exact princess names to preserve the same outcome contract.
$princessSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$princessNames | ForEach-Object { [void]$princessSet.Add($_) }

$princesses = $allCharacters | Where-Object {
    $name = [string]$_.name
    -not [string]::IsNullOrWhiteSpace($name) -and $princessSet.Contains($name)
}

$results = $princesses |
Sort-Object name -Unique |
Select-Object @{
    Name       = 'Name'
    Expression = { $_.name }
}, @{
    Name       = 'Films'
    Expression = { if ($_.films) { $_.films -join ', ' } else { '' } }
}, @{
    Name       = 'TVShows'
    Expression = { if ($_.tvShows) { $_.tvShows -join ', ' } else { '' } }
}, @{
    Name       = 'ShortFilms'
    Expression = { if ($_.shortFilms) { $_.shortFilms -join ', ' } else { '' } }
}

$results
