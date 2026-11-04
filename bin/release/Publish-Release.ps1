#Requires -Version 7.4

<#
.SYNOPSIS
    Commit a built release tree onto the orphan branch 'release'.

.DESCRIPTION
    Replaces the content of the branch with the tree in TreePath, commits it
    with the message 'release: build from <SourceCommit>' and pushes it. The
    branch is orphaned: its first commit has no parent. If the remote has the
    branch, the new commit goes on top of it. If the tree did not change, or
    SourceCommit is older than or equal to the commit the tip of release was
    built from, no commit is made: release never goes backwards. The work
    happens in a temporary worktree outside the repository, which is always
    removed.

.PARAMETER RepoPath
    Repository to commit in. Required unless the script is dot-sourced in
    library mode (a mandatory parameter would make the dot-source prompt).

.PARAMETER TreePath
    Folder holding the built release tree. Required, as RepoPath.

.PARAMETER SourceCommit
    Commit the tree was built from. Goes into the commit message. Required,
    as RepoPath.

.PARAMETER NoPush
    Commit, but do not push.

.EXAMPLE
    .\Publish-Release.ps1 -RepoPath . -TreePath C:\temp\release -SourceCommit abc123
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoPath,

    [Parameter(Mandatory = $false)]
    [string]$TreePath,

    [Parameter(Mandatory = $false)]
    [string]$SourceCommit,

    [Parameter(Mandatory = $false)]
    [switch]$NoPush
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# The branch downstream forks track, and the remote it lives on.
$ReleaseBranch = 'release'
$ReleaseRemote = 'origin'

# --- Dependencies ---------------------------------------------------------
. "$PSScriptRoot\..\..\lib\utils\utils.ps1"

# --- Functions ------------------------------------------------------------

function Invoke-GitCommand {
    <#
    .SYNOPSIS
        Run git in a folder; throw with git's output when it fails.
    .OUTPUTS
        [string[]] the output lines of git.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$GitArgument
    )

    $output = @(& git -C $Path @GitArgument 2>&1 | ForEach-Object { "$_" })
    if ($LASTEXITCODE -ne 0) {
        throw "git $($GitArgument -join ' ') failed with exit code ${LASTEXITCODE}: $($output -join [Environment]::NewLine)"
    }
    return $output
}

function Test-RemoteReleaseBranch {
    <#
    .SYNOPSIS
        Tell whether the remote has the release branch.
    .DESCRIPTION
        Decides on the exit code of 'git ls-remote --exit-code' alone: 0 is
        present, 2 is absent, anything else throws with git's error output.
    .OUTPUTS
        [bool] $true when the remote has the branch.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    $errorFile = New-TemporaryFile
    try {
        & git -C $RepoPath ls-remote --exit-code $ReleaseRemote "refs/heads/$ReleaseBranch" 2> $errorFile.FullName | Out-Null
        $exitCode = $LASTEXITCODE
        switch ($exitCode) {
            0 { return $true }
            2 { return $false }
            default {
                $errorText = Get-Content -LiteralPath $errorFile.FullName -Raw
                throw "git ls-remote $ReleaseRemote failed with exit code ${exitCode}: $errorText"
            }
        }
    }
    finally {
        Remove-Item -LiteralPath $errorFile.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Get-PublishedSourceCommit {
    <#
    .SYNOPSIS
        Read the source commit of the fetched release tip from its subject.
    .OUTPUTS
        [string] the sha from 'release: build from <sha>', or $null when the
        subject does not parse or the commit is unknown in RepoPath.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath
    )

    $tip = "refs/remotes/$ReleaseRemote/$ReleaseBranch"
    $subject = "$(Invoke-GitCommand -Path $RepoPath -GitArgument @('log', '-1', '--format=%s', $tip) | Select-Object -First 1)"
    if ($subject -notmatch '^release: build from ([0-9a-f]{40})$') {
        return $null
    }
    $sha = $Matches[1]
    & git -C $RepoPath cat-file -e "$sha^{commit}" 2>$null
    if ($LASTEXITCODE -ne 0) {
        return $null
    }
    return $sha
}

function Test-GitAncestor {
    <#
    .SYNOPSIS
        Tell whether Ancestor is an ancestor of Descendant, or the same commit.
    .OUTPUTS
        [bool]; throws when git cannot decide (an unknown commit).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$Ancestor,

        [Parameter(Mandatory = $true)]
        [string]$Descendant
    )

    $output = & git -C $RepoPath merge-base --is-ancestor $Ancestor $Descendant 2>&1 | Out-String
    switch ($LASTEXITCODE) {
        0 { return $true }
        1 { return $false }
        default { throw "git merge-base --is-ancestor $Ancestor $Descendant failed with exit code ${LASTEXITCODE}: $output" }
    }
}

