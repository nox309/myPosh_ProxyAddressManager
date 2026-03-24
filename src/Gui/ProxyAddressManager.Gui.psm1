Set-StrictMode -Version Latest

$configurationModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Configuration\ProxyAddressManager.Configuration.psm1'
$rulesModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Configuration\ProxyAddressManager.Rules.psm1'
$ruleSelectionModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Engine\ProxyAddressManager.RuleSelection.psm1'
$previewModulePath = Join-Path -Path $PSScriptRoot -ChildPath '..\Engine\ProxyAddressManager.Preview.psm1'
Import-Module -Name $configurationModulePath -Force
Import-Module -Name $rulesModulePath -Force
Import-Module -Name $ruleSelectionModulePath -Force
Import-Module -Name $previewModulePath -Force

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
    $runtimeData = Get-PamGuiRuntimeData -Configuration $Configuration

    return [pscustomobject]@{
        WindowTitle = if ($Configuration.gui.windowTitle) { $Configuration.gui.windowTitle } else { 'Proxy Address Manager' }
        WindowWidth = if ($Configuration.gui.windowWidth) { [double]$Configuration.gui.windowWidth } else { 1440 }
        WindowHeight = if ($Configuration.gui.windowHeight) { [double]$Configuration.gui.windowHeight } else { 920 }
        AppRoot = $Configuration.appRoot
        ConfigPath = $Configuration.configPath
        SessionSummary = $runtimeData.SessionSummary
        StatusHeadline = $runtimeData.StatusHeadline
        StatusBarText = $runtimeData.StatusBarText
        StartupModules = $moduleNames
        Users = @($runtimeData.Users)
        Preview = @($runtimeData.Preview)
        DataSource = $runtimeData.DataSource
        LoadError = $runtimeData.LoadError
    }
}

function Get-PamGuiRulesPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    return [string]$Configuration.resolvedPaths.rulesConfiguration
}

function Get-PamGuiSampleUsersPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    return [string]$Configuration.resolvedPaths.sampleUsersFile
}

function Get-PamGuiUserIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    foreach ($propertyName in @('SamAccountName', 'UserPrincipalName', 'DistinguishedName')) {
        foreach ($property in $UserObject.PSObject.Properties) {
            if ($property.Name -ieq $propertyName -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                return [string]$property.Value
            }
        }
    }

    return 'Unbekannt'
}

function Get-PamGuiOrganizationalUnit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject
    )

    $distinguishedName = $null
    foreach ($property in $UserObject.PSObject.Properties) {
        if ($property.Name -ieq 'DistinguishedName') {
            $distinguishedName = [string]$property.Value
            break
        }
    }

    if ([string]::IsNullOrWhiteSpace($distinguishedName)) {
        return 'n/a'
    }

    $firstOuIndex = $distinguishedName.IndexOf('OU=', [System.StringComparison]::OrdinalIgnoreCase)
    if ($firstOuIndex -lt 0) {
        return $distinguishedName
    }

    return $distinguishedName.Substring($firstOuIndex)
}

function Get-PamGuiChangeSummary {
    [CmdletBinding()]
    param(
        [psobject]$PreviewObject
    )

    if ($null -eq $PreviewObject) {
        return 'Keine Preview verfuegbar'
    }

    $changes = @($PreviewObject.Changes)
    if ($changes.Count -eq 0) {
        return 'Keine Aenderung'
    }

    return [string]::Join(', ', $changes)
}

function ConvertTo-PamGuiUserRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [psobject]$RuleSelection,

        [psobject]$PreviewObject
    )

    $status = if ($null -eq $RuleSelection -or $null -eq $RuleSelection.SelectedRule) {
        'Keine passende Regel'
    }
    elseif ($null -eq $PreviewObject) {
        "Regel: $($RuleSelection.SelectedRuleName)"
    }
    elseif ($PreviewObject.Diff.HasChanges) {
        "Regel: $($RuleSelection.SelectedRuleName) | Aenderungen"
    }
    else {
        "Regel: $($RuleSelection.SelectedRuleName) | Keine Aenderung"
    }

    return [pscustomobject]@{
        Identity = Get-PamGuiUserIdentity -UserObject $UserObject
        OrganizationalUnit = Get-PamGuiOrganizationalUnit -UserObject $UserObject
        Status = $status
    }
}

function ConvertTo-PamGuiPreviewRow {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$UserObject,

        [psobject]$RuleSelection,

        [psobject]$PreviewObject
    )

    if ($null -eq $RuleSelection -or $null -eq $RuleSelection.SelectedRule) {
        return [pscustomobject]@{
            Identity = Get-PamGuiUserIdentity -UserObject $UserObject
            AppliedRule = 'Keine passende Regel'
            CurrentMail = [string]$UserObject.Mail
            ProposedMail = ''
            ChangeSummary = 'Keine Vorschau moeglich'
        }
    }

    return [pscustomobject]@{
        Identity = $PreviewObject.Identity
        AppliedRule = $PreviewObject.AppliedRule
        CurrentMail = $PreviewObject.CurrentMail
        ProposedMail = $PreviewObject.ProposedMail
        ChangeSummary = Get-PamGuiChangeSummary -PreviewObject $PreviewObject
    }
}

