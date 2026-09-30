#!/bin/bash
TARGET_AMI_NAME="nexus-app"

REGIONS=("us-east-1" "us-east-2" "us-west-1" "us-west-2")

for region in "${REGIONS[@]}"; do
    echo "Processing region: $region"
    
    AMI_ID=$(aws ec2 describe-images \
        --region "$region" \
        --owners self \
        --filters "Name=name,Values=$TARGET_AMI_NAME" \
        --query "Images[0].ImageId" \
        --output text 2>/dev/null)

    if [ "$AMI_ID" != "None" ] && [ -n "$AMI_ID" ]; then
        echo "Found AMI $AMI_ID in $region. Deregistering and deleting snapshots..."
        
        # Deregister and auto-delete associated EBS snapshots
        aws ec2 deregister-image \
            --region "$region" \
            --image-id "$AMI_ID" \
            --delete-associated-snapshots
    else
        echo "No matching AMI found in $region."
    fi
done
