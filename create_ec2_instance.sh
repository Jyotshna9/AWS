#!/bin/bash

if [[ $# -ne 1 ]]; then
        echo "usage:./`basename $0` : <params.txt>"
        exit 2
fi

aws_installed=`which aws`
if [[ -n "$aws_installed" ]]; then
        echo "aws cli already installed"
else
        echo "installing aws cli"
        sudo apt install -y curl unzip
        if [[ ! -f "/tmp/awscliv2.zip" ]]; then
                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
        fi
        unzip /tmp/awscliv2.zip -d /tmp
        sudo /tmp/aws/install

fi

echo "below is aws cli version"
aws --version

aws_access_key_id=`grep aws_access_key_id params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`
aws_secret_access_key=`grep aws_secret_access_key params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`
aws_reg=`grep AWS_REGION params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`

aws configure set aws_access_key_id $aws_access_key_id
aws configure set aws_secret_access_key $aws_secret_access_key
aws configure set default.region $aws_reg

echo "..................................................."


cidr_block=`grep VPC_CIDR params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`
name=`grep -w NAME params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`

name ()
{
	aws ec2 create-tags \
        	--resources $1 \
        	--tags "Key=Name,Value=${name}_$2" \
        	--region $aws_reg
	echo "$2 - $1 named as ${name}_$2"

}





# Create VPC
VPC_ID=$(aws ec2 create-vpc \
	--cidr-block "$cidr_block" \
	--query 'Vpc.{VpcId:VpcId}' \
	--output text \
	--region "$aws_reg")
echo "VPC_ID:$VPC_ID: created in "$aws_reg" region"

# Add Name tag to VPC
name $VPC_ID vpc

subnet_cidr=`grep SUBNET_CIDR params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`
subnet_az=`grep SUBNET_AZ params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`

# add dns support
aws ec2 modify-vpc-attribute \
    --vpc-id "$VPC_ID" \
    --enable-dns-support "{\"Value\":true}"
if [[ $? -eq 0 ]]; then
	echo "added dns support"
else
	echo "not able to add dns support"
	exit 1
fi


# add dns hostnames
aws ec2 modify-vpc-attribute \
  --vpc-id "$VPC_ID" \
  --enable-dns-hostnames "{\"Value\":true}"
if [[ $? -eq 0 ]]; then
	echo "added dns hostnames"
else
	echo "not able to add dns hostnames"
	exit 1
fi

# create internet gateway
INTERNET_GATEWAY_ID=$(aws ec2 create-internet-gateway \
	--output text \
	--query 'InternetGateway.{InternetGatewayId:InternetGatewayId}' \
	--region $aws_reg)
echo "INTERNET_GATEWAY '$INTERNET_GATEWAY_ID' CREATED "

#name the internet gateway
name $INTERNET_GATEWAY_ID Gateway

#attach Internet gateway to VPC
aws ec2 attach-internet-gateway \
  --vpc-id $VPC_ID \
  --internet-gateway-id $INTERNET_GATEWAY_ID \
  --region $aws_reg
echo "Internet Gateway ID '$INTERNET_GATEWAY_ID' ATTACHED to VPC ID '$VPC_ID'."

# Create Public Subnet
SUBNET_ID=$(aws ec2 create-subnet \
  --vpc-id $VPC_ID \
  --cidr-block $subnet_cidr \
  --availability-zone $subnet_az \
  --query 'Subnet.{SubnetId:SubnetId}' \
  --output text \
  --region $aws_reg)
echo "Subnet ID '$SUBNET_ID' CREATED in $subnet_az Availability Zone."

# Add Name tag to Public Subnet
name $SUBNET_ID subnet
		

# Enable Auto-assign Public IP on Public Subnet
aws ec2 modify-subnet-attribute \
  --subnet-id $SUBNET_ID \
  --map-public-ip-on-launch \
  --region $aws_reg
echo "'Auto-assign Public IP' ENABLED on Public Subnet ID '$SUBNET_ID'"


#create security group
GROUP_Id=$(aws ec2 create-security-group \
 --group-name "${name}_SG" \
 --description "Private: ${name}_SG" \
 --vpc-id "$VPC_ID" \
 --output text \
 --region $aws_reg)
 echo "Security Group $GROUP_Id CREATED"

 # Add Name tag to security group
 name $GROUP_Id SG


destCidrBlk=`grep destinationCidrBlock params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`

#enable ports
enable_ports()
{
	aws ec2 authorize-security-group-ingress \
 		--group-id "$GROUP_Id" \
 		--protocol tcp --port $1 \
 		--cidr "$destCidrBlk"
	if [[ $? -eq 0 ]];then
		echo "enabled port $1 on cidr "$destCidrBlk""
	else
		echo "unable to enable port $1 on cidr "$destCidrBlk""
	fi
}

enable_ports 22
enable_ports 3000

# Create Route Table
ROUTE_TABLE_ID=$(aws ec2 create-route-table \
  --vpc-id $VPC_ID \
  --query 'RouteTable.{RouteTableId:RouteTableId}' \
  --output text \
  --region $aws_reg)
echo "Route Table ID '$ROUTE_TABLE_ID' CREATED."

# Add Name tag to Route Table
name $ROUTE_TABLE_ID route_table

#add route for the internet gateway
route_response=$(aws ec2 create-route \
 --route-table-id "$ROUTE_TABLE_ID" \
 --destination-cidr-block "$destCidrBlk" \
 --gateway-id "$INTERNET_GATEWAY_ID" \
 --region $aws_reg)

if [[ $? -eq 0 ]]; then
	echo "Route to "$destCidrBlk" via Internet Gateway ID "$INTERNET_GATEWAY_ID" added to Route Table ID $ROUTE_TABLE_ID"
else
	echo "unable to add route to Internet gateway"
fi

# Associate Public Subnet with Route Table
associate_response=$(aws ec2 associate-route-table  \
  --subnet-id $SUBNET_ID \
  --route-table-id $ROUTE_TABLE_ID \
  --region $aws_reg)

echo "Public Subnet ID '$SUBNET_ID' ASSOCIATED with Route Table ID '$ROUTE_TABLE_ID'"


echo "..................................................."

key_pair_exists=`aws ec2  describe-key-pairs  --output text --query 'KeyPairs' | awk '{print $2}' | grep $name`
if [[ -n $key_pair_exists ]]; then
	echo "key_pair $name already exists"
else
	aws ec2 create-key-pair --key-name $name --output text > $HOME/"$name".pem
	echo "created $name keypair and stored in $HOME with name "$name".pem"
	cat $HOME/"$name".pem  | awk -F "$name" '{print $1}' | sed '1d' | sed '1 i\-----BEGIN RSA PRIVATE KEY-----' > $HOME/"$name".pem_temp
	mv $HOME/"$name".pem_temp $HOME/"$name".pem
	chmod 400 $HOME/"$name".pem
fi

echo "..................................................."

instance_type=`grep instance-type params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`
cnt=`grep count params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`

inst_id=$(aws ec2 run-instances --image-id ami-0ac80df6eff0e70b5 --count $cnt --instance-type ${instance_type} --key-name $name --security-group-ids $GROUP_Id --subnet-id $SUBNET_ID --output text | awk '{print $8}' | grep "^i-")

if [[ $? -eq 0 ]]; then

	echo "below instance created"
	echo "$inst_id"
	for i in $inst_id;
	do
		name $i machine
		pub_ip=`aws ec2 describe-instances --instance-ids $i --query 'Reservations[].Instances[].PublicIpAddress' --output text`
		echo "public ip : ${pub_ip}"
		pub_dns=`aws ec2 describe-instances --instance-ids $i --query 'Reservations[].Instances[].PublicDnsName' --output text`
		echo "public dns : ${pub_dns}"
		pri_ip=`aws ec2 describe-instances --instance-ids $i --query 'Reservations[].Instances[].PrivateIpAddress'  --output text`
		echo "private ip : ${pri_ip}"
		pri_dns=`aws ec2 describe-instances --instance-ids $i --query 'Reservations[].Instances[].PrivateDnsName'  --output text`
		echo "private dns : ${pri_dns}"
		inst_status=$(aws ec2 describe-instance-status  --instance-ids $i --query 'InstanceStatuses[].SystemStatus[].Details[].Status' --output text)
		j=0

		if [[ ${inst_status} == "passed" ]]; then
			echo "$i system status is passed. Can use the instance"
		else

				until [[ ${inst_status} == "passed" ]] || [[ $j -gt 600 ]]; 
				do
					echo "waiting for the  $i system status to be passed"
					sleep 30
					inst_status=$(aws ec2 describe-instance-status  --instance-ids $i --query 'InstanceStatuses[].SystemStatus[].Details[].Status' --output text)
					j=$(($j+30))
				done
				
			

			if [[ ${inst_status} == "passed" ]]; then
				echo "$i system status is passed. Can use the instance"
			else
				echo "$i didnot come to passed state even waiting for 600 seconds. request to check"
				exit 2
			fi
		fi
	done
else
	echo "some problem creating instance"
	echo "$aws_res"
	exit 2
fi

echo "..................................................."
