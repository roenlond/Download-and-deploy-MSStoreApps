<#
.SYNOPSIS
    Converts a list of store library strings to objects.

.DESCRIPTION
    This function takes an array of strings representing store library entries and converts each entry into a PSObject with properties for Name, Version, FileType, Url, and Size.

.PARAMETER InputObject
    An array of strings representing store library entries.

.EXAMPLE
    $storeLibStrings = @(
        "[Microsoft.WindowsNotepad_11.2402.22.0_neutral_~_8wekyb3d8bbwe.Msixbundle](http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/e56b5b40-3d30-449c-a72d-5ce7c0423f05?P1=1721290476&P2=404&P3=2&P4=DgQodfR4av4dnIj%2b6PaZkcIbAQ6P0SxDO3T9AsqUImyShhyN87gaBioMLlMNrnuG7gQ5shvhe0Z4%2b9Uo5AqOlw%3d%3d): 13MB"
    )
    $objects = $storeLibStrings | Convert-StoreLibToObject
    $objects

.NOTES
    Author: Patrik Ronnlund
    Date: 2024-07-18
#>

function Convert-StoreLibToObject {
    Param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object[]]$InputObject
    )

    Begin {
        $OutputObject = [System.Collections.Generic.List[PSObject]]::new()
    }

    Process {
        foreach ($string in $InputObject) {
            try {
                # We split the string on ] to get the name, version and filetype on index 0 with url and file size on index 1
                $SplitString = $string.Split("]").TrimStart("[")

                # Get the name, version and filetype from the first split index - example:
                # Microsoft.MicrosoftStickyNotes_1.8.0.0_neutral_~_8wekyb3d8bbwe.AppxBundle
                $NameVersionFileType = $SplitString[0]
                $Name = $NameVersionFileType.Split("_")[0]
                $Version = $NameVersionFileType.Split("_")[1]
                $FileType = $NameVersionFileType.split(".")[-1]

                # Get the URL and filesize from the second split index - example:
                # (http://tlu.dl.delivery.mp.microsoft.com/filestreamingservice/files/53f43f75-9264-40df-bf09-e631d96c9795?P1=1708951154&P2=404&P3=2&P4=bG7op7om0VLsB67OS1e18%2ft7pRH8nqB0IT2m0Nxet0edzm8SJahlconv%2fBdFVMtki1COOfm0tAQ9zg19UvLCgw%3d%3d): 20,2MB
                $URLFileSize = $SplitString[1]
                $URL = $URLFileSize.TrimStart("(").Split(")")[0]
                $FileSize = $URLFileSize.TrimStart("(").Split(")")[1].TrimStart(": ")
                
                $object = [PSObject]::new()
                $object | Add-Member -MemberType NoteProperty -Name Name -Value $Name
                $object | Add-Member -MemberType NoteProperty -Name Version -Value $Version
                $object | Add-Member -MemberType NoteProperty -Name FileType -Value $FileType
                $object | Add-Member -MemberType NoteProperty -Name Url -Value $URL
                $object | Add-Member -MemberType NoteProperty -Name Size -Value $FileSize

                $OutputObject.Add($object)
            } catch {}
        }
    }

    End {
        return $OutputObject
    }
}