function Get-PamGuiRuntimeData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    try {
        $rulesPath = Get-PamGuiRulesPath -Configuration $Configuration
        $sampleUsersPath = Get-PamGuiSampleUsersPath -Configuration $Configuration

        if (-not (Test-Path -Path $sampleUsersPath -PathType Leaf)) {
            throw "Die Beispieldatei fuer Benutzer wurde nicht gefunden: $sampleUsersPath"
        }

        $rulesConfiguration = Get-PamRulesConfiguration -RulesPath $rulesPath
        $users = @(Get-Content -Path $sampleUsersPath -Raw | ConvertFrom-Json -Depth 20)

        $userRows = New-Object System.Collections.Generic.List[object]
        $previewRows = New-Object System.Collections.Generic.List[object]

        foreach ($user in $users) {
            $selection = Select-PamApplicableRule -UserObject $user -Rules @($rulesConfiguration.rules)
            $preview = $null

            if ($null -ne $selection.SelectedRule) {
                $preview = New-PamRecipientPreview -UserObject $user -Rule $selection.SelectedRule
            }

            $userRows.Add((ConvertTo-PamGuiUserRow -UserObject $user -RuleSelection $selection -PreviewObject $preview))
            $previewRows.Add((ConvertTo-PamGuiPreviewRow -UserObject $user -RuleSelection $selection -PreviewObject $preview))
        }

        $previewChangeCount = @($previewRows | Where-Object { $_.ChangeSummary -ne 'Keine Aenderung' -and $_.ChangeSummary -ne 'Keine Vorschau moeglich' }).Count
        $matchedRuleCount = @($previewRows | Where-Object { $_.AppliedRule -ne 'Keine passende Regel' }).Count

        return [pscustomobject]@{
            SessionSummary = "$(@($users).Count) Benutzer aus Beispieldaten geladen, $matchedRuleCount Regelzuordnungen bestimmt."
            StatusHeadline = 'Read-only Preview bereit'
            StatusBarText = "$previewChangeCount Benutzer mit vorgeschlagenen Aenderungen. Datenquelle: Beispieldatei."
            Users = $userRows.ToArray()
            Preview = $previewRows.ToArray()
            DataSource = 'SampleUsers'
            LoadError = $null
        }
    }
    catch {
        $errorMessage = $_.Exception.Message

        return [pscustomobject]@{
            SessionSummary = 'Die GUI konnte keine Benutzer- und Preview-Daten laden.'
            StatusHeadline = 'Ladefehler'
            StatusBarText = $errorMessage
            Users = @(
                [pscustomobject]@{
                    Identity = 'Keine Daten'
                    OrganizationalUnit = 'n/a'
                    Status = 'Fehler beim Laden'
                }
            )
            Preview = @(
                [pscustomobject]@{
                    Identity = 'Keine Daten'
                    AppliedRule = 'Fehler'
                    CurrentMail = ''
                    ProposedMail = ''
                    ChangeSummary = 'Details im Statusbereich'
                }
            )
            DataSource = 'None'
            LoadError = $errorMessage
        }
    }
}

function Set-PamGuiShellState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Shell,

        [Parameter(Mandatory)]
        [psobject]$State
    )

    $Shell.Elements.AppRootTextBlock.Text = $State.AppRoot
    $Shell.Elements.ConfigPathTextBlock.Text = $State.ConfigPath
    $Shell.Elements.SessionSummaryTextBlock.Text = $State.SessionSummary
    $Shell.Elements.StatusHeadlineTextBlock.Text = $State.StatusHeadline
    $Shell.Elements.StatusBarTextBlock.Text = $State.StatusBarText
    $Shell.Elements.UsersDataGrid.ItemsSource = @($State.Users)
    $Shell.Elements.PreviewDataGrid.ItemsSource = @($State.Preview)
    $Shell.State = $State
}

function Refresh-PamGuiShellData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Shell,

        [Parameter(Mandatory)]
        [psobject]$Configuration
    )

    $updatedState = Get-PamGuiShellState -AppRoot $Configuration.appRoot -ConfigPath $Configuration.configPath -Configuration $Configuration
    Set-PamGuiShellState -Shell $Shell -State $updatedState
    return $updatedState
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
        LoadUsersButton = $window.FindName('LoadUsersButton')
        RefreshPreviewButton = $window.FindName('RefreshPreviewButton')
        UsersDataGrid = $window.FindName('UsersDataGrid')
        PreviewDataGrid = $window.FindName('PreviewDataGrid')
    }

    foreach ($entry in $namedElements.GetEnumerator()) {
        if ($null -eq $entry.Value) {
            throw "Das GUI-Element '$($entry.Key)' konnte im MainWindow nicht gefunden werden."
        }
    }

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

    $shell = [pscustomobject]@{
        Window = $window
        State = $state
        Elements = $namedElements
        XamlPath = $xamlPath
    }

    Set-PamGuiShellState -Shell $shell -State $state

    $refreshHandler = {
        Refresh-PamGuiShellData -Shell $shell -Configuration $configuration | Out-Null
    }.GetNewClosure()

    $namedElements.LoadUsersButton.IsEnabled = $true
    $namedElements.RefreshPreviewButton.IsEnabled = $true
    $namedElements.LoadUsersButton.Add_Click($refreshHandler)
    $namedElements.RefreshPreviewButton.Add_Click($refreshHandler)

    return $shell
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
        DataSource = $shell.State.DataSource
        StatusHeadline = $shell.State.StatusHeadline
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
