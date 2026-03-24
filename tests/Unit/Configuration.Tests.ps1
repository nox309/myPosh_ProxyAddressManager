$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Configuration\ProxyAddressManager.Configuration.psm1'
$configPath = Join-Path -Path $repoRoot -ChildPath 'config\appsettings.json'

Import-Module -Name $modulePath -Force

Describe 'Resolve-PamAppPath' {
    It 'resolves relative paths against the app root' {
        $resolvedPath = Resolve-PamAppPath -AppRoot $repoRoot -PathValue 'config\rules.json'

        $resolvedPath | Should Be (Join-Path -Path $repoRoot -ChildPath 'config\rules.json')
    }
}

Describe 'Get-PamAppConfiguration' {
    It 'loads and validates appsettings including resolved paths' {
        $configuration = Get-PamAppConfiguration -AppRoot $repoRoot -ConfigPath $configPath

        $configuration.application.startupMode | Should Be 'GuiShell'
        $configuration.appRoot | Should Be $repoRoot
        $configuration.resolvedPaths.rulesConfiguration | Should Be (Join-Path -Path $repoRoot -ChildPath 'config\rules.json')
        $configuration.resolvedPaths.sampleUsersFile | Should Be (Join-Path -Path $repoRoot -ChildPath 'examples\users.sample.json')
    }
}
