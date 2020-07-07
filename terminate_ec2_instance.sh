#!/bin/bash

if [[ $# -ne 1 ]]; then
        echo "usage:./`basename $0` : <params.txt>"
        exit 2
fi

name=`grep -w NAME params.txt | cut -d "=" -f2 | sed 's/^\s\+//g;s/\s\+$//g'`

echo "###########################################"

# terminate ec2 instance
for j in `aws ec2 describe-instances --filters "Name=tag:Name,Values=${name}_machine" --query "Reservations[].Instances[].InstanceId" --output text`;
do
        if [[ -n $j ]]; then
                vpc=`aws ec2 describe-instances --filter --instance-ids $j --query "Reservations[].Instances[].VpcId" --output text`;
                term_res=$(aws ec2 terminate-instances --instance-ids "$j")
                inst_code=`aws ec2 describe-instances --instance-ids "$j" --query "Reservations[].Instances[].State[]" --output text | awk '{print $1}'`
                if [[ $inst_code -ne 48 ]]; then
                        until [[ $inst_code -eq 48 ]];
                        do
                                sleep 5
                                inst_code=`aws ec2 describe-instances --instance-ids "$j" --query "Reservations[].Instances[].State[]" --output text | awk '{print $1}'`
                        done

                        echo "$j came to terminated state"
                else
                        echo "$j is already in terminated state"
                fi

        else
                echo "no ec2 instances found to delete"
        fi
done

echo "#####################################################3"


for vpc in `aws ec2 describe-vpcs --filter "Name=tag:Name,Values=${name}_vpc" --output text | awk '{print $8}' | sed '/^$/d'`;

do
                        if [[ -n "$vpc" ]]; then

                                echo "vpc id - $vpc"
                                # delete subnets
                                for i in `aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpc" --query "Subnets[].SubnetId" --output text`
                                do
                                        if [[ -n $i ]]; then
                                                aws ec2 delete-subnet --subnet-id $i
                                                if [[ $? -eq 0 ]]; then
                                                        echo "successfuly deleted --subnet-id $i from $vpc"
                                                fi
                                        else
                                                "no subnets found to delete"
                                        fi
                                done

                                # detach IG from vpc and delete
                                for i in `aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$vpc"  --query "InternetGateways[].InternetGatewayId" --output text`
                                do
                                        if [[ -n $i ]]; then
                                                aws ec2 detach-internet-gateway --internet-gateway-id $i --vpc-id "$vpc"
                                                if [[ $? -eq 0 ]]; then
                                                        echo "successfuly detached --internet-gateway-id $i from $vpc"
                                                else
                                                        echo "problem detaching --internet-gateway-id $i from $vpc"
                                                fi
                                                aws ec2 delete-internet-gateway --internet-gateway-id $i
                                                if [[ $? -eq 0 ]]; then
                                                        echo "successfuly deleted --internet-gateway-id $i from "$vpc""
                                                else
                                                        echo "problem deleting --internet-gateway-id $i from "$vpc""
                                                fi
                                        else
                                                echo "no IG for deletion"
                                        fi
                                done

                                # delete Security groups
                                for i in `aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$vpc" "Name=tag:Name,Values=${name}_SG" --query 'SecurityGroups[].GroupId' --output text`
                                do
                                        if [[ -n $i ]]; then
                                                aws ec2 delete-security-group --group-id $i
                                                if [[ $? -eq 0 ]]; then
                                                        echo "successfuly deleted --security-group-id $i from "$vpc""
                                                else
                                                        echo "problem deleting --security-group-id $i from "$vpc""
                                                fi
                                        else
                                                echo "no SG's for deletion"
                                        fi
                                done

                                # delete route tables
                                for i in `aws ec2 describe-route-tables  --filters "Name=vpc-id,Values=$vpc" "Name=tag:Name,Values=${name}_route_table" --query 'RouteTables[].RouteTableId' --output text`
                                do
                                        if [[ -n "$i" ]]; then
                                                aws ec2 delete-route-table --route-table-id $i
                                                if [[ $? -eq 0 ]]; then
                                                        echo "successfuly deleted --RouteTableId $i from "$vpc""

                                                else
                                                        echo "problem deleting --RouteTableId $i from "$vpc""
                                                fi
                                        else
                                                echo "no route-table's found to delete"
                                        fi
                                done

                                # delete vpc
                                aws ec2 delete-vpc --vpc-id "$vpc"
                                if [[ $? -eq 0 ]]; then
                                        echo "succesfully deleted --vpc-id "$vpc""
                                else
                                        echo "unable to delete vpc id $vpc"
                                fi
                        else
                                echo "no vpc's found to delete"
                        fi

                        echo "....................................................."

done

echo "############################################"

# delete keypairs
key_pair_exists=`aws ec2  describe-key-pairs  --output text --query 'KeyPairs' | awk '{print $2}' | grep $name`
if [[ -n $key_pair_exists ]]; then
        aws ec2 delete-key-pair --key-name $name
        if [[ $? -eq 0 ]]; then
                echo "deleted $name key-pair"
                rm -rf $HOME/"$name"_keypair.pem
        else
                echo "unable to delete $name key-pair"
        fi
else
        echo "$name key-pair doesnot exists"
fi


echo "#############################################"
