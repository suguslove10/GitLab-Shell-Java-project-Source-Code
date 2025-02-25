#!/bin/bash
# Idempotent EKS cluster creation script

set -e  # Exit immediately if a command fails

# Step 1: Define variables
CLUSTER_NAME="my-eks-cluster"
REGION="us-east-1"
VPC_CIDR="10.0.0.0/16"
SUBNET1_CIDR="10.0.1.0/24"
SUBNET2_CIDR="10.0.2.0/24"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_ROLE_NAME="eks-cluster-role-$CLUSTER_NAME"
NODE_ROLE_NAME="eks-node-role-$CLUSTER_NAME"

echo "Setting up EKS cluster: $CLUSTER_NAME in region $REGION"

# Check if cluster already exists
if aws eks describe-cluster --name $CLUSTER_NAME --region $REGION 2>/dev/null; then
    echo "EKS cluster $CLUSTER_NAME already exists."
    
    # Update kubeconfig in case it's not already configured
    aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION
    
    echo "Kubeconfig updated. You can use kubectl to interact with your cluster."
    echo "Try running: kubectl get nodes"
    exit 0
fi

# Step 2: Check and create VPC if it doesn't exist
echo "Checking VPC..."
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=eks-vpc-$CLUSTER_NAME" --region $REGION --query "Vpcs[0].VpcId" --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo "Creating VPC..."
    VPC_ID=$(aws ec2 create-vpc --cidr-block $VPC_CIDR --region $REGION --output json | jq -r '.Vpc.VpcId')
    aws ec2 create-tags --resources $VPC_ID --tags Key=Name,Value="eks-vpc-$CLUSTER_NAME"
else
    echo "VPC already exists with ID: $VPC_ID"
fi

# Check and create subnets if they don't exist
echo "Checking subnets..."
SUBNET1_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=eks-subnet-1-$CLUSTER_NAME" --region $REGION --query "Subnets[0].SubnetId" --output text)
SUBNET2_ID=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=eks-subnet-2-$CLUSTER_NAME" --region $REGION --query "Subnets[0].SubnetId" --output text)

if [ "$SUBNET1_ID" = "None" ] || [ -z "$SUBNET1_ID" ]; then
    echo "Creating subnet 1..."
    SUBNET1_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET1_CIDR --availability-zone ${REGION}a --region $REGION --output json | jq -r '.Subnet.SubnetId')
    aws ec2 create-tags --resources $SUBNET1_ID --tags Key=Name,Value="eks-subnet-1-$CLUSTER_NAME"
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET1_ID --map-public-ip-on-launch
else
    echo "Subnet 1 already exists with ID: $SUBNET1_ID"
fi

if [ "$SUBNET2_ID" = "None" ] || [ -z "$SUBNET2_ID" ]; then
    echo "Creating subnet 2..."
    SUBNET2_ID=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block $SUBNET2_CIDR --availability-zone ${REGION}b --region $REGION --output json | jq -r '.Subnet.SubnetId')
    aws ec2 create-tags --resources $SUBNET2_ID --tags Key=Name,Value="eks-subnet-2-$CLUSTER_NAME"
    aws ec2 modify-subnet-attribute --subnet-id $SUBNET2_ID --map-public-ip-on-launch
else
    echo "Subnet 2 already exists with ID: $SUBNET2_ID"
fi

# Check and create internet gateway if it doesn't exist
echo "Checking Internet Gateway..."
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=eks-igw-$CLUSTER_NAME" --region $REGION --query "InternetGateways[0].InternetGatewayId" --output text)

if [ "$IGW_ID" = "None" ] || [ -z "$IGW_ID" ]; then
    echo "Creating Internet Gateway..."
    IGW_ID=$(aws ec2 create-internet-gateway --region $REGION --output json | jq -r '.InternetGateway.InternetGatewayId')
    aws ec2 create-tags --resources $IGW_ID --tags Key=Name,Value="eks-igw-$CLUSTER_NAME"
    
    # Check if the internet gateway is already attached
    ATTACHED_VPC=$(aws ec2 describe-internet-gateways --internet-gateway-ids $IGW_ID --query "InternetGateways[0].Attachments[0].VpcId" --output text)
    
    if [ "$ATTACHED_VPC" = "None" ] || [ -z "$ATTACHED_VPC" ]; then
        echo "Attaching Internet Gateway to VPC..."
        aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID --region $REGION
    fi
else
    echo "Internet Gateway already exists with ID: $IGW_ID"
fi

# Check and create route table if it doesn't exist
echo "Checking route table..."
RTB_ID=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=eks-rtb-$CLUSTER_NAME" --region $REGION --query "RouteTables[0].RouteTableId" --output text)

if [ "$RTB_ID" = "None" ] || [ -z "$RTB_ID" ]; then
    echo "Creating route table..."
    RTB_ID=$(aws ec2 create-route-table --vpc-id $VPC_ID --region $REGION --output json | jq -r '.RouteTable.RouteTableId')
    aws ec2 create-tags --resources $RTB_ID --tags Key=Name,Value="eks-rtb-$CLUSTER_NAME"
    
    # Create route to IGW
    aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
    
    # Associate route table with subnets
    aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $SUBNET1_ID --region $REGION
    aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $SUBNET2_ID --region $REGION
