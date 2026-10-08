#!/bin/sh
# Rebuilds the steam tables in a checkout of mobileapp_thermcalc_data and copies them into ThermoKit.
# Usage: ThermoKit/Scripts/update-tables.sh path/to/mobileapp_thermcalc_data
set -eu
data_repo="${1:?usage: $0 path/to/mobileapp_thermcalc_data}"
here="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$data_repo/build_tables.py"
cp "$data_repo"/steam/*.csv "$here/Sources/ThermoKit/Resources/steam/"
echo "Copied tables into $here/Sources/ThermoKit/Resources/steam"
