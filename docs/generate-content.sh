#!/bin/bash
set -euo pipefail

# Generate Hugo content from scripts/*/README.md
# This script is intended to be run from the repository root.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOCS_DIR="${REPO_ROOT}/docs"
CONTENT_DIR="${DOCS_DIR}/content/filters"
SCRIPTS_DIR="${REPO_ROOT}/scripts"
GITHUB_REPO_URL="https://github.com/pepabo/alive-project-obs-plugins"
LICENSE_URL="${GITHUB_REPO_URL}/blob/main/LICENSE"

# Clean and recreate content directory
rm -rf "${CONTENT_DIR}"
mkdir -p "${CONTENT_DIR}"

# Copy logo to static assets
mkdir -p "${DOCS_DIR}/static/assets"
cp "${REPO_ROOT}/assets/alive-studio-logo.webp" "${DOCS_DIR}/static/assets/"

for filter_dir in "${SCRIPTS_DIR}"/*/; do
  filter_name="$(basename "${filter_dir}")"
  readme="${filter_dir}/README.md"

  if [ ! -f "${readme}" ]; then
    echo "SKIP: ${filter_name} (no README.md)"
    continue
  fi

  echo "Processing: ${filter_name}"

  # Create page bundle directory
  bundle_dir="${CONTENT_DIR}/${filter_name}"
  mkdir -p "${bundle_dir}"

  # Extract title from first line (e.g., "# 🎭 スポットライト")
  title="$(head -1 "${readme}" | sed 's/^# *//' | sed 's/"/\\"/g')"

  # Extract description: first non-empty line after the # heading
  description="$(awk 'NR>1 && /^.+$/ {print; exit}' "${readme}" | sed 's/"/\\"/g')"

  # Extract the first image filename referenced in the README (e.g., ./screenshot.png)
  thumbnail="$(grep -oE '\!\[.*\]\(\./[^)]+\.(png|gif)\)' "${readme}" | head -1 | sed 's/.*(\.\///; s/)//' || true)"

  # Read README content (skip the first line since Hugo will use front matter title)
  content="$(tail -n +2 "${readme}")"

  # Apply path transformations
  # ../../assets/alive-studio-logo.webp -> /alive-project-obs-plugins/assets/alive-studio-logo.webp
  content="$(echo "${content}" | sed 's|../../assets/alive-studio-logo.webp|/alive-project-obs-plugins/assets/alive-studio-logo.webp|g')"

  # ../../LICENSE -> GitHub LICENSE URL
  content="$(echo "${content}" | sed "s|../../LICENSE|${LICENSE_URL}|g")"

  # GitHub user-attachments video URLs -> <video> tags
  content="$(echo "${content}" | sed -E 's|^https://github\.com/user-attachments/assets/[a-zA-Z0-9-]+$|<video src="&" controls playsinline muted loop style="max-width:100%;height:auto;"></video>|')"

  # Write index.md with front matter
  # Build thumbnail front matter line
  thumbnail_line=""
  if [ -n "${thumbnail}" ]; then
    thumbnail_line="thumbnail: \"${thumbnail}\""
  fi

  cat > "${bundle_dir}/index.md" <<EOF
---
title: "${title}"
description: "${description}"
${thumbnail_line}
---
${content}
EOF

  # Copy image files (.png, .gif) to the page bundle
  for img in "${filter_dir}"*.png "${filter_dir}"*.gif; do
    if [ -f "${img}" ]; then
      cp "${img}" "${bundle_dir}/"
    fi
  done
done

echo "Content generation complete."
