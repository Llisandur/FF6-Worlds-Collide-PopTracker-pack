#!/usr/bin/env nix-shell
#! nix-shell -i bash -p jq coreutils findutils gnused zopfli

# Save image hashes to JSON
Save_ImageHashes() {
  local output_path="$1"
  declare -n hashes_ref="$2"  # this avoids naming collision with image_hashes

  {
    echo "{"
    first=1
    for key in "${!hashes_ref[@]}"; do
      [[ $first -eq 0 ]] && echo ","
      first=0
      printf '  "%s": "%s"' "$key" "${hashes_ref[$key]}"
    done
    echo
    echo "}"
  } > "$output_path"
}


# Compress PNGs with zopflipng if hash has changed
Compress_Images() {
  local imagehash_path="./imagehash.json"
  declare -A image_hashes

  if [[ -f "$imagehash_path" ]]; then
    while IFS="=" read -r k v; do
      image_hashes["$k"]="$v"
    done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$imagehash_path")
  fi

  while IFS= read -r -d '' file; do
    local rel_path="${file#./src/}"
    rel_path="${rel_path//\\//}"
    local current_hash
    current_hash=$(sha256sum "$file" | awk '{print $1}')

    if [[ -n "${image_hashes[$rel_path]+_}" && "${image_hashes[$rel_path]}" == "$current_hash" ]]; then
      echo "Skipping $file, already compressed."
      continue
    fi

    local output_file="${file%.png}-compressed.png"
    echo "Compressing $file..."
    zopflipng --iterations=15 --filters=01234mepb --lossy_8bit --lossy_transparent "$file" "$output_file"
    mv "$output_file" "$file"

    new_hash=$(sha256sum "$file" | awk '{print $1}')
    image_hashes["$rel_path"]="$new_hash"
    Save_ImageHashes "$imagehash_path" image_hashes
  done < <(find ./src -type f -name '*.png' -print0)
}


# Remove comments and trailing commas from JSONC
Remove_JsonCComments() {
  local file_path="$1"
  sed -E -e 's@//.*$@@' -e '/\/\*/,/\*\//d' -e 's/,\s*([}\]])/\1/' "$file_path" > "$file_path.tmp"
  mv "$file_path.tmp" "$file_path"
}

# Minify JSON (strip whitespace)
Minify_Json() {
  local file_path="$1"
  tr -d '\n\r\t ' < "$file_path" > "$file_path.min"
  mv "$file_path.min" "$file_path"
}

# Copy build content, strip JSONC, and minify
Build_PackContent() {
  rm -rf ./bin/build
  cp -r ./src ./bin/build

  find ./bin/build -type f -name "*.jsonc" | while read -r file; do
    Remove_JsonCComments "$file"
    Minify_Json "$file"
    mv "$file" "${file%.jsonc}.json"
  done

  local init_lua="./bin/build/scripts/init.lua"
  if [[ -f "$init_lua" ]]; then
    sed -i 's/jsonc/json/g' "$init_lua"
  fi
}
