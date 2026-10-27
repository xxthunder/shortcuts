# PSScriptAnalyzer settings, read by Invoke-Formatter, linter.Tests.ps1 and
# the Claude Code hook. The default rules run at Warning and Error severity;
# the formatting rules are those of the built-in CodeFormatting preset, without
# PSUseCorrectCasing (SC-083).
@{
    Severity = @('Error', 'Warning')

    Rules    = @{
        PSPlaceOpenBrace           = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }

        PSPlaceCloseBrace          = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }

        PSUseConsistentIndentation = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }

        PSUseConsistentWhitespace  = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $false
            CheckSeparator                          = $true
            CheckParameter                          = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSAlignAssignmentStatement = @{
            Enable         = $true
            CheckHashtable = $true
        }

        # Off, unlike the preset: to find a command's casing it resolves the command on a
        # thread without a runspace, which fails for commands of PwshSpectreConsole
        PSUseCorrectCasing         = @{
            Enable = $false
        }
    }
}
