## Description


## Objectives
Create a Virtual Network with two virtual machines in separate subnets. One machine is public accessable to host the application and the other one is private to host the database. Enable network security rule on the public VM to enable RDP connection.

## Usage
<br /> 1. Open terminal
<br /> 2. Before you can execute the terraform script, your need to configure your Azure environment first.
<br /> az login --user <myAlias@myCompany.onmicrosoft.com> --password <myPassword>
<br /> Update tenant_id in main.tf (az account tenant list)
<br /> Update subscription_id in main.tf (az account subscription list)
<br /> 3. Now you can apply the terraform changes.
<br /> terraform init
<br /> terraform apply --auto-approve
<br /> 4. Connect to public VM and ping the private VM.
<br /> Test result: Ping answer messages received.
<br /> 5. At the end you can cleanup the created AWS resources.
<br /> terraform destroy --auto-approve
