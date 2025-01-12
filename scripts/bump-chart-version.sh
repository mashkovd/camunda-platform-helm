#!/bin/bash
set -euo pipefail

print_help () {
cat << EOF
Usage:
    $0 [chart-name]

Details:
    A simple script to bump the chart version.
    Updating the Chart.yaml version will trigger Helm release with the new version.

Notes:
    Default value for 'chart-name' is 'camunda-platform'.
EOF
}

if [ "${1:-''}" == '-h' ]; then
  print_help
  exit 1
fi

# Chart name is hard-coded since we only have 1 main chart,
# but it could be customized in case we have more in the future.
chart_name="camunda-platform"

# When changing the minor version, export "is_minor_version=1",
# that will increment the minor version and set the patch version to zero.
is_minor_version="${is_minor_version:-0}"

# Generate new version based on the old one.
chart_version_old=$(grep -Po "(?<=^version: ).+" charts/${chart_name}/Chart.yaml)
chart_version_new=$(echo "${chart_version_old}" |
    awk -F '.' -v OFS='.' -v is_minor_version=${is_minor_version} \
      '{
        if (is_minor_version) {
          printf "%d.%d.0", $1, $2+1, $3
        } else {
          $NF += 1; print;
        }
      }'
)

# Update the appVersion in parent chart in case it's a minor release.
if [[ ${is_minor_version} -eq 1 ]]; then
    chart_version_new_minor=$(echo "${chart_version_new%.0}.x")
    sed -i "s/^appVersion: 8.*/appVersion: ${chart_version_new_minor}/g" charts/${chart_name}/Chart.yaml
fi

# Update parent chart version
sed -i "s/version: ${chart_version_old}/version: ${chart_version_new}/g" charts/${chart_name}/Chart.yaml

# Update subcharts version.
sed -i "s/^version: ${chart_version_old}/version: ${chart_version_new}/g" charts/${chart_name}/charts/*/Chart.yaml

# Print the changes.
echo "The chart '${chart_name}' version has been bumped from '${chart_version_old}' to '${chart_version_new}'."