function Publish-ReleaseTree {
    <#
    .SYNOPSIS
        Commit the release tree onto the release branch and push it.
    .OUTPUTS
        [bool] $true when a commit was made; $false when the tree did not change
        or SourceCommit is not newer than the source of release.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoPath,

        [Parameter(Mandatory = $true)]
        [string]$TreePath,

        [Parameter(Mandatory = $true)]
        [string]$SourceCommit,

        [Parameter(Mandatory = $false)]
        [switch]$NoPush
    )

    $remoteHasBranch = Test-RemoteReleaseBranch -RepoPath $RepoPath
    if ($remoteHasBranch) {
        # An explicit refspec, so the fetch does not depend on the clone's remote.<name>.fetch.
        $refspec = "+refs/heads/${ReleaseBranch}:refs/remotes/$ReleaseRemote/$ReleaseBranch"
        Invoke-GitCommand -Path $RepoPath -GitArgument @('fetch', $ReleaseRemote, $refspec) | Out-Null
        $published = Get-PublishedSourceCommit -RepoPath $RepoPath
        if ($published -and (Test-GitAncestor -RepoPath $RepoPath -Ancestor $SourceCommit -Descendant $published)) {
            Write-Status "Skipping ${SourceCommit}: release is already built from $published, which contains it"
            return $false
        }
    }

    $worktree = Join-Path ([System.IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N'))
    try {
        if ($remoteHasBranch) {
            Invoke-GitCommand -Path $RepoPath -GitArgument @('worktree', 'add', '-B', $ReleaseBranch, $worktree, "$ReleaseRemote/$ReleaseBranch") | Out-Null
        }
        else {
            Invoke-GitCommand -Path $RepoPath -GitArgument @('worktree', 'add', '--orphan', '-b', $ReleaseBranch, $worktree) | Out-Null
        }

        # '.git' in a worktree is the link file to the repository: keep it.
        Get-ChildItem -LiteralPath $worktree -Force |
            Where-Object { $_.Name -ne '.git' } |
            Remove-Item -Recurse -Force
        Get-ChildItem -LiteralPath $TreePath -Force |
            Copy-Item -Destination $worktree -Recurse -Force

        Invoke-GitCommand -Path $worktree -GitArgument @('add', '-A') | Out-Null
        & git -C $worktree diff --cached --quiet
        if ($LASTEXITCODE -eq 0) {
            return $false
        }
        if ($LASTEXITCODE -ne 1) {
            throw "git diff --cached failed with exit code $LASTEXITCODE"
        }

        Invoke-GitCommand -Path $worktree -GitArgument @('commit', '-m', "release: build from $SourceCommit") | Out-Null
        if (-not $NoPush) {
            # Push from the checkout, so the push uses its credential config.
            Invoke-GitCommand -Path $RepoPath -GitArgument @('push', $ReleaseRemote, $ReleaseBranch) | Out-Null
        }
        return $true
    }
    finally {
        & git -C $RepoPath worktree remove --force $worktree 2>&1 | Out-Null
        & git -C $RepoPath worktree prune 2>&1 | Out-Null
        if (Test-Path -LiteralPath $worktree) {
            Remove-Item -LiteralPath $worktree -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Main -----------------------------------------------------------------
if (-not $env:PUBLISHRELEASE_LIBRARY_MODE) {
    if (-not $RepoPath) { throw 'Parameter -RepoPath is required.' }
    if (-not $TreePath) { throw 'Parameter -TreePath is required.' }
    if (-not $SourceCommit) { throw 'Parameter -SourceCommit is required.' }
    Write-Status "Committing the release tree onto '$ReleaseBranch'"
    $committed = Publish-ReleaseTree -RepoPath $RepoPath -TreePath $TreePath -SourceCommit $SourceCommit -NoPush:$NoPush
    if ($committed) {
        Write-Success "Release commit made for $SourceCommit"
    }
    else {
        Write-Success "No release commit made for $SourceCommit"
    }
}
