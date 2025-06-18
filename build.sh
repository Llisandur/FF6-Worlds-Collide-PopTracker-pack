#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq zip coreutils findutils gnused zopfli

# Usage: ./build.sh [-v version] [-c changelog] [--skipcompression]

set -euo pipefail

# Parse arguments
version=""
changelog=""
skipcompression=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--version)
      version="$2"
      shift 2
      ;;
    -c|--changelog)
      changelog="$2"
      shift 2
      ;;
    --skipcompression)
      skipcompression=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

source ./buildfunctions.sh

if [[ "$skipcompression" = false ]]; then
  echo "Compressing images..."
  Compress_Images
else
  echo "Skipping image compression."
fi

mkdir -p ./bin

filename="ff6wc-ap-tracker.zip"
if [[ -n "$version" ]]; then
  filename="ff6wc-ap-tracker-$version.zip"

  manifest_path="./src/manifest.json"
  jq --arg ver "$version" '.package_version = $ver' "$manifest_path" > "$manifest_path.tmp"
  mv "$manifest_path.tmp" "$manifest_path"
fi

echo "Building poptracker pack..."
Build_PackContent

if [[ -f "./bin/$filename" ]]; then
  rm -f "./bin/$filename"
fi

cd ./bin/build
zip -r "../$filename" ./*
cd -

echo "Build complete. Output: ./bin/$filename"

if [[ -n "$version" ]]; then
  sha256=$(sha256sum "./bin/$filename" | awk '{print $1}')
  echo "SHA256: $sha256"

  versions_path="./versions.json"
  tmp_versions=$(mktemp)

  jq --arg ver "$version" \
     --arg url "https://github.com/llisandur/ff6-worlds-collide-poptracker-pack/releases/download/$version/ff6wc-ap-tracker-$version.zip" \
     --arg sha "$sha256" \
     --argjson changelog "[$(jq -Rs <<<"$changelog")]" \
     '.versions |= [{"package_version": $ver, "download_url": $url, "sha256": $sha, "changelog": $changelog}] + .' \
     "$versions_path" > "$tmp_versions" && mv "$tmp_versions" "$versions_path"

  echo -e "\nVersioning complete! Next steps:\n"
  echo "- Commit and push all files except ./versions.json"
  echo "- Create GitHub release and upload $filename"
  echo "- Then commit and push ./versions.json"
fi
