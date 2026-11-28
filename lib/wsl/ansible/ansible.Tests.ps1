<#
.DESCRIPTION
    Pester tests for the dev-stack Ansible assets of wsl-manager: requirements.yml, dev-stack.yml
    and the two in-distribution scripts. They check the text of the files; no Ansible is needed.
#>

param()

BeforeAll {
    $script:AnsibleDir = $PSScriptRoot
    $script:ScriptsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'scripts'

    function Get-AssetText {
        param([string]$Path)
        [System.IO.File]::ReadAllText($Path)
    }

    function Get-AssetByteArray {
        param([string]$Path)
        , [System.IO.File]::ReadAllBytes($Path)
    }
}

Describe "requirements.yml" {
    BeforeAll {
        $script:Req = Get-AssetText (Join-Path $script:AnsibleDir 'requirements.yml')
    }

    It "Should name the role repository" {
        $script:Req | Should -Match 'https://github\.com/xxthunder/ansible-role-dev-stack\.git'
    }

    It "Should use scm git" {
        $script:Req | Should -Match '(?m)^\s*(-\s+)?scm:\s*["'']?git["'']?\s*$'
    }

    It "Should pin version v1.8.0" {
        $script:Req | Should -Match '(?m)^\s*(-\s+)?version:\s*["'']?v1\.8\.0["'']?\s*$'
    }

    It "Should name the role dev_stack" {
        $script:Req | Should -Match '(?m)^\s*(-\s+)?name:\s*["'']?dev_stack["'']?\s*$'
    }
}

Describe "dev-stack.yml" {
    BeforeAll {
        $script:Play = Get-AssetText (Join-Path $script:AnsibleDir 'dev-stack.yml')
    }

    It "Should target localhost" {
        $script:Play | Should -Match '(?m)^\s*(-\s+)?hosts:\s*["'']?localhost["'']?\s*$'
    }

    It "Should connect locally" {
        $script:Play | Should -Match '(?m)^\s*connection:\s*["'']?local["'']?\s*$'
    }

    It "Should become root without a password" {
        $script:Play | Should -Match '(?m)^\s*become:\s*["'']?(true|yes)["'']?\s*$'
    }

    It "Should apply the dev_stack role" {
        $script:Play | Should -Match '(?m)^\s*roles:'
        $script:Play | Should -Match '(?m)^\s*-\s+["'']?dev_stack["'']?\s*$'
    }

    It "Should bind the container runtime to runtime" {
        $script:Play | Should -Match 'dev_stack_container_runtime:\s*["'']\{\{\s*runtime\s*\}\}["'']'
    }

    It "Should bind the user to username" {
        $script:Play | Should -Match 'dev_stack_user:\s*["'']\{\{\s*username\s*\}\}["'']'
    }

    It "Should bind Claude Code to claude_code as a boolean" {
        $script:Play | Should -Match 'dev_stack_install_claude_code:\s*["'']\{\{\s*claude_code\s*\|\s*bool\s*\}\}["'']'
    }

    It "Should switch <Name> on" -ForEach @(
        @{ Name = 'dev_stack_install_devpod' }
        @{ Name = 'dev_stack_install_uv' }
        @{ Name = 'dev_stack_install_gh' }
        @{ Name = 'dev_stack_install_zsh' }
    ) {
        $script:Play | Should -Match ('(?m)^\s*' + $Name + ':\s*["'']?(true|yes)["'']?\s*$')
    }

    It "Should switch <Name> off" -ForEach @(
        @{ Name = 'dev_stack_ssh_agent' }
        @{ Name = 'dev_stack_disable_password_auth' }
    ) {
        $script:Play | Should -Match ('(?m)^\s*' + $Name + ':\s*["'']?(false|no)["'']?\s*$')
    }

    It "Should pass <Name> under environment" -ForEach @(
        @{ Name = 'http_proxy' }
        @{ Name = 'https_proxy' }
        @{ Name = 'no_proxy' }
        @{ Name = 'HTTP_PROXY' }
        @{ Name = 'HTTPS_PROXY' }
        @{ Name = 'NO_PROXY' }
    ) {
        $script:Play | Should -Match ('(?s)\benvironment:.*\b' + $Name + ':')
    }

    It "Should add the DevPod docker provider" {
        $script:Play | Should -Match 'devpod provider add docker'
    }

    It "Should run the DevPod provider step as the user" {
        $script:Play | Should -Match '(?m)^\s*become_user:\s*["'']\{\{\s*username\s*\}\}["'']'
    }

    It "Should not ask for a sudo password" {
        $script:Play | Should -Not -Match '(?<![\w-])-K(?![\w-])'
        $script:Play | Should -Not -Match 'ask_become_pass'
        $script:Play | Should -Not -Match 'become_password'
    }
}

