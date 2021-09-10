# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

. $PSScriptRoot\..\..\..\..\Shared\Confirm-Administrator.ps1
. $PSScriptRoot\..\New-TestResult.ps1
Function Test-UserGroupMemberOf {
    [CmdletBinding()]
    param(
        [bool]$PrepareAdRequired,
        [bool]$PrepareSchemaRequired
    )

    function GetGroupMatches($whoamiOutput, $groupName) {
        $m = @($whoamiOutput | Select-String "(^\w+\\$($groupName))\s+")
        if ($m.Count -eq 0) { return $m }
        return $m | ForEach-Object {
            [PSCustomObject]@{
                GroupName = ($_.Matches.Groups[1].Value)
                SID       = (GetSidFromLine $_.Line)
            }
        }
    }

    Function GetSidFromLine ([string]$Line) {
        $startIndex = $Line.IndexOf("S-")
        return $Line.Substring($startIndex,
            $Line.IndexOf(" ", $startIndex) - $startIndex)
    }

    Function TestGroupResult($WhoamiOutput, $GroupName) {
        [array]$g = GetGroupMatches $WhoamiOutput $GroupName
        $params = @{
            TestName = $GroupName
            Details  = "Not a member of the $GroupName Group"
        }

        if ($g.Count -gt 0) {
            $params.Details = "$($g.GroupName) $($g.SID)"
            New-TestResult @params -Result "Passed"
        } elseif ($GroupName -eq "Schema Admins" -and
            $PrepareSchemaRequired) {
            New-TestResult @params -Result "Failed" -ReferenceInfo "User must be in Schema Admins to update Schema which is required."
        } elseif ($GroupName -eq "Enterprise Admins" -and
            ($PrepareAdRequired -or $PrepareSchemaRequired)) {
            New-TestResult @params -Result "Failed" -ReferenceInfo "User must be Enterprise Admins to do Schema Update or PrepareAD"
        } elseif ($GroupName -eq "Organization Management" -or
            $GroupName -eq "Domain Admins") {
            New-TestResult @params -Result "Failed"
        } else {
            New-TestResult @params -Result "Warning" -ReferenceInfo "User isn't in $GroupName but /PrepareAD is not required"
        }
    }

    $whoami = whoami
    $whoamiAllOutput = whoami /all
    $userSid = ($whoamiAllOutput | Select-String $whoami.Replace("\", "\\")).Line.Replace($whoami, "").Trim()

    $params = @{
        TestName = "User Administrator"
        Details  = "$whoami $userSid"
    }

    if (Confirm-Administrator) {
        New-TestResult @params -Result "Passed"
    } else {
        New-TestResult @params -Result "Failed"
    }

    TestGroupResult $whoamiAllOutput "Domain Admins"
    TestGroupResult $whoamiAllOutput "Schema Admins"
    TestGroupResult $whoamiAllOutput "Enterprise Admins"
    TestGroupResult $whoamiAllOutput "Organization Management"
}

