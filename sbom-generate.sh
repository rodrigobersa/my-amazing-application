#!/bin/bash

# Set the project name and version
PROJECT_NAME="my-amazing-application"
PROJECT_VERSION="1.0.0"

# Path to requirements.txt
REQUIREMENTS_FILE="requirements.txt"

# Function to generate a simple unique identifier
generate_uuid() {
    od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
}

# Get the current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Generate the SBOM
cat << EOF > sbom.json
{
  "bomFormat": "CycloneDX",
  "specVersion": "1.4",
  "serialNumber": "urn:uuid:$(generate_uuid)",
  "version": 1,
  "metadata": {
    "timestamp": "$TIMESTAMP",
    "tools": [
      {
        "vendor": "UnicorCompany",
        "name": "SBOM Generator",
        "version": "1.0.0"
      }
    ],
    "component": {
      "type": "application",
      "name": "$PROJECT_NAME",
      "version": "$PROJECT_VERSION"
    }
  },
  "components": [
EOF

# Read requirements.txt and format dependencies as SBOM components
first=true
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^#.*$ ]] && continue

    # Extract package name and version
    if [[ "$line" =~ ^([^=><~!]+)([=><~!]=?.*)?$ ]]; then
        name="${BASH_REMATCH[1]}"
        version="${BASH_REMATCH[2]}"
        
        # Remove any leading/trailing whitespace
        name=$(echo "$name" | awk '{$1=$1};1')
        version=$(echo "$version" | awk '{$1=$1};1')

        # If no version is specified, use "latest"
        [[ -z "$version" ]] && version="latest"

        # Add comma for all but the first entry
        if $first; then
            first=false
        else
            echo "    }," >> sbom.json
        fi

        cat << EOF >> sbom.json
    {
      "type": "library",
      "name": "$name",
      "version": "$version",
      "purl": "pkg:pypi/$name@$version"
EOF
    fi
done < "$REQUIREMENTS_FILE"

# Close the last component and the JSON structure
cat << EOF >> sbom.json
    }
  ]
}
EOF

echo "SBOM generated as sbom.json"