Describe "In-distribution scripts" {
    Context "<Name>" -ForEach @(
        @{ Name = 'setup-dev-stack.sh' }
        @{ Name = 'setup-binfmt-interop.sh' }
    ) {
        BeforeAll {
            $script:Bytes = Get-AssetByteArray (Join-Path $script:ScriptsDir $Name)
            $script:Text = Get-AssetText (Join-Path $script:ScriptsDir $Name)
        }

        It "Should have LF line endings only" {
            $script:Bytes.Length | Should -BeGreaterThan 0
            $script:Bytes | Should -Not -Contain 13
        }

        It "Should start with a bash shebang" {
            $script:Text | Should -Match '^#!(/usr/bin/env bash|/bin/bash)\n'
        }
    }
}

Describe "setup-dev-stack.sh" {
    BeforeAll {
        $script:Script = Get-AssetText (Join-Path $script:ScriptsDir 'setup-dev-stack.sh')
    }

    It "Should not leave errexit on when it exits" {
        $enabled = [regex]::Matches($script:Script, '(?m)^\s*set\s+(-[A-Za-z]*e[A-Za-z]*|.*-o\s+errexit)\b')

        $enabled.Count | Should -Be 0 -Because ('the script runs as a login shell and bash then runs ~/.bash_logout on exit; ' +
            'the /etc/skel/.bash_logout of Debian and Ubuntu ends with a clear_console call that fails without a console, ' +
            'and with errexit on that failure turns every exit code into 1')
    }

    It "Should install ansible-core and git with apt" {
        $script:Script | Should -Match 'apt-get install -y ansible-core git'
    }

    It "Should install the role from requirements.yml" {
        $script:Script | Should -Match 'ansible-galaxy role install -r'
        $script:Script | Should -Match 'requirements\.yml'
    }

    It "Should replace an older role clone" {
        $script:Script | Should -Match 'ansible-galaxy role install -r .*--force'
    }

    It "Should run the playbook" {
        $script:Script | Should -Match 'ansible-playbook'
        $script:Script | Should -Match 'dev-stack\.yml'
    }

    It "Should not ask for a sudo password" {
        $script:Script | Should -Not -Match '(?<![\w-])-K(?![\w-])'
        $script:Script | Should -Not -Match '--ask-become-pass'
    }

    It "Should send failed tasks to stderr, which Invoke-WslDistroScript keeps" {
        # The first code line that calls ansible-playbook (comments name it too)
        $call = [regex]::Match($script:Script, '(?m)^(?!\s*#).*\bansible-playbook\s')
        $call.Success | Should -BeTrue
        $setting = 'ANSIBLE_DISPLAY_FAILED_STDERR=["'']?(true|yes|1)["'']?'

        $prefixed = $call.Value -match ('\b' + $setting + '\s+ansible-playbook\s')
        $exported = [regex]::Match($script:Script, '(?m)^\s*export\s+' + $setting + '\s*$')

        ($prefixed -or ($exported.Success -and $exported.Index -lt $call.Index)) |
            Should -BeTrue -Because 'the playbook must run with ANSIBLE_DISPLAY_FAILED_STDERR=true (env prefix or export before the call)'
    }

    Context "Migration from the old wsl-manager Docker install" {
        BeforeAll {
            # The first code line that runs apt-get
            $script:FirstApt = [regex]::Match($script:Script, '(?m)^(?!\s*#).*\bapt-get\b')
        }

        It "Should run apt-get" {
            $script:FirstApt.Success | Should -BeTrue
        }

        It "Should remove <Path> before the first apt-get" -ForEach @(
            @{ Path = '/etc/apt/sources.list.d/docker.list' }
            @{ Path = '/etc/apt/keyrings/docker.gpg' }
        ) {
            $remove = [regex]::Match($script:Script, '(?m)^(?!\s*#)[^\n]*\brm\b[^\n]*' + [regex]::Escape($Path) + '(?![\w.])')

            $remove.Success | Should -BeTrue -Because "an rm line must name $Path"
            $remove.Index | Should -BeLessThan $script:FirstApt.Index
        }

        It "Should look for the source line the old install-docker.sh wrote before the first apt-get" {
            $marker = [regex]::Match($script:Script, '(?m)^(?!\s*#)[^\n]*' + [regex]::Escape('signed-by=/etc/apt/keyrings/docker.gpg'))

            $marker.Success | Should -BeTrue -Because 'only a list that wsl-manager wrote is removed (ADR-0002)'
            $marker.Index | Should -BeLessThan $script:FirstApt.Index
        }
    }
}

Describe "setup-binfmt-interop.sh" {
    BeforeAll {
        $script:Script = Get-AssetText (Join-Path $script:ScriptsDir 'setup-binfmt-interop.sh')
    }

    It "Should register the WSLInterop format" {
        $script:Script | Should -Match ([regex]::Escape(':WSLInterop:M::MZ::/init:PF'))
    }

    It "Should load the format with systemd-binfmt" {
        $script:Script | Should -Match ([regex]::Escape('/usr/lib/systemd/systemd-binfmt /etc/binfmt.d/WSLInterop.conf'))
    }

    It "Should not restart systemd-binfmt" {
        $script:Script | Should -Not -Match 'systemctl restart systemd-binfmt'
    }
}
