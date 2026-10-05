#!/usr/bin/env bash
# Fetches the pinned Natural Earth source datasets into Data/source/.
#
# The repository already contains these files (Natural Earth is public
# domain and redistributable), so this script exists to make the
# provenance reproducible and verifiable, not because a build needs it.
# Nothing in the app downloads anything at runtime.
#
# Pinned sources:
#   - Natural Earth vector data, natural-earth-vector v5.1.2
#   - NASA Blue Marble: Next Generation surface imagery (Dec 2004)
# See docs/DATA_AND_LICENSES.md for licenses and attribution.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$REPO_ROOT/Data/source"
BASE="https://raw.githubusercontent.com/nvkelso/natural-earth-vector/v5.1.2/geojson"

mkdir -p "$DEST"

fetch() {
  local name="$1" expected="$2"
  echo "==> $name"
  curl --fail --silent --show-error --location --max-time 180 \
       --output "$DEST/$name" "$BASE/$name"
  local actual
  actual="$(shasum -a 256 "$DEST/$name" | awk '{print $1}')"
  if [ "$actual" != "$expected" ]; then
    echo "SHA-256 mismatch for $name" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
  echo "    sha256 ok ($actual)"
}

fetch ne_110m_admin_0_countries.geojson \
  6866c877d39cba9c357620878839b336d569f8c662d3cfab4cb1dbe2d39c977f
fetch ne_110m_populated_places.geojson \
  a86028b083182b68c7620fc6e1a8a47ee547cb9cd2fb62ccbb78bea786440899

# The surface imagery comes from NASA rather than Natural Earth, so it
# has its own base URL. It is public domain; NASA asks for credit, which
# the app gives in Settings > Data & Credits.
IMAGERY_NAME=world.topo.bathy.200412.3x5400x2700.jpg
IMAGERY_URL=https://eoimages.gsfc.nasa.gov/images/imagerecords/73000/73909/$IMAGERY_NAME
IMAGERY_SHA=a9f0088972dee0254610af851c4d6838ca3f2cf79176987e0a5713e2c15ec042

echo "==> $IMAGERY_NAME"
curl --fail --silent --show-error --location --max-time 900 \
     --output "$DEST/$IMAGERY_NAME" "$IMAGERY_URL"
IMAGERY_ACTUAL="$(shasum -a 256 "$DEST/$IMAGERY_NAME" | awk '{print $1}')"
if [ "$IMAGERY_ACTUAL" != "$IMAGERY_SHA" ]; then
  echo "SHA-256 mismatch for $IMAGERY_NAME" >&2
  echo "  expected: $IMAGERY_SHA" >&2
  echo "  actual:   $IMAGERY_ACTUAL" >&2
  exit 1
fi
echo "    sha256 ok ($IMAGERY_ACTUAL)"

echo
echo "Source data verified in Data/source/."
echo "Regenerate the runtime asset with: swift run AtlasDataTool"
