#!/bin/bash
# install-macos.sh — Matt Skills multi-platform installer for macOS
# Usage: ./install-macos.sh [--uninstall]
# Idempotent: safe to run multiple times

set -euo pipefail

REPO="Loveacup/matt-skills"
BRANCH="main"
REPO_DIR="${HOME}/.local/share/matt-skills"
ACTION="${1:-install}"

# ─── Platform target directories ───
HERMES_SKILLS="${HOME}/.hermes/skills"
CLAUDE_SKILLS="${HOME}/.claude/skills"
CODEX_SKILLS="${HOME}/.codex/skills"

# ─── Colors ───
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

say() { echo -e "${BLUE}[matt-skills]${NC} $*"; }
ok()  { echo -e "${GREEN}  ✅${NC} $*"; }
warn(){ echo -e "${YELLOW}  ⚠️${NC} $*"; }
err() { echo -e "${RED}  ❌${NC} $*"; exit 1; }

# ─── Preflight ───
preflight() {
    say "Running preflight checks..."

    # Check gh CLI
    if ! command -v gh &>/dev/null; then
        err "GitHub CLI (gh) not found. Install: brew install gh"
    fi

    # Check gh auth
    if ! gh auth status &>/dev/null; then
        err "GitHub CLI not authenticated. Run: gh auth login"
    fi

    ok "Preflight passed"
}

# ─── Clone / Update repo ───
sync_repo() {
    if [[ -d "${REPO_DIR}/.git" ]]; then
        say "Updating existing repo..."
        git -C "${REPO_DIR}" fetch origin "${BRANCH}" --depth 1
        git -C "${REPO_DIR}" reset --hard "origin/${BRANCH}"
        ok "Repo updated"
    else
        say "Cloning repo..."
        mkdir -p "$(dirname "${REPO_DIR}")"
        gh repo clone "${REPO}" "${REPO_DIR}" -- --depth 1 --branch "${BRANCH}"
        ok "Repo cloned to ${REPO_DIR}"
    fi
}

# ─── Install to a platform ───
install_platform() {
    local platform=$1
    local target_dir=$2
    local source_dir="${REPO_DIR}/skills"

    say "Installing to ${platform} (${target_dir})..."
    mkdir -p "${target_dir}"

    # Copy engineering, productivity, misc buckets
    local count=0
    for bucket in engineering productivity misc personal; do
        local src="${source_dir}/${bucket}"
        if [[ -d "${src}" ]]; then
            for skill_dir in "${src}"/*/; do
                local skill_name=$(basename "${skill_dir}")
                local dst="${target_dir}/${skill_name}"

                # Skip if src has no SKILL.md
                if [[ ! -f "${skill_dir}SKILL.md" ]]; then
                    continue
                fi

                rm -rf "${dst}"
                cp -r "${skill_dir}" "${dst}"
                count=$((count + 1))
            done
        fi
    done

    ok "Installed ${count} skills to ${platform}"
}

# ─── Validate installation ───
validate() {
    say "Validating installations..."

    local errors=0

    # Hermes validation
    if [[ -d "${HERMES_SKILLS}" ]]; then
        local hermes_count=$(find "${HERMES_SKILLS}" -name "SKILL.md" -maxdepth 2 | wc -l | tr -d ' ')
        if [[ ${hermes_count} -gt 0 ]]; then
            ok "Hermes: ${hermes_count} skills found"
        else
            warn "Hermes: no skills found"
            errors=$((errors + 1))
        fi
    else
        warn "Hermes: skills directory not found (Hermes may not be installed)"
    fi

    # Claude Code validation
    if [[ -d "${CLAUDE_SKILLS}" ]]; then
        local claude_count=$(find "${CLAUDE_SKILLS}" -name "SKILL.md" -maxdepth 2 | wc -l | tr -d ' ')
        if [[ ${claude_count} -gt 0 ]]; then
            ok "Claude Code: ${claude_count} skills found"
        else
            warn "Claude Code: no skills found"
            errors=$((errors + 1))
        fi
    else
        warn "Claude Code: skills directory not found (Claude Code may not be installed)"
    fi

    # Codex validation
    if [[ -d "${CODEX_SKILLS}" ]]; then
        local codex_count=$(find "${CODEX_SKILLS}" -name "SKILL.md" -maxdepth 2 | wc -l | tr -d ' ')
        if [[ ${codex_count} -gt 0 ]]; then
            ok "Codex: ${codex_count} skills found"
        else
            warn "Codex: no skills found"
            errors=$((errors + 1))
        fi
    else
        warn "Codex: skills directory not found (Codex may not be installed)"
    fi

    if [[ ${errors} -gt 0 ]]; then
        say "Validation complete with ${YELLOW}${errors} warnings${NC}"
    else
        ok "All platforms validated"
    fi
}

# ─── Uninstall ───
uninstall() {
    say "Uninstalling matt-skills..."

    for platform_dir in "${HERMES_SKILLS}" "${CLAUDE_SKILLS}" "${CODEX_SKILLS}"; do
        if [[ -d "${platform_dir}" ]]; then
            # Only remove skill dirs that match our skill names
            local removed=0
            for bucket in engineering productivity misc personal; do
                local src="${REPO_DIR}/skills/${bucket}"
                if [[ -d "${src}" ]]; then
                    for skill_dir in "${src}"/*/; do
                        local skill_name=$(basename "${skill_dir}")
                        local dst="${platform_dir}/${skill_name}"
                        if [[ -d "${dst}" ]]; then
                            rm -rf "${dst}"
                            removed=$((removed + 1))
                        fi
                    done
                fi
            done
            if [[ ${removed} -gt 0 ]]; then
                ok "Removed ${removed} skills from ${platform_dir}"
            fi
        fi
    done

    # Remove repo cache
    if [[ -d "${REPO_DIR}" ]]; then
        rm -rf "${REPO_DIR}"
        ok "Removed repo cache at ${REPO_DIR}"
    fi

    ok "Uninstall complete"
}

# ─── Main ───
case "${ACTION}" in
    --uninstall|uninstall)
        preflight
        uninstall
        ;;
    install|--install|"")
        preflight
        sync_repo
        install_platform "Hermes" "${HERMES_SKILLS}"
        install_platform "Claude Code" "${CLAUDE_SKILLS}"
        install_platform "Codex" "${CODEX_SKILLS}"
        validate
        say ""
        say "🎉 Installation complete!"
        say ""
        say "Next steps:"
        say "  • Restart Hermes to pick up new skills"
        say "  • In Claude Code: the skills are auto-discovered"
        say "  • In Codex: skills are available on next session"
        say "  • Run with --uninstall to remove all installed skills"
        ;;
    *)
        echo "Usage: $0 [--uninstall]"
        exit 1
        ;;
esac
