#!/usr/bin/env bash
echo "REPOSITORY: terraform-aws-jenkins"
echo "SCRIPT: tf-plan.sh <env_name> <region> <availability_zones> <ssh_key_name>"
echo "EXECUTING: terraform plan"

echo "Checking for aws cli..."
if ! [ -x "$(command -v aws)" ]; then
    echo 'Error: aws cli is not installed.' >&2
    exit 1
fi

jenkins_env_name=$1
if [ -z "$jenkins_env_name" ]; then
    jenkins_env_name=TestJenkins01
    echo "An environment name was not passed in, using \"${jenkins_env_name}\" as the default"
fi

target_aws_region=$2
if [ -z "$target_aws_region" ]; then
    target_aws_region=us-west-2
    echo "No region was passed in, using \"${target_aws_region}\" as the default"
fi

availability_zones=$3
if [ -z "$availability_zones" ]; then
    availability_zones=us-west-2a,us-west-2b,us-west-2c
    echo "No availability zones were passed in, using \"${availability_zones}\" as the default"
fi

ssh_key_name=$4
if [ -z "$ssh_key_name" ]; then
    ssh_key_name="root-ssh-key-${target_aws_region}"
    echo "No ssh key name was passed in, using \"${ssh_key_name}\" as the default"
fi

# Set name of remote terraform states bucket
terraform_remote_states_bucket=terraform-states-${target_aws_region}

# Needed for Terraform AWS Provider {}
export AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
export AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)

# Uncomment for verbose terraform output
#export TF_LOG=info

echo "Cleanup terraform state files"
rm .terraform/terraform.tfstate terraform.tfstate.backup

echo "Setting up terraform configuration for remote s3 state file storage"
echo "terraform init -backend-config \"bucket=${terraform_remote_states_bucket}\" -backend-config \"key=${jenkins_env_name}/jenkins.tfstate\" -backend-config \"region=${target_aws_region}\""
terraform init \
    -backend-config="bucket=${terraform_remote_states_bucket}" \
    -backend-config="key=${jenkins_env_name}/jenkins.tfstate" \
    -backend-config="region=${target_aws_region}"

echo "Uploading files for jenkins..."
./upload_files_to_s3.sh ${target_aws_region}

echo "terraform apply -var \"env_name=${jenkins_env_name}\" -var \"region=${target_aws_region}\"  -var \"availability_zones=${availability_zones}\" -var \"ssh_key_name=${ssh_key_name}\""
if terraform apply -var "env_name=${jenkins_env_name}" -var "region=${target_aws_region}"  -var "availability_zones=${availability_zones}" -var "ssh_key_name=${ssh_key_name}"; then
    echo "Terraform apply succeeded."
else
    echo 'Error: terraform apply failed.' >&2
    exit 1
fi

echo "# # # # # YOU DID IT! # # # # # #"
echo "Yay! Jenkins is now being provisioned!"
echo "To access your jenkins shell, run \"ssh admin@the.ip.in.output\""
echo "Go ahead and ssh in and tail the provision script to watch everything get installed"
echo "tail -f /var/log/user-data.log"
echo "To access your jenkins UI, goto \"the.ip.in.output:8080\" in your web browser."
echo "done";
