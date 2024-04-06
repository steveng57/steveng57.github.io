param(
    [Parameter(Mandatory=$true)]
    [string]$rootUrl
)

# Create a HashSet to store the URLs that have been checked
$checkedUrls = New-Object System.Collections.Generic.HashSet[string]
    # Define the list of error codes

function Check-Links {
    param(
        [Parameter(Mandatory=$true)]
        [string]$url
    )

    # Check if the URL has already been checked
    if ($checkedUrls.Contains($url)) {
        return
    }

    # Add the URL to the HashSet of checked URLs
    $checkedUrls.Add($url)

    Write-Host "Checking URL: $url"

    try {
        # Download the HTML content
        $htmlContent = Invoke-WebRequest -Uri $url

        # Go through all the links in the HTML content
        foreach ($link in $htmlContent.Links.href) {
            $linkUrl = $link

            # Skip if the URL is empty, a bookmark, or a mailto link
            if ([string]::IsNullOrEmpty($linkUrl) -or $linkUrl.StartsWith("#") -or $linkUrl.StartsWith("mailto:") -or $linkUrl.StartsWith("javascript:") -or $linkUrl.StartsWith("{url}")) {
                continue
            }

            # Check if the URL is an image
            if ($linkUrl -match "\.(jpg|jpeg|png|gif|mp4)$") {
                try {
                    # Check if the URL is relative
                    if ($linkUrl.StartsWith("/")) {
                        # Convert the relative URL to an absolute URL
                        $linkUrl = $rootUrl.TrimEnd("/") + $linkUrl
                    }

                    # Send a request to the URL
                    $response = Invoke-WebRequest -Uri $linkUrl -Method Head -TimeoutSec 5

                    # Check if the response status code is not successful
                    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
                        Write-Host "Broken image link: $linkUrl in URL: $url"
                    }
                } catch {
                    # Catch any errors from Invoke-WebRequest
                    Write-Host "Broken image link: $linkUrl in URL: $url"
                }

                # Skip further processing for image URLs
                continue
            }

            # Check if the URL is relative
            if ($linkUrl.StartsWith("/")) {
                # Convert the relative URL to an absolute URL
                $linkUrl = $rootUrl.TrimEnd("/") + $linkUrl

                # Recursively check the links in the URL
                Check-Links -url $linkUrl
            } else {
                try {
                    # Send a request to the URL
                    $response = Invoke-WebRequest -Uri $linkUrl -Method Head -TimeoutSec 5

                    # Check if the response status code is not successful
                    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 300) {
                        Write-Host "Error status code: $response.StatusCode at $linkUrl in URL: $url"
                    }
                } catch {

                    # Define the list of ignored domains
                    $ignoredDomains = @("facebook", "twitter", "linkedin", "github")

                    # Check if the URL contains any of the ignored domains
                    if ($ignoredDomains | Where-Object { $linkUrl -match $_ }) {
                        return
                    }

                    $errorCodes = @(400, 401, 403, 404, 500, 502, 503, 504)
                    # Catch any errors from Invoke-WebRequest
                    $statusCode = $_.Exception.Response.StatusCode
                    if ($statusCode -in $errorCodes) {
                        Write-Host "Broken link / Invoke-WebRequest Catch.  Status Code: $statusCode at $linkUrl in URL: $url"
                    }
                }
            }
        }
    } catch {
        # Catch any errors from Invoke-WebRequest
        Write-Host "Failed to download URL: $url"
    }
}

# Start the link checking from the root URL
Check-Links -url $rootUrl