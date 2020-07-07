below are the contents present in params.txt file inorder to create ec2 instance in the specified region

ubuntu@localhost:~/$cat params.txt
AWS_REGION=us-east-1                               # instance will be created in us-east-1 region
NAME=dev                                           # aws resources like ec2, subnet,internet gateway, security group will be tagged with dev
VPC_CIDR=10.0.0.0/16                
SUBNET_PUBLIC_CIDR=10.0.1.0/24
SUBNET_PUBLIC_AZ=us-east-1a
SUBNET_PUBLIC_NAME=10.0.1.0 - us-east-1a
destinationCidrBlock=0.0.0.0/0
count=1                                           # no of ec2 instances to be launched
instance-type=t2.micro                            # type of ec2 instance to be launched


below is the sample o/p of creation of ec2 instance
ubuntu@localhost$ ./create_ec2_instance.sh params.txt
...................................................
aws cli already installed
aws-cli/1.18.93 Python/3.6.9 Linux/5.3.0-1028-aws botocore/1.17.16
...................................................
VPC_ID:vpc-09f0a2a45bc77d146: created in us-east-1 region
vpc - vpc-09f0a2a45bc77d146 named as dev_vpc
added dns support
added dns hostnames
INTERNET_GATEWAY 'igw-0775a08b7e40c1a5c' CREATED
Gateway - igw-0775a08b7e40c1a5c named as dev_Gateway
Internet Gateway ID 'igw-0775a08b7e40c1a5c' ATTACHED to VPC ID 'vpc-09f0a2a45bc77d146'.
Subnet ID 'subnet-00dd32503b7f1890c' CREATED in us-east-1a Availability Zone.
subnet - subnet-00dd32503b7f1890c named as dev_subnet
'Auto-assign Public IP' ENABLED on Public Subnet ID 'subnet-00dd32503b7f1890c'
Security Group sg-0bed1e9a24fb8182c CREATED
SG - sg-0bed1e9a24fb8182c named as dev_SG
enabled port 22 on cidr 0.0.0.0/0
Route Table ID 'rtb-0a800c764e79b1bb4' CREATED.
route_table - rtb-0a800c764e79b1bb4 named as dev_route_table
Route to 0.0.0.0/0 via Internet Gateway ID igw-0775a08b7e40c1a5c added to Route Table ID rtb-0a800c764e79b1bb4
Public Subnet ID 'subnet-00dd32503b7f1890c' ASSOCIATED with Route Table ID 'rtb-0a800c764e79b1bb4'
...................................................
created dev keypair and stored in /home/ubuntu with name dev_keypair.pem
...................................................
below instance created
i-09c4a33c232818bf9
machine - i-09c4a33c232818bf9 named as dev_machine
...................................................





below is the sample o/p of termination of ec2 instance
ubuntu@localhost:~./terminate_ec2_instance.sh params.txt
###########################################
i-09c4a33c232818bf9 came to terminated state
#####################################################3
vpc id - vpc-09f0a2a45bc77d146
successfuly deleted --subnet-id subnet-00dd32503b7f1890c from vpc-09f0a2a45bc77d146
successfuly detached --internet-gateway-id igw-0775a08b7e40c1a5c from vpc-09f0a2a45bc77d146
successfuly deleted --internet-gateway-id igw-0775a08b7e40c1a5c from vpc-09f0a2a45bc77d146
successfuly deleted --security-group-id sg-0bed1e9a24fb8182c from vpc-09f0a2a45bc77d146
successfuly deleted --RouteTableId rtb-0a800c764e79b1bb4 from vpc-09f0a2a45bc77d146
succesfully deleted --vpc-id vpc-09f0a2a45bc77d146
.....................................................
############################################
deleted dev key-pair
#############################################
