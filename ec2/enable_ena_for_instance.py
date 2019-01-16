#!/usr/local/bin/python3 -u

"""
This script creates a ENA-enabled copy of an AWS Instance after following instructions here:
https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/enhanced-networking.html
"""

import boto3
ec2 = boto3.resource('ec2')
client = boto3.client('ec2')


def create_snap(i_id: str) -> dict:
    """
    :param i_id: EC2 Instance ID
    :return: New Snapshot
    """
    print('Retrieving Volume ID...')
    instance = ec2.Instance(i_id)
    devices = instance.block_device_mappings
    for device in devices:
        if device['DeviceName'] == '/dev/sdb':
            print(f"Volume ID is {device['Ebs']['VolumeId']}")
            print('Creating Snapshot...')
            snap = client.create_snapshot(
                Description='HD_Image',
                VolumeId=device['Ebs']['VolumeId'],
            )
            ec2.Snapshot(snap['SnapshotId']).wait_until_completed()
            print(f"Snapshot: {snap['SnapshotId']} is now created.")
            return snap


def create_ami(name: str, snap: dict) -> dict:
    """
    :param name: Name of New AMI
    :param snap: Snapshot Info
    :return: New AMI
    """
    new_image = client.register_image(
        Name=name,
        Architecture='x86_64',
        EnaSupport=True,
        BlockDeviceMappings=[
            {
                'DeviceName': '/dev/sda1',
                "Ebs": {
                    'SnapshotId': snap['SnapshotId'],
                    'VolumeSize': snap['VolumeSize'],
                    'DeleteOnTermination': True,
                    'VolumeType': 'gp2'
                },
            }
        ],
        RootDeviceName='/dev/sda1',
        VirtualizationType='hvm'
    )
    return new_image['ImageId']


if __name__ == '__main__':
    aws_instance_id = ''
    new_ami_name = ''
    snapshot = create_snap(aws_instance_id)
    ami = create_ami(new_ami_name, snapshot)
    print(f"New AMI: {ami}")