else
    echo "Route table already exists with ID: $RTB_ID"
    
    # Check if route to IGW exists
    ROUTE_EXISTS=$(aws ec2 describe-route-tables --route-table-ids $RTB_ID --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" --output text)
    
    if [ -z "$ROUTE_EXISTS" ]; then
        echo "Creating route to Internet Gateway..."
        aws ec2 create-route --route-table-id $RTB_ID --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID --region $REGION
    fi
    
    # Check subnet associations
    SUBNET1_ASSOCIATED=$(aws ec2 describe-route-tables --route-table-ids $RTB_ID --query "RouteTables[0].Associations[?SubnetId=='$SUBNET1_ID'].SubnetId" --output text)
    SUBNET2_ASSOCIATED=$(aws ec2 describe-route-tables --route-table-ids $RTB_ID --query "RouteTables[0].Associations[?SubnetId=='$SUBNET2_ID'].SubnetId" --output text)
    
    if [ -z "$SUBNET1_ASSOCIATED" ]; then
        echo "Associating subnet 1 with route table..."
        aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $SUBNET1_ID --region $REGION
    fi
    
    if [ -z "$SUBNET2_ASSOCIATED" ]; then
        echo "Associating subnet 2 with route table..."
        aws ec2 associate-route-table --route-table-id $RTB_ID --subnet-id $SUBNET2_ID --region $REGION
    fi
fi

# Check and create security group if it doesn't exist
echo "Checking security group..."
SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=eks-sg-$CLUSTER_NAME" "Name=vpc-id,Values=$VPC_ID" --region $REGION --query "SecurityGroups[0].GroupId" --output text)

if [ "$SG_ID" = "None" ] || [ -z "$SG_ID" ]; then
    echo "Creating security group..."
    SG_ID=$(aws ec2 create-security-group --group-name eks-sg-$CLUSTER_NAME --description "Security group for EKS cluster" --vpc-id $VPC_ID --region $REGION --output json | jq -r '.GroupId')
    aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 0.0.0.0/0 --region $REGION
else
    echo "Security group already exists with ID: $SG_ID"
fi

# Check and create IAM roles if they don't exist
echo "Checking IAM roles..."

# Cluster role
CLUSTER_ROLE_EXISTS=$(aws iam get-role --role-name $CLUSTER_ROLE_NAME 2>/dev/null || echo "false")
if [ "$CLUSTER_ROLE_EXISTS" = "false" ]; then
    echo "Creating cluster IAM role..."
    aws iam create-role --role-name $CLUSTER_ROLE_NAME --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "eks.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'
    aws iam attach-role-policy --role-name $CLUSTER_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
    
    # Wait for role propagation
    echo "Waiting for IAM role propagation..."
    sleep 15
else
    echo "Cluster IAM role already exists."
fi

# Node role
NODE_ROLE_EXISTS=$(aws iam get-role --role-name $NODE_ROLE_NAME 2>/dev/null || echo "false")
if [ "$NODE_ROLE_EXISTS" = "false" ]; then
    echo "Creating node IAM role..."
    aws iam create-role --role-name $NODE_ROLE_NAME --assume-role-policy-document '{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": "ec2.amazonaws.com"
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }'
    aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
    aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
    aws iam attach-role-policy --role-name $NODE_ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
    
    # Wait for role propagation
    echo "Waiting for IAM role propagation..."
    sleep 15
else
    echo "Node IAM role already exists."
fi

# Create EKS cluster
echo "Creating EKS cluster (this will take 10-15 minutes)..."
aws eks create-cluster \
  --name $CLUSTER_NAME \
  --role-arn arn:aws:iam::$ACCOUNT_ID:role/$CLUSTER_ROLE_NAME \
  --resources-vpc-config subnetIds=$SUBNET1_ID,$SUBNET2_ID,securityGroupIds=$SG_ID \
  --region $REGION

# Wait for cluster to become active
echo "Waiting for cluster to become active (this may take a while)..."
aws eks wait cluster-active --name $CLUSTER_NAME --region $REGION

# Configure kubectl
echo "Configuring kubectl..."
aws eks update-kubeconfig --name $CLUSTER_NAME --region $REGION

# Check if node group exists
NODEGROUP_EXISTS=$(aws eks list-nodegroups --cluster-name $CLUSTER_NAME --region $REGION --query "nodegroups[?contains(@, '${CLUSTER_NAME}-nodes')]" --output text)

if [ -z "$NODEGROUP_EXISTS" ]; then
    # Create a node group
    echo "Creating node group..."
    aws eks create-nodegroup \
      --cluster-name $CLUSTER_NAME \
      --nodegroup-name "${CLUSTER_NAME}-nodes" \
      --node-role arn:aws:iam::$ACCOUNT_ID:role/$NODE_ROLE_NAME \
      --subnets $SUBNET1_ID $SUBNET2_ID \
      --disk-size 20 \
      --scaling-config minSize=2,maxSize=3,desiredSize=2 \
      --instance-types t3.medium \
      --region $REGION

    echo "Waiting for node group to become active (this may take 5-10 minutes)..."
    aws eks wait nodegroup-active --cluster-name $CLUSTER_NAME --nodegroup-name "${CLUSTER_NAME}-nodes" --region $REGION
else
    echo "Node group ${CLUSTER_NAME}-nodes already exists."
fi

echo "EKS cluster $CLUSTER_NAME is ready!"
echo "You can now use kubectl to interact with your cluster."
echo "Try running: kubectl get nodes"
