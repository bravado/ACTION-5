#!/usr/bin/env bash
# Install pinned official Godot binary + only Linux/Web standard export templates.
set -euo pipefail

version="4.7.2"
tag="${version}-stable"
base="https://github.com/godotengine/godot-builds/releases/download/${tag}"
download_dir="${RUNNER_TEMP:-/tmp}/action5-godot"
mkdir -p "${download_dir}"
binary_zip="${download_dir}/Godot_v${tag}_linux.x86_64.zip"
template_zip="${download_dir}/Godot_v${tag}_export_templates.tpz"

download() {
  local url="$1" output="$2"
  curl --fail --location --retry 5 --retry-all-errors --retry-delay 3 \
    --connect-timeout 20 --output "${output}" "${url}"
  test -s "${output}"
}

download "${base}/Godot_v${tag}_linux.x86_64.zip" "${binary_zip}"
unzip -q -o "${binary_zip}" -d "${download_dir}/editor"
sudo install -m 0755 "${download_dir}/editor/Godot_v${tag}_linux.x86_64" /usr/local/bin/godot
godot --headless --version
godot --headless --version | grep -q '^4\.7\.2\.'

# This official archive is ~1.3 GiB. Extract only required templates to limit disk usage.
download "${base}/Godot_v${tag}_export_templates.tpz" "${template_zip}"
extract_dir="${download_dir}/selected-templates"
mkdir -p "${extract_dir}"
unzip -q -o "${template_zip}" \
  "templates/version.txt" \
  "templates/linux_release.x86_64" \
  "templates/web_release.zip" \
  "templates/web_debug.zip" \
  -d "${extract_dir}"
destination="${HOME}/.local/share/godot/export_templates/${version}.stable"
mkdir -p "${destination}"
cp -a "${extract_dir}/templates/." "${destination}/"
for name in version.txt linux_release.x86_64 web_release.zip web_debug.zip; do
  test -s "${destination}/${name}" || { echo "Missing export template: ${name}" >&2; exit 1; }
done
echo "ACTION5_GODOT_SETUP_OK version=${version} templates=${destination}"
