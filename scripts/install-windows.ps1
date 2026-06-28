# install-windows.ps1 — Matt Skills multi-platform installer for Windows
# Usage: .\install-windows.ps1 [-Uninstall]
# Idempotent: safe to run multiple times

param(
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$REPO = "Loveacup/matt-skills"
$BRANCH = "main"
$REPO_DIR = Join-Path $env:LOCALAPPDATA "matt-skills"

# ─── Platform target directories ───
$HERMES_SKILLS = Join-Path $env:USERPROFILE ".hermes\skills"
$CLAUDE_SKILLS = Join-Path $env:USERPROFILE ".claude\skills"
$CODEX_SKILLS  = Join-Path $env:USERPROFILE ".codex\skills"

# ─── Colors (PowerShell) ───
function Write-Info  { Write-Host "[matt-skills] $args" -ForegroundColor Blue }
function Write-OK    { Write-Host "  ✅ $args" -ForegroundColor Green }
function Write-Warn  { Write-Host "  ⚠️ $args" -ForegroundColor Yellow }
function Write-Err   { Write-Host "  ❌ $args" -ForegroundColor Red; exit 1 }

# ─── Preflight ───
function Test-Preflight {
    Write-Info "Running preflight checks..."

    # Check ExecutionPolicy
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq "Restricted" -or $policy -eq "Undefined") {
        Write-Err "PowerShell execution policy is Restricted. Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    }

    # Check gh CLI
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        Write-Err "GitHub CLI (gh) not found. Install: winget install --id GitHub.cli"
    }

    # Check gh auth
    $ghAuth = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Err "GitHub CLI not authenticated. Run: gh auth login"
    }

    Write-OK "Preflight passed"
}

# ─── Clone / Update repo ───
function Sync-Repo {
    if (Test-Path (Join-Path $REPO_DIR ".git")) {
        Write-Info "Updating existing repo..."
        Push-Location $REPO_DIR
        git fetch origin $BRANCH --depth 1
        git reset --hard "origin/$BRANCH"
        Pop-Location
        Write-OK "Repo updated"
    } else {
        Write-Info "Cloning repo..."
        New-Item -ItemType Directory -Force -Path (Split-Path $REPO_DIR) | Out-Null
        gh repo clone $REPO $REPO_DIR -- --depth 1 --branch $BRANCH
        Write-OK "Repo cloned to $REPO_DIR"
    }
}

# ─── Install to a platform ───
function Install-Platform {
    param($Platform, $TargetDir)

    Write-Info "Installing to $Platform ($TargetDir)..."
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    $sourceDir = Join-Path $REPO_DIR "skills"
    $count = 0

    foreach ($bucket in @("engineering", "productivity", "misc", "personal")) {
        $bucketPath = Join-Path $sourceDir $bucket
        if (Test-Path $bucketPath) {
            foreach ($skillDir in Get-ChildItem $bucketPath -Directory) {
                $skillName = $skillDir.Name
                $skillFile = Join-Path $skillDir.FullName "SKILL.md"
                if (-not (Test-Path $skillFile)) { continue }

                $dst = Join-Path $TargetDir $skillName
                Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue
                Copy-Item $skillDir.FullName $dst -Recurse -Force
                $count++
            }
        }
    }

    Write-OK "Installed $count skills to $Platform"
}

# ─── Validate installation ───
function Test-Installation {
    Write-Info "Validating installations..."
    $errors = 0

    foreach ($item in @(
        @{Name="Hermes"; Dir=$HERMES_SKILLS},
        @{Name="Claude Code"; Dir=$CLAUDE_SKILLS},
        @{Name="Codex"; Dir=$CODEX_SKILLS}
    )) {
        if (Test-Path $item.Dir) {
            $count = (Get-ChildItem $item.Dir -Recurse -Filter "SKILL.md" -Depth 1 -ErrorAction SilentlyContinue).Count
            if ($count -gt 0) {
                Write-OK "$($item.Name): $count skills found"
            } else {
                Write-Warn "$($item.Name): no skills found"
                $errors++
            }
        } else {
            Write-Warn "$($item.Name): skills directory not found ($($item.Name) may not be installed)"
        }
    }

    if ($errors -gt 0) {
        Write-Info "Validation complete with $errors warnings"
    } else {
        Write-OK "All platforms validated"
    }
}

# ─── Uninstall ───
function Invoke-Uninstall {
    Write-Info "Uninstalling matt-skills..."

    foreach ($platformDir in @($HERMES_SKILLS, $CLAUDE_SKILLS, $CODEX_SKILLS)) {
        if (Test-Path $platformDir) {
            $removed = 0
            foreach ($bucket in @("engineering", "productivity", "misc", "personal")) {
                $bucketPath = Join-Path $REPO_DIR "skills\$bucket"
                if (Test-Path $bucketPath) {
                    foreach ($skillDir in Get-ChildItem $bucketPath -Directory -ErrorAction SilentlyContinue) {
                        $skillName = $skillDir.Name
                        $dst = Join-Path $platformDir $skillName
                        if (Test-Path $dst) {
                            Remove-Item $dst -Recurse -Force
                            $removed++
                        }
                    }
                }
            }
            if ($removed -gt 0) {
                Write-OK "Removed $removed skills from $platformDir"
            }
        }
    }

    # Remove repo cache
    if (Test-Path $REPO_DIR) {
        Remove-Item $REPO_DIR -Recurse -Force
        Write-OK "Removed repo cache at $REPO_DIR"
    }

    Write-OK "Uninstall complete"
}

# ─── Main ───
if ($Uninstall) {
    Test-Preflight
    Invoke-Uninstall
} else {
    Test-Preflight
    Sync-Repo
    Install-Platform "Hermes" $HERMES_SKILLS
    Install-Platform "Claude Code" $CLAUDE_SKILLS
    Install-Platform "Codex" $CODEX_SKILLS
    Test-Installation

    Write-Host ""
    Write-Info "🎉 Installation complete!"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  • Restart Hermes to pick up new skills"
    Write-Host "  • In Claude Code: the skills are auto-discovered"
    Write-Host "  • In Codex: skills are available on next session"
    Write-Host "  • Run with -Uninstall to remove all installed skills"
}
