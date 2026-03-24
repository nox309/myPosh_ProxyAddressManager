$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Gui\ProxyAddressManager.Gui.psm1'
$configPath = Join-Path -Path $repoRoot -ChildPath 'config\appsettings.json'

Import-Module -Name $modulePath -Force

Describe 'Get-PamGuiShellState' {
    It 'builds the placeholder shell state from configuration' {
        $configuration = Get-PamGuiConfiguration -AppRoot $repoRoot -ConfigPath $configPath
        $state = Get-PamGuiShellState -AppRoot $repoRoot -ConfigPath $configPath -Configuration $configuration

        $state.WindowTitle | Should Be 'Proxy Address Manager'
        @($state.StartupModules).Count | Should Be 2
        @($state.Users).Count | Should Be 1
        @($state.Preview).Count | Should Be 1
    }
}

Describe 'Test-PamGuiShell' {
    It 'loads the main window shell' {
        if (-not $IsWindows) {
            return
        }

        $result = Test-PamGuiShell -AppRoot $repoRoot -ConfigPath $configPath

        $result.WindowTitle | Should Be 'Proxy Address Manager'
        $result.UserRows | Should Be 1
        $result.PreviewRows | Should Be 1
    }
}
