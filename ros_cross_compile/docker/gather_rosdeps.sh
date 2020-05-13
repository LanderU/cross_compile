#!/bin/bash
set -euxo pipefail

if [ ! -d ./src ]; then
  echo "No src/ directory found at $(pwd), did you remember to mount your workspace?"
  exit 1
fi

if [ -f "${CUSTOM_SETUP}" ]; then
  chmod +x "${CUSTOM_SETUP}"
  pushd "$(dirname "${CUSTOM_SETUP}")"
  "${CUSTOM_SETUP}"
  popd
fi

out_dir=$(dirname "${OUT_PATH}")
mkdir -p "${out_dir}"

rosdep update

cat > "${OUT_PATH}" <<EOF
#!/bin/bash
set -euxo pipefail
EOF

mapfile -t package_paths < <(colcon list -p)

rosdep install \
    --os "${TARGET_OS}" \
    --rosdistro "${ROSDISTRO}" \
    --from-paths "${package_paths[@]}" \
    --ignore-src \
    --reinstall \
    --default-yes \
    --skip-keys "${SKIP_ROSDEP_KEYS}" \
    --simulate \
  >> /tmp/all-deps.sh

# Find the non-apt lines and move them as-is to the final script
grep -v "apt-get install -y" /tmp/all-deps.sh >> ${OUT_PATH}

# Find all apt-get lines from the rosdep output
# As an optimization, we will combine all such commands into a single command, which saves time
grep "apt-get install -y" /tmp/all-deps.sh > /tmp/apt-deps.sh
# package_names ends up containing a set of space-separated package names
# (fourth column is the name, after ["apt-get", "install", "-y"])
package_names=$(cat /tmp/apt-deps.sh | awk '{print $4}' ORS=' ')
echo "apt-get install -y ${package_names}" >> ${OUT_PATH}

chmod +x "${OUT_PATH}"
chown -R "${OWNER_USER}" "${out_dir}"
