#!/bin/bash

SERVICES_FILE="/etc/nftables.d/services.json"
OUTPUT_FILE="/etc/nftables.d/service-ips.conf"

# Start generating nftables rules
cat > $OUTPUT_FILE <<'EOF'
#!/usr/sbin/nft -f

table ip monitor {
    chain services {
EOF

# Process each service from JSON
jq -r '.services | to_entries[] | @json' $SERVICES_FILE | while read -r service; do
    name=$(echo $service | jq -r '.key')
    display_name=$(echo $service | jq -r '.value.name')
    description=$(echo $service | jq -r '.value.description')
    
    echo "        # $description" >> $OUTPUT_FILE
    echo -n "        ip daddr {" >> $OUTPUT_FILE
    
    # Get IPs for each ASN
    echo $service | jq -r '.value.asn[]' | while read -r asn; do
        whois -h whois.radb.net -- "-i origin $asn" | \
        grep "^route:" | \
        awk '{print $2}' | \
        tr '\n' ','
    done | sed 's/,$//' >> $OUTPUT_FILE
    
    echo "} counter log prefix \"$display_name: \"" >> $OUTPUT_FILE
    echo "" >> $OUTPUT_FILE
done

# Close the nftables configuration
cat >> $OUTPUT_FILE <<'EOF'
    }
}
EOF

# Make executable and apply
chmod +x $OUTPUT_FILE
nft -f $OUTPUT_FILE

echo "Service rules generated successfully"
