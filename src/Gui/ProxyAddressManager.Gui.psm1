Set-StrictMode -Version Latest

$configurationModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Configuration\ProxyAddressManager.Configuration.psm1'
Import-Module -Name $configurationModulePath -Force

function Assert-PamGuiPrerequisites {
    [CmdletBinding()]
    param()

    if (-not $IsWindows) {
        throw 'Die WPF-Oberflaeche wird nur unter Windows unterstuetzt.'
    }

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
}

function Get-PamGuiConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    return (Get-PamAppConfiguration -AppRoot $AppRoot -ConfigPath $ConfigPath)
}

function Get-PamGuiXamlPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot
    )

    return (Join-Path -Path $AppRoot -ChildPath 'src\Gui\MainWindow.xaml')
}

function Get-PamGuiShellState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    $moduleNames = @($Configuration.bootstrap.moduleRequirements | Where-Object { $_.requiredAtStartup -eq $true } | Sort-Object order, id | ForEach-Object { $_.displayName })

    return [pscustomobject]@{
        WindowTitle = if ($Configuration.gui.windowTitle) { $Configuration.gui.windowTitle } else { 'Proxy Address Manager' }
        WindowWidth = if ($Configuration.gui.windowWidth) { [double]$Configuration.gui.windowWidth } else { 1440 }
        WindowHeight = if ($Configuration.gui.windowHeight) { [double]$Configuration.gui.windowHeight } else { 920 }
        AppRoot = $Configuration.appRoot
        ConfigPath = $Configuration.configPath
        SessionSummary = 'Noch keine Benutzer geladen. Die Shell ist bereit fuer die naechsten Inkremente.'
        StatusHeadline = 'GUI-Grundgeruest geladen'
        StatusBarText = 'Bereit. Konfiguration, Benutzerliste und Preview sind als Platzhalter verbunden.'
        StartupModules = $moduleNames
        Users = @(
            [pscustomobject]@{
                Identity = 'Beispiel: max.mustermann'
                OrganizationalUnit = 'OU=Users,DC=contoso,DC=com'
                Status = 'Noch nicht geladen'
            }
        )
        Preview = @(
            [pscustomobject]@{
                Identity = 'Beispiel: max.mustermann'
                AppliedRule = 'Noch keine Regel'
                ChangeSummary = 'Preview-Engine folgt in einem spaeteren Inkrement'
            }
        )
    }
}

function New-PamMainWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    Assert-PamGuiPrerequisites

    $configuration = Get-PamGuiConfiguration -AppRoot $AppRoot -ConfigPath $ConfigPath
    $state = Get-PamGuiShellState -AppRoot $AppRoot -ConfigPath $ConfigPath -Configuration $configuration
    $xamlPath = Get-PamGuiXamlPath -AppRoot $AppRoot

    if (-not (Test-Path -Path $xamlPath -PathType Leaf)) {
        throw "Die XAML-Datei fuer das Hauptfenster wurde nicht gefunden: $xamlPath"
    }

    $xamlContent = Get-Content -Path $xamlPath -Raw
    $stringReader = [System.IO.StringReader]::new($xamlContent)

    try {
        $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
        $window = [Windows.Markup.XamlReader]::Load($xmlReader)
    }
    finally {
        if ($null -ne $xmlReader) {
            $xmlReader.Dispose()
        }

        $stringReader.Dispose()
    }

    $window.Title = $state.WindowTitle
    $window.Width = $state.WindowWidth
    $window.Height = $state.WindowHeight

    $namedElements = @{
        AppRootTextBlock = $window.FindName('AppRootTextBlock')
        ConfigPathTextBlock = $window.FindName('ConfigPathTextBlock')
        SessionSummaryTextBlock = $window.FindName('SessionSummaryTextBlock')
        StatusHeadlineTextBlock = $window.FindName('StatusHeadlineTextBlock')
        StatusBarTextBlock = $window.FindName('StatusBarTextBlock')
        StartupModulesItemsControl = $window.FindName('StartupModulesItemsControl')
        UsersDataGrid = $window.FindName('UsersDataGrid')
        PreviewDataGrid = $window.FindName('PreviewDataGrid')
    }

    foreach ($entry in $namedElements.GetEnumerator()) {
        if ($null -eq $entry.Value) {
            throw "Das GUI-Element '$($entry.Key)' konnte im MainWindow nicht gefunden werden."
        }
    }

    $namedElements.AppRootTextBlock.Text = $state.AppRoot
    $namedElements.ConfigPathTextBlock.Text = $state.ConfigPath
    $namedElements.SessionSummaryTextBlock.Text = $state.SessionSummary
    $namedElements.StatusHeadlineTextBlock.Text = $state.StatusHeadline
    $namedElements.StatusBarTextBlock.Text = $state.StatusBarText

    $namedElements.StartupModulesItemsControl.ItemsSource = @($state.StartupModules | ForEach-Object {
            [pscustomobject]@{
                Label = $_
            }
        })
    $namedElements.StartupModulesItemsControl.ItemTemplate = [Windows.Markup.XamlReader]::Parse(@"
<DataTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation">
    <Border Margin="0,0,0,6"
            Padding="8,6,8,6"
            CornerRadius="10"
            Background="#FFE7EEF5">
        <TextBlock Text="{Binding Label}"
                   Foreground="#FF35506D" />
    </Border>
</DataTemplate>
"@)

    $namedElements.UsersDataGrid.ItemsSource = $state.Users
    $namedElements.PreviewDataGrid.ItemsSource = $state.Preview

    return [pscustomobject]@{
        Window = $window
        State = $state
        Elements = $namedElements
        XamlPath = $xamlPath
    }
}

function Show-PamMainWindow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $shell = New-PamMainWindow -AppRoot $AppRoot -ConfigPath $ConfigPath
    $null = $shell.Window.ShowDialog()
    return $shell
}

function Test-PamGuiShell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$AppRoot,

        [Parameter(Mandatory)]
        [string]$ConfigPath
    )

    $shell = New-PamMainWindow -AppRoot $AppRoot -ConfigPath $ConfigPath
    $shell.Window.Close()

    return [pscustomobject]@{
        WindowTitle = $shell.State.WindowTitle
        XamlPath = $shell.XamlPath
        StartupModules = @($shell.State.StartupModules)
        UserRows = @($shell.State.Users).Count
        PreviewRows = @($shell.State.Preview).Count
    }
}

Export-ModuleMember -Function @(
    'Assert-PamGuiPrerequisites',
    'Get-PamGuiConfiguration',
    'Get-PamGuiShellState',
    'Get-PamGuiXamlPath',
    'New-PamMainWindow',
    'Show-PamMainWindow',
    'Test-PamGuiShell'
)
