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
