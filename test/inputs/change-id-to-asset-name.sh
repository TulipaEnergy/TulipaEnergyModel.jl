#!/bin/bash
# This script converts the ids to asset names. It should not be necessary in the future,
# but it serves as documentation of how it was done.

if [ $# -lt 1 ]; then
    echo "ERROR: Needs INPUT_FOLDER argument"
    exit 1
fi

INPUT_FOLDER=$1
ASSETS_DATA="$INPUT_FOLDER/assets-data.csv"
FLOWS_DATA="$INPUT_FOLDER/flows-data.csv"

# Read assets data and replace id for name
sed -i "s/^id,/asset,/g" "$INPUT_FOLDER/assets-partitions.csv" "$INPUT_FOLDER/assets-profiles.csv"
while IFS="," read -r id name rest; do
    # id happens on the first column
    sed -i "s/^$id,/$name,/g" "$INPUT_FOLDER/assets-partitions.csv" "$INPUT_FOLDER/assets-profiles.csv"
done < <(tail -n +3 "$ASSETS_DATA")

# Read flows data and replace id for (from, to)
sed -i "s/^id,/from_asset,to_asset,/g" "$INPUT_FOLDER/flows-partitions.csv" "$INPUT_FOLDER/flows-profiles.csv"
sed -i "s/^,/,,/g" "$INPUT_FOLDER/flows-partitions.csv" "$INPUT_FOLDER/flows-profiles.csv"
while IFS="," read -r id _ from to rest; do
    # id happens on the first column
    sed -i "s/^$id,/$from,$to,/g" "$INPUT_FOLDER/flows-partitions.csv" "$INPUT_FOLDER/flows-profiles.csv"
done < <(tail -n +3 "$FLOWS_DATA")

# Remove id column
sed -i 's/^[^,]*,//g' "$ASSETS_DATA" "$FLOWS_DATA"
