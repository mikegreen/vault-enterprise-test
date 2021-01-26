#!/bin/bash

# run as sudo
# prereqs
# install docker 
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo chkconfig docker on

# get required packages
yum install -y git gcc make jq

# install terraform binary
wget https://releases.hashicorp.com/terraform/0.13.6/terraform_0.13.6_linux_amd64.zip
unzip terraform_0.13.6_linux_amd64.zip 
mv terraform /usr/local/bin/
sudo chmod +x /usr/local/bin/terraform 

# install vault binary
wget https://releases.hashicorp.com/vault/1.6.1+ent/vault_1.6.1+ent_linux_amd64.zip
unzip vault_1.6.1+ent_linux_amd64.zip 
mv vault /usr/local/bin/
sudo chmod +x /usr/local/bin/vault

# docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# done with prereqs
# and back to orignal steps

docker-compose stop
pushd ./transit-vault
rm -rf .terraform/
rm -rf terraform.tfstate
rm -rf terraform.tfstate.backup
popd
pushd ./vault
rm -rf .terraform/
rm -rf terraform.tfstate
rm -rf terraform.tfstate.backup
popd

echo "Start docker-compose on vault_transit"

docker-compose up --no-start
docker-compose start vault_transit
pushd ./transit-vault
terraform init
terraform apply -auto-approve
popd

echo "Start docker-compose on vault cluster"
docker-compose start consul
docker-compose start statsd
docker-compose start vault_1
docker-compose start vault_2
docker-compose start vault_3
RESPONSE=$(vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json)
echo $RESPONSE
ROOT_TOKEN=$(echo $RESPONSE | jq -j .root_token)
echo ROOT TOKEN = $ROOT_TOKEN
export VAULT_TOKEN=$ROOT_TOKEN
pushd ./vault
terraform init
terraform apply -auto-approve
popd
vault login -address=http://127.0.0.1:8200 -method=userpass username=user password=password
echo "Setup done"

sleep 5
docker-compose logs -f
