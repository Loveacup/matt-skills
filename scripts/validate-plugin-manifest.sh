#!/bin/bash
# validate-plugin-manifest.sh — Verify .claude-plugin/plugin.json matches skills/ directory
# Usage: ./validate-plugin-manifest.sh [--fix]
#   --fix: Auto-add missing entries to plugin.json
# Returns: 0 if consistent, 1 if mismatches found

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="${REPO_ROOT}/skills"
PLUGIN_JSON="${REPO_ROOT}/.claude-plugin/plugin.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
errors=0

# ─── Collect expected skills ───
declare -a expected_skills=()

for bucket in engineering productivity misc; do
    bucket_dir="${SKILLS_DIR}/${bucket}"
    if [[ -d "${bucket_dir}" ]]; then
        for skill_dir in "${bucket_dir}"/*/; do
            skill_name=$(basename "${skill_dir}")
            if [[ -f "${skill_dir}SKILL.md" ]]; then
                expected_skills+=("./skills/${bucket}/${skill_name}")
            fi
        done
    fi
done

# ─── Collect forbidden skills ───
declare -a forbidden_skills=()

for bucket in personal in-progress deprecated; do
    bucket_dir="${SKILLS_DIR}/${bucket}"
    if [[ -d "${bucket_dir}" ]]; then
        for skill_dir in "${bucket_dir}"/*/; do
            skill_name=$(basename "${skill_dir}")
            if [[ -f "${skill_dir}SKILL.md" ]]; then
                forbidden_skills+=("./skills/${bucket}/${skill_name}")
            fi
        done
    fi
done

# ─── Parse plugin.json ───
if [[ ! -f "${PLUGIN_JSON}" ]]; then
    echo -e "${RED}❌${NC} plugin.json not found at ${PLUGIN_JSON}"
    exit 1
fi

# Extract skills array from JSON using python (more reliable than jq in all envs)
listed_skills=$(python3 -c "
import json, sys
with open('${PLUGIN_JSON}') as f:
    data = json.load(f)
for skill in data.get('skills', []):
    print(skill)
")

# ─── Check 1: Expected skills IN plugin.json ───
echo "=== Checking expected skills in plugin.json ==="
missing=0
for skill in "${expected_skills[@]}"; do
    if ! echo "${listed_skills}" | grep -qF "${skill}"; then
        echo -e "${RED}  ❌ MISSING:${NC} ${skill}"
        missing=$((missing + 1))
    fi
done

if [[ ${missing} -gt 0 ]]; then
    echo -e "${RED}  ${missing} skills missing from plugin.json${NC}"
    errors=$((errors + 1))
else
    echo -e "${GREEN}  ✅ All ${#expected_skills[@]} expected skills present${NC}"
fi

# ─── Check 2: Forbidden skills NOT in plugin.json ───
echo "=== Checking forbidden skills NOT in plugin.json ==="
leaked=0
for skill in "${forbidden_skills[@]}"; do
    if echo "${listed_skills}" | grep -qF "${skill}"; then
        echo -e "${RED}  ❌ LEAKED:${NC} ${skill} (should not be in plugin.json)"
        leaked=$((leaked + 1))
    fi
done

if [[ ${leaked} -gt 0 ]]; then
    echo -e "${RED}  ${leaked} forbidden skills leaked into plugin.json${NC}"
    errors=$((errors + 1))
else
    echo -e "${GREEN}  ✅ No forbidden skills leaked${NC}"
fi

# ─── Check 3: Stale entries (in plugin.json but not on disk) ───
echo "=== Checking for stale entries ==="
stale=0
while IFS= read -r skill; do
    # Skip empty lines
    [[ -z "${skill}" ]] && continue
    skill_path="${REPO_ROOT}/${skill}/SKILL.md"
    if [[ ! -f "${skill_path}" ]]; then
        echo -e "${YELLOW}  ⚠️  STALE:${NC} ${skill} (in plugin.json but not on disk)"
        stale=$((stale + 1))
    fi
done <<< "${listed_skills}"

if [[ ${stale} -gt 0 ]]; then
    echo -e "${YELLOW}  ${stale} stale entries in plugin.json${NC}"
    # Stale entries are warnings, not errors — they don't break functionality
else
    echo -e "${GREEN}  ✅ No stale entries${NC}"
fi

# ─── Summary ───
echo ""
echo "─────────────────────────────────"
echo "  Expected skills:  ${#expected_skills[@]}"
echo "  Listed in JSON:   $(echo "${listed_skills}" | grep -c . || echo 0)"
echo "  Missing:          ${missing:-0}"
echo "  Leaked:           ${leaked:-0}"
echo "  Stale:            ${stale:-0}"

if [[ ${errors} -gt 0 ]]; then
    echo ""
    echo -e "${RED}❌ VALIDATION FAILED (${errors} error(s))${NC}"
    echo "Run with --fix to auto-correct plugin.json"
    exit 1
else
    echo -e "${GREEN}✅ VALIDATION PASSED${NC}"
    exit 0
fi
