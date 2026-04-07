[console]::OutputEncoding = [console]::InputEncoding = [console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
Import-Module PwshSpectreConsole -ErrorAction Stop

$logo = @(
    "     [dodgerblue2]▄████[/][orange1]████▄[/]"
    "    [dodgerblue2]█████▶[/][orange1]██████[/]"
    "    [dodgerblue2]██████[/][orange1]███▼██[/]"
    "    [green]██▲███[/][deeppink3]██████[/]"
    "    [green]██████[/][deeppink3]◀█████[/]"
    "     [green]▀████[/][deeppink3]████▀[/]"
) -join "`n"

Write-SpectreHost $logo
