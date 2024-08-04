# ManagedadoopsPool

az account set --subscription "023b2039-5c23-44b8-844e-c002f8ed431d"
terraform init -var-file="dev.tfvars" 
terraform plan -var-file="dev.tfvars" 
terraform apply -var-file="dev.tfvars"  --auto-approve


# windows install donet core
# linux install dotnet core,azure cli, unzip, nodejs, powershell


https://github.com/Azure/managed-devops-pools/blob/main/docs/get-started-ado.md

steps :
1. Register the Managed DevOps Pools resource provider in your Azure Subscription:
select your subscription , under settings got to  Resource providers  and enable Microsoft.DevOpsInfrastructure


2. Verify Azure DevOps permissions

your identity is used to create a corresponding agent pool in your Azure DevOps organization. To successfuly create a Managed DevOps Pool you must have the following Azure DevOps permissions in your organization : Project Collection Administrator 

3.  Create a Dev Center and Dev Center project

 create a ressource group :  RG_MANAGED_DEVOPS_POOL

4. Create the Managed DevOps Pools resource

Search for Managed DevOps Pools and select it from the available options.


5. Verify the pool is available in azure devops 


6. setup build pipeline

# Change these two lines as shown in the following example.
 pool:
  vmImage: ubuntu-latest


  pool:
  name: datasynchro-managed-devops-pool-ado

7. Configure networking
add delegation to Microsoft.DevOpsInfrastructure/pools