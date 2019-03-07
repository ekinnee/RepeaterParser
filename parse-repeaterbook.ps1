function Convert-HtmlTableToPSObject {
    param
    (
        [Parameter(Mandatory = $true)]

        [Microsoft.PowerShell.Commands.HtmlWebResponseObject] $WebRequest,

        [Parameter(Mandatory = $true)]

        [int] $TableNumber
    )

    ## Extract the tables out of the web request
    $tables = @($WebRequest.ParsedHtml.getElementsByTagName("TABLE"))

    $table = $tables[$TableNumber]

    $titles = @()

    $rows = @($table.Rows)

    ## Go through all of the rows in the table
    foreach ($row in $rows)
    {
        $cells = @($row.Cells)

        ## If we've found a table header, remember its titles
        if ($cells[0].tagName -eq "TH")
        {
            $titles = @($cells | ForEach-Object { ("" + $_.InnerText).Trim() })

            continue
        }

        ## If we haven't found any table headers, make up names "P1", "P2", etc.
        if (-not $titles)
        {
            $titles = @(1..($cells.Count + 2) | ForEach-Object { "P$_" })
        }

        ## Now go through the cells in the the row. For each, try to find the
        ## title that represents that column and create a hashtable mapping those
        ## titles to content
        $resultObject = [Ordered] @{}

        for ($counter = 0; $counter -lt $cells.Count; $counter++)
        {
            $title = $titles[$counter]

            if (-not $title) { continue }

            $resultObject[$title] = ("" + $cells[$counter].InnerText).Trim()
        }

        ## And finally cast that hashtable to a PSCustomObject
        [PSCustomObject] $resultObject
    }
}

function Get-DMRRepeaters {
    param
    (
    )

    $rptrlist = New-Object -TypeName System.Collections.ArrayList

    $web = Invoke-WebRequest -Uri "https://www.repeaterbook.com/repeaters/feature_search.php?type=DMR&state_id=48&band=%25"
    #Make sure there's 6 tables, else the website changed.
    if (@($web.ParsedHtml.getElementsByTagName("TABLE")).Count -eq 6) {
        $rptrs = Convert-HtmlTableToPSObject -WebRequest $web -TableNumber 2

        for ($i = 0; $i -lt $rptrs.Count; $i++) {
            #Freq offset example "+5.0 MHz", "-0.6 MHz"
            $offset = $rptrs[$i].Offset.Split(' ')
            #The math operator +/- is the first character
            $op = $offset[0].Substring(0, 1)
            #Length of 2 = UHF, 4 = VHF
            switch ($offset[0].Length) {
                2 {$val = $offset[0].Substring(1, 1)}
                4 {$val = $offset[0].Substring(1, 3)}
            }

            $rptr = $null;

            try {
                $rptr = [PSCustomObject]@{    
                    RXFreq    = $rptrs[$i].Frequency
                    #This uses the operation sign +/- and frequency offset captured earlier to do the math for TX based on RX freq.
                    #The $($op + $val) causes that bit to be evaluated first so the variable contents operate as expected.
                    TXFreq    = $([double]$rptrs[$i].Frequency + $($op + $val)).ToString()
                    #Caputring the whole offset bit for validation.
                    Offest    = $rptrs[$i].Offset
                    ColorCode = $rptrs[$i].Tone.Replace("CC", "")
                    Location  = $rptrs[$i].Location
                    County    = $rptrs[$i].County
                    Call      = $rptrs[$i].Call
                    Use       = $rptrs[$i].Use
                }
    
                $rptrlist.Add($rptr) | Out-Null
            }
            catch {
                Write-Error -Message "Uanble to parse the site table data to the required format."
            }
        }
    }
    else {
        Write-Error -Message "Website format changed, different number of tables."
    }

    return $rptrlist
}
