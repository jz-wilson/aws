#!/bin/bash
 
set -e
 
REGION=us-east-1
ORPHANED_SNAPSHOTS_COUNT_LIMIT=10
WORK_DIR=/tmp

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)

aws ec2 --region $REGION describe-snapshots --owner-ids $AWS_ACCOUNT_ID --query Snapshots[*].SnapshotId --output text | tr '\t' '\n' | sort > $WORK_DIR/all_snapshots
aws ec2 --region $REGION describe-images --filters Name=state,Values=available --owners $AWS_ACCOUNT_ID --query "Images[*].BlockDeviceMappings[*].Ebs.SnapshotId" --output text | tr '\t' '\n' | sort > $WORK_DIR/snapshots_attached_to_ami
 
ORPHANED_SNAPSHOT_IDS=$(comm -23 <(sort $WORK_DIR/all_snapshots) <(sort $WORK_DIR/snapshots_attached_to_ami))
 
if [ -z "$ORPHANED_SNAPSHOT_IDS" ]; then
  echo "OK - no orphaned (not attached to any AMI) snapshots found"
  exit 
fi
 
ORPHANED_SNAPSHOT_IDS=$(echo "$ORPHANED_SNAPSHOT_IDS" | grep "snap")
 
ORPHANED_SNAPSHOTS_COUNT=$(echo "$ORPHANED_SNAPSHOT_IDS" | wc -l)
 
if (( ORPHANED_SNAPSHOTS_COUNT > ORPHANED_SNAPSHOTS_COUNT_LIMIT )); then
  echo "CRITICAL - $ORPHANED_SNAPSHOTS_COUNT orphaned (not attached to any AMI) snapshots found: [ $ORPHANED_SNAPSHOT_IDS ]"
  echo "To delete them, use commands below:"
  IFS=$'\n'
  for snapshot_id in $ORPHANED_SNAPSHOT_IDS; do echo "aws ec2 --region $REGION delete-snapshot --snapshot-id $snapshot_id"; done
  exit 1
else
  echo "OK - $ORPHANED_SNAPSHOTS_COUNT orphaned (not attached to any AMI) snapshots found"
  if (( ORPHANED_SNAPSHOTS_COUNT >  )); then
    echo "[ $ORPHANED_SNAPSHOT_IDS ]"
  fi
  exit 
fi