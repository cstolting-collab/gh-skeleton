#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
temporary_directory=$(mktemp -d)

cleanup() {
  rm -rf "${temporary_directory}"
}

trap cleanup EXIT

mock_bin="${temporary_directory}/bin"
mkdir -p "${mock_bin}"

cat > "${mock_bin}/gh" << 'EOF'
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

if [[ "${1:-}" == "api" && "${2:-}" == "user" ]]; then
  echo "test-user"
elif [[ " $* " == *" --input - "* ]]; then
  cat > /dev/null
fi
EOF

cat > "${mock_bin}/git" << 'EOF'
#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

if [[ "${1:-}" == "clone" ]]; then
  destination="${!#}"
  mkdir -p "${destination}/.github/workflows" "${destination}/meta"
  printf '%s\n' 'cisagov/skeleton-parent skeleton-parent' > "${destination}/README.md"
  printf '%s\n' 'cisagov/skeleton-parent skeleton-parent' > "${destination}/CONTRIBUTING.md"
  printf '%s\n' 'cisagov/skeleton-parent skeleton-parent' > "${destination}/.github/workflows/build.yml"
  printf '%s\n' 'cisagov/skeleton-parent skeleton-parent' > "${destination}/meta/requirements.yml"
fi
EOF

chmod +x "${mock_bin}/gh" "${mock_bin}/git"

(
  cd "${temporary_directory}"
  PATH="${mock_bin}:${PATH}" bash "${repo_root}/gh-skeleton" clone skeleton-parent child-repo
)

child_repository="${temporary_directory}/child-repo"

assert_contains() {
  local expected=$1
  local file=$2

  if ! grep --fixed-strings --quiet "${expected}" "${file}"; then
    echo "Expected '${file}' to contain '${expected}'." >&2
    exit 1
  fi
}

assert_contains 'cisagov/child-repo child-repo' "${child_repository}/README.md"
assert_contains 'cisagov/child-repo child-repo' "${child_repository}/CONTRIBUTING.md"
assert_contains 'cisagov/child-repo child-repo' "${child_repository}/.github/workflows/build.yml"
assert_contains 'cisagov/skeleton-parent skeleton-parent' "${child_repository}/meta/requirements.yml"

echo "PASS: repository references are only replaced in project metadata."
