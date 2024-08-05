# Deploying in a Private Azure Environment using Managed DevOps Pool

In your organization, you may have an Azure environment where all deployed services must be private due to security requirements.
In this context, it will not be possible to deploy from Azure DevOps or GitHub Actions using Microsoft-hosted DevOps agents, as these agents will not be able to enter a private environment.

For more information, please refer to the following link: [Learn more about Azure DevOps Hosted Agents](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml)

Several solutions have been considered by DevOps teams to deploy in a private environment from GitHub Actions or Azure DevOps.

In my previous article, [Azure DevOps Private Build Agent using Azure Container Instance and Terraform](https://azurewarriors.com/index.php/2024/02/25/azure-devops-private-build-agent-using-azure-container-instance-and-terraform/), I showed how to create private build agents using Docker, Azure Container Instance, and Terraform.

As a Microsoft MVP, I had the privilege of participating in a private preview of the Managed DevOps Pools, which will completely change the way we design private DevOps agents.

For more information on the topic of Managed DevOps Pools, please refer to the blog [Announcing the Public Preview of Managed DevOps Pools (MDP) for Azure DevOps](https://devblogs.microsoft.com/devops/managed-devops-pools/).

In this tutorial, I will show how to configure a Managed DevOps Pools (MDP) and deploy private infrastructure in Azure with Azure DevOps.

The architecture to be deployed is as follows:

A private function app (datasync-funcapp-dev) with a private endpoint enabled on an inboundSubnet (10.0.0.0/24) on the virtual network vnet-funcapp-dev (10.0.0.0/16) with a virtual network integration on an outboundSubnet (10.0.1.0/24) on the same virtual network vnet-funcapp-dev.

This function app datasync-funcapp-dev connects to a private storage account storagedatasyncdev with a private endpoint enabled on the subnet vnet-funcapp-dev/inboundSubnet.

In the second phase, I will use a Managed DevOps Pools (MDP) and Azure DevOps to deploy C# code into the function app (datasync-funcapp-dev).

![Architecture- datasynchro architecture - mdp drawio](https://github.com/user-attachments/assets/b08995f2-8969-47e5-95a1-1dce45925abf)

Figure A

## A. Managed DevOps Pools Configuration
For more information on managed devops pools, please follow the link: https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/overview?view=azure-devops

In this section, I will configure a Managed DevOps Pool step-by-step:<br>
- **Register the Managed DevOps Pools resource provider** <br>
- **Verify Azure DevOps permissions** <br>
- **Create a Dev Center and a Dev Center project** <br>
- **Create the Managed DevOps Pools resource** <br>
- **Configure the image** <br>
- **Configure networking** <br>
- **Ensure the pool is available in Azure DevOps** <br>
- **Configure the build pipeline** <br>
- **Complete the configuration** <br>

### Steps:

1. **Register the Managed DevOps Pools resource provider in your Azure subscription:** <br>
   This step is part of the prerequisites before starting the configuration of a Managed DevOps Pool:
- Connect your Azure DevOps organization to the same Microsoft Entra directory as your Azure subscription.
- **Register the Managed DevOps Pools resource provider in your Azure subscription**.
- Verify Azure DevOps permissions.
- Check Managed DevOps Pools quotas. <br>
For more information on the prerequisites, please visit https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops&tabs=azure-portal. <br>
To register the Managed DevOps Pools resource provider in your Azure subscription, simply open your Azure portal and select your Azure subscription, under the settings tab, go to Resource Providers and activate Microsoft.DevOpsInfrastructure as shown in the following figure:
   
   ![0  Register](https://github.com/user-attachments/assets/272d9f8f-4fe9-462c-aab8-a1c63deb70c7)


2. **Verify Azure DevOps permissions:** <br>
 This step is also part of the prerequisites before starting the configuration of a Managed DevOps Pool: https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops&tabs=azure-portal

- Connect your Azure DevOps organization to the same Microsoft Entra directory as your Azure subscription.
- Register the Managed DevOps Pools resource provider in your Azure subscription.
- **Verify Azure DevOps permissions**.
- Check Managed DevOps Pools quotas. <br>

Indeed, when creating a Managed DevOps Pool, your identity is used to create an agent pool in your Azure DevOps organization. <br>
To successfully create a Managed DevOps Pool, you must have one of the following permissions in your Azure DevOps organization.
These permissions are listed in ascending order of privileges.

- Organization-level agent pool administrator: Organization-level agent pool administrators can create new agent pools and perform all operations on them.
- Project collection administrator: The project collection administrators group is the main administrative security group defined for an organization and can perform all operations within an Azure DevOps organization, including creating new pools.
  https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops&tabs=azure-portal#verify-azure-devops-permissions  <br>
  
In fact, your identity is used to create an agent pool in your Azure DevOps organization. To successfully create a Managed DevOps Pool, I added my user to the permissions (Project collection administrator) in my Azure DevOps organization as shown in the following figure: <br>

   ![0b  devops](https://github.com/user-attachments/assets/858ed313-e213-45ea-8ca0-00270b2c0573)


3. **Create a Dev Center and a Dev Center project:** <br>
Before creating a managed devops pool, you must first create a dev center and a dev center project. <br>
For more information on the steps, please refer to the following link: https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/quickstart-azure-portal?view=azure-devops

To  create a dev center and a dev center project, you will create a resource group: `ex RG_MANAGED_DEVOPS_POOL`. <br>
Then, in your Azure portal, search for "Dev centers" and click on create as follows:
   
   ![1  dev center](https://github.com/user-attachments/assets/71805f1d-5b37-470a-b299-c590839d6668)

Wait for the deployment to complete, then, in the manage tab, click on project to create a new project.

   ![2a  dev center project](https://github.com/user-attachments/assets/87e33aa2-017b-4a59-8921-a76e6e959196)

   Provide the necessary information, resource group, name, description, and then click on review + create

![2b  dev center project](https://github.com/user-attachments/assets/04986b8d-3e11-4ddc-8a8f-07ddff1bb05a)


4. **Create the Managed DevOps Pools resource:**
Log in to the Azure portal.

Search for "Managed DevOps Pools" and click on "Create a Managed DevOps Pool."

   ![3a  managed devops pool](https://github.com/user-attachments/assets/45622893-a462-427f-bb6f-26ac2f3c9d53)

Fill in the necessary information:
- Resource group name
- Use the previously created Dev Center and Dev Center project
- In "Azure DevOps organization," **provide your DevOps organization** (in my case, it's https://dev.azure.com/datasynchro). <br>
- Name your pool (datasynchro-managed-devops-pool-ado in my case). <br>
- For the rest, you can leave the default configuration or adjust it according to your requirements in terms of maximum agents, agent size, OS disk type, and images used by the agents.
Click "Next."

![3b  managed devops pool](https://github.com/user-attachments/assets/de02d9bf-d2ee-4fbd-9b40-770375b7a842)

Review the default scaling configuration and click "Next."
Customizing scaling will be covered in a separate topic.

![3c  managed devops pool](https://github.com/user-attachments/assets/0f06dfb5-7d31-4aa7-8b30-42688a301459)

Review the default networking configuration and click "Next."
Customizing networking will be covered in a separate topic.

![3d  managed devops pool](https://github.com/user-attachments/assets/14a10a1c-48e8-4f62-8005-5c79710a6d30)

Review the default storage configuration and click "Next."
Customizing storage will be covered in a separate topic.

![3e  managed devops pool](https://github.com/user-attachments/assets/b04e3d9b-b403-4328-8582-47542ea75287)

Review the default security configuration and click "Next."
Customizing security will be covered in a separate topic.

![3f  managed devops pool](https://github.com/user-attachments/assets/107669a1-2112-4d2e-864d-8b47a15f9ed8)

Click "Review + Create" to complete the configuration of the Managed DevOps Pool resource.

Wait until the deployment is completed, then check the pools in your organization: click on "Project Settings" then "Agent Pools." <br>
The previously configured pool should be displayed as shown in the following figure; if not, review your configuration.

![3g  managed devops pool](https://github.com/user-attachments/assets/1da4abfd-89dc-49a9-bf78-d39e532e91cd)

5. **Configuring the Image:**

Managed DevOps Pools offer several options for configuring the images that run on the virtual machines, allowing pipelines to execute in the pool. <br>
We can create our pool with the following options:
- Use virtual machine images from Azure Marketplace.
- Use our own custom images from the Azure Compute Gallery.
- Use the same images as the Microsoft-hosted agents in Azure Pipelines.

Managed DevOps Pools can be configured with a single image or multiple images (by specifying an alias). <br>
For more information on configuring images, please refer to the following link: [Configure images](https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-images?view=azure-devops&tabs=azure-portal)

   ![4a  Configure image](https://github.com/user-attachments/assets/f0dc08fc-b013-4eda-9cfe-2a4304f5663d)

We will use the 2 images Azure Pipelines Windows Server 2022 and Ubuntu 20.04 as they contain the necessary tools to configure our pipelines without needing to install additional tools:
- [Windows Server 2022 Readme](https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md)
- [Ubuntu 20.04 Readme](https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2004-Readme.md)

   ![4b  Configure image](https://github.com/user-attachments/assets/9a3ab50a-54e7-4b84-8d6d-57888b5024ba)

Click "Add" then "Apply."

   ![4c  Configure image](https://github.com/user-attachments/assets/306a0333-9437-4e21-9be5-0a678cf3782c)

7. **Configuring the Build Pipeline:** <br>
   Our Managed DevOps Pool configuration is ready and operational. In this section, we will create a pipeline in Azure DevOps and use our Managed DevOps Pool.

   To do this, simply replace the default image (`vmImage: ubuntu-latest`) with our Managed DevOps Pool (`name: datasynchro-managed-devops-pool-ado`).

   ```yaml
   # In the following configuration, replace vmImage: ubuntu-latest (where ubuntu-latest is the default image) with name: datasynchro-managed-devops-pool-ado (where datasynchro-managed-devops-pool-ado is the name of our Managed DevOps Pool)
   pool:
     vmImage: ubuntu-latest

   pool:
     name: datasynchro-managed-devops-pool-ado

## B. Using the Managed DevOps Pool in a Private Network

In Part A, we completed the configuration of our Managed DevOps Pool, which is operational for deployments in an unrestricted network architecture. 
Indeed, in our architecture setup (see Figure A), the function app and the storage account are private, so the default agents like `ubuntu-latest` or `windows-latest` will not be able to deploy code to the function app because the VMs cannot access our private network.

To resolve this issue, we will add our Managed DevOps Pool to a virtual network (our internal network).

1. **Configuring Networking:**

Open your Managed DevOps Pool under settings, select "Networking," and then click on "Agents injected into existing virtual network."
Click "Configure" and select our virtual network and subnet.

![5a  networking](https://github.com/user-attachments/assets/f6cb85fa-bad1-4bde-831c-0e8702c50d5d)

2. **Completing the Configuration:**

Our Managed DevOps Pool is configured in a VNet (`managed-devops-pool-vnet`) which is different from the VNet where our function app is configured (`vnet-funcapp-dev`).

Therefore, we need to set up peering between the two VNets in both directions (VNet `managed-devops-pool-vnet` <--> peering with VNet `vnet-funcapp-dev`).

![6a  peering](https://github.com/user-attachments/assets/70a1052e-fa1f-4b0d-ac2d-e3ad74603269)

![6b  peering](https://github.com/user-attachments/assets/bd1f7c00-d717-4daa-833a-0e44c66fb0c2)

Finally, since our architecture uses private endpoints, we need to add a Virtual Network Link between our virtual networks (`vnet-managed-devops-pool-vnet` and `vnet-funcapp-dev`) and the private DNS zones (`privatelink.blob.core.windows.net` for the storage account and `privatelink.azurewebsites.net` for the function app).

![7a vnet link](https://github.com/user-attachments/assets/186f4d16-d92c-4017-97f2-6448530ae0c0)

![7b vnet link](https://github.com/user-attachments/assets/c51aec3d-022e-4897-82ea-97bd7de103be)

## B. Summary

We have completed the configuration of a Managed DevOps Pool and added it to our private network to enable deployments within our private architecture. With this new service now in public preview, Microsoft introduces a highly anticipated feature in the DevOps world: setting up private DevOps agents.

In addition to this networking feature, other key features have been added. I encourage you to read the official blog for more information: [Managed DevOps Pools](https://devblogs.microsoft.com/devops/managed-devops-pools/).
