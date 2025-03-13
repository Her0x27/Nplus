#!/bin/bash

TEMP_DIR="/tmp/service-ips"
OUTPUT_FILE="/etc/nftables.d/service-ips.conf"
SERVICES_FILE="/etc/nftables.d/services.json"

mkdir -p $TEMP_DIR

# Function to fetch and process IP ranges
fetch_ips() {
    local service=$1
    local asn=$2
    whois -h whois.radb.net -- "-i origin $asn" | grep "^route:" | awk '{print $2}' | sort -u >> "$TEMP_DIR/$service.txt"
}

# Process services from JSON
process_services() {
    local services=$(jq -r '.services | keys[]' $SERVICES_FILE)
    
    for service in $services; do
        echo "Processing $service..."
        > "$TEMP_DIR/$service.txt"
        
        local asns=$(jq -r ".services.$service.asn[]" $SERVICES_FILE)
        for asn in $asns; do
            fetch_ips "$service" "$asn"
        done
    done
}

# Generate nftables configuration
generate_config() {
    cat > $OUTPUT_FILE <<EOF
chain services {
EOF
    
    local services=$(jq -r '.services | keys[]' $SERVICES_FILE)
    for service in $services; do
        local name=$(jq -r ".services.$service.name" $SERVICES_FILE)
        local desc=$(jq -r ".services.$service.description" $SERVICES_FILE)
        
        echo "    # $desc" >> $OUTPUT_FILE
        echo "    ip daddr { $(cat $TEMP_DIR/$service.txt | tr '\n' ',' | sed 's/,$//')} counter log prefix \"$name: \"" >> $OUTPUT_FILE
        echo "" >> $OUTPUT_FILE
    done
    
    echo "}" >> $OUTPUT_FILE
}

# Main execution
process_services
generate_config
nft -f /etc/nftables.conf

echo "Service IP ranges updated successfully"
