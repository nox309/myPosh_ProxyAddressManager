$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent $here)
$modulePath = Join-Path -Path $repoRoot -ChildPath 'src\Configuration\ProxyAddressManager.Rules.psm1'
$rulesPath = Join-Path -Path $repoRoot -ChildPath 'config\rules.json'

Import-Module -Name $modulePath -Force

Describe 'Get-PamRulesConfiguration' {
    It 'loads the default rules file' {
        $rulesConfiguration = Get-PamRulesConfiguration -RulesPath $rulesPath

        $rulesConfiguration.schemaVersion | Should Be '1.0'
        @($rulesConfiguration.rules).Count | Should Be 1
        $rulesConfiguration.rules[0].name | Should Be 'Standard Users'
    }

    It 'throws when schemaVersion is missing' {
        $tempPath = Join-Path -Path $env:TEMP -ChildPath "pam-rules-noschema-$([guid]::NewGuid()).json"
        Set-Content -Path $tempPath -Value '{"rules":[]}' -Encoding UTF8

        $didThrow = $false
        try {
            $null = Get-PamRulesConfiguration -RulesPath $tempPath
        }
        catch {
            $didThrow = $true
        }
        finally {
            Remove-Item -Path $tempPath -ErrorAction SilentlyContinue
        }

        $didThrow | Should Be $true
    }

    It 'throws when priorities are duplicated' {
        $tempPath = Join-Path -Path $env:TEMP -ChildPath "pam-rules-dupe-$([guid]::NewGuid()).json"
        Set-Content -Path $tempPath -Value @'
{
  "schemaVersion": "1.0",
  "rules": [
    {
      "name": "Rule A",
      "enabled": true,
      "priority": 100,
      "scope": {},
      "primaryAddressTemplate": "%GivenName%",
      "aliasTemplates": [],
      "domainRules": { "primaryDomain": "contoso.com" },
      "normalizationRules": {},
      "overrides": []
    },
    {
      "name": "Rule B",
      "enabled": true,
      "priority": 100,
      "scope": {},
      "primaryAddressTemplate": "%Surname%",
      "aliasTemplates": [],
      "domainRules": { "primaryDomain": "contoso.com" },
      "normalizationRules": {},
      "overrides": []
    }
  ]
}
'@ -Encoding UTF8

        $didThrow = $false
        $message = $null
        try {
            $null = Get-PamRulesConfiguration -RulesPath $tempPath
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }
        finally {
            Remove-Item -Path $tempPath -ErrorAction SilentlyContinue
        }

        $didThrow | Should Be $true
        $message | Should Match 'doppelte Prioritaet'
    }

    It 'throws when a required rule field is missing' {
        $tempPath = Join-Path -Path $env:TEMP -ChildPath "pam-rules-missing-$([guid]::NewGuid()).json"
        Set-Content -Path $tempPath -Value @'
{
  "schemaVersion": "1.0",
  "rules": [
    {
      "name": "Broken Rule",
      "enabled": true,
      "priority": 100,
      "scope": {},
      "aliasTemplates": [],
      "domainRules": { "primaryDomain": "contoso.com" },
      "normalizationRules": {},
      "overrides": []
    }
  ]
}
'@ -Encoding UTF8

        $didThrow = $false
        $message = $null
        try {
            $null = Get-PamRulesConfiguration -RulesPath $tempPath
        }
        catch {
            $didThrow = $true
            $message = $_.Exception.Message
        }
        finally {
            Remove-Item -Path $tempPath -ErrorAction SilentlyContinue
        }

        $didThrow | Should Be $true
        $message | Should Match 'primaryAddressTemplate'
    }
}
