#!/bin/bash

# Check if the correct number of arguments are provided
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <input_directory> <output_dump_file>"
  exit 1
fi

# Store input arguments in variables
input_directory="$1"
output_dump_file="$2"

# Empty or create the output dump file
> "$output_dump_file"

# Process each file in the input directory
for file in "${input_directory}"/*.csv; do
  # Extract the table name from the file name (remove .csv extension)
  table_name=$(basename "$file" .csv)

  # Read the header (field names) from the first line of the file
  header=$(head -n 1 "$file")

  # Remove the header line from the file to create a temporary file with data only
  tail -n +2 "$file" > "${file}_tmp"

  # Determine the data types of each field and create the table schema
  schema=""
  IFS=',' read -ra field_names <<< "$header"
  for field_name in "${field_names[@]}"; do
    # Get the first non-empty value for the current field
    value=$(awk -F, -v col="$((++col_num))" 'length($col) > 0 {print $col; exit}' "${file}_tmp")

    # Determine the data type based on the value
    if [[ "$value" =~ ^-?[0-9]+$ ]]; then
      data_type="INT"
    elif [[ "$value" =~ ^-?[0-9]*\.[0-9]+$ ]]; then
      data_type="FLOAT"
    else
      data_type="VARCHAR(255)"
    fi

    # Add the field definition to the schema
    schema="${schema}${field_name//\"} ${data_type}, "
  done

  # Remove the last comma and space from the schema
  schema=${schema%, }

  # Write the CREATE TABLE statement to the output dump file
  echo "CREATE TABLE IF NOT EXISTS ${table_name} (${schema});" >> "$output_dump_file"

  # Write the INSERT INTO statements to the output dump file
  while IFS= read -r line; do
    echo "INSERT INTO ${table_name} VALUES (${line});" >> "$output_dump_file"
  done < "${file}_tmp"

  # Remove the temporary data file
  rm "${file}_tmp"
done

# Print the result
echo "MySQL dump created in $output_dump_file"
