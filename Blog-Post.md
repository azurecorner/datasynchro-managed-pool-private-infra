Dans votre organisation, vous pouvez disposer d'un environnement Azure où tous les services déployés doivent être privés pour des exigences de sécurité.
Dans ce contexte, il ne sera pas possible de déployer à partir d'Azure DevOps ou de GitHub Actions en utilisant des agents DevOps hébergés par Microsoft, car ces agents ne pourront pas entrer dans un environnement privé.

Pour plus d'informations, veuillez consulter le lien suivant : [Agents hébergés par Microsoft](https://learn.microsoft.com/en-us/azure/devops/pipelines/agents/hosted?view=azure-devops&tabs=yaml).

Plusieurs solutions ont été envisagées par les équipes DevOps pour déployer dans un environnement privé depuis GitHub Action ou Azure DevOps.

Dans cet article, [Azure DevOps Private Build Agent using Azure Container Instance and Terraform](https://azurewarriors.com/index.php/2024/02/25/azure-devops-private-build-agent-using-azure-container-instance-and-terraform/), j'avais montré comment créer des agents de build privés avec Azure Docker, Azure Container Instance et Terraform.

Étant Microsoft MVP, j'ai eu le privilège de participer à une private preview des Managed DevOps Pools qui va complètement changer la manière de concevoir des agents DevOps privés.

Pour plus d'informations sur le sujet des Managed DevOps Pools, veuillez consulter le blog [Annonçant la Public Preview des Managed DevOps Pools (MDP) pour Azure DevOps](https://devblogs.microsoft.com/devops/managed-devops-pools/).

Dans cet tutoriel, je vais montrer comment configurer un Managed DevOps Pools (MDP) et déployer une infrastructure privée dans Azure avec Azure DevOps.

L'architecture à déployer est la suivante :

Une fonction app (datasync-funcapp-dev) privée avec un private endpoint sur un sous-réseau inboundSubnet (10.0.0.0/24) sur le vnet vnet-funcapp-dev (10.0.0.0/16) avec une intégration vnet sur un sous-réseau outboundSubnet (10.0.1.0/24) sur le même vnet vnet-funcapp-dev.

Cette fonction app, datasync-funcapp-dev, se connecte à un compte de stockage storagedatasyncdev privé avec un private endpoint sur le sous-réseau vnet-funcapp-dev/inboundSubnet.

Et dans un second temps, je vais utiliser un Managed DevOps Pools (MDP) et Azure Devops pour deployer du code C# dans la function app (datasync-funcapp-dev)
![Architecture- datasynchro architecture - mdp drawio](https://github.com/user-attachments/assets/b08995f2-8969-47e5-95a1-1dce45925abf)
Fugure A

## A. Configuration des Managed DevOps Pools
Pour plus d'informations sur les managed devops pool, merci de suivre le lien suivant : https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/overview?view=azure-devops

Dans cette section, nous allons configurer un Managed DevOps Pool étape par étape :<br>
- **Enregistrement du  fournisseur de ressources Managed DevOps Pools dans votre abonnement Azure** <br>
- **Vérification des permissions Azure DevOps   de l'utilisateur chargé de configuration** <br>
- **Création d'un Dev Center et d'un projet Dev Center :** <br>
- **Création de la ressource Managed DevOps Pools :**  <br>
- **Configuration de l'image :** <br>
- **Configuration du networking :** <br>
- **Vérifier que le pool est disponible dans Azure DevOps.** <br>
- **Configurer le pipeline de build :** <br>
- **Terminer la congiguration :** <br>


### Étapes :

1. **Enregistrement du fournisseur de ressources Managed DevOps Pools dans votre abonnement Azure :** <br>
   Cette étape fait partie des prerequis suivant avant de commencer la configuration d'un Managed DevOps Pools :
- Connectez votre organisation Azure DevOps au même annuaire Microsoft Entra que votre abonnement Azure.
- **Enregistrez le fournisseur de ressources Managed DevOps Pools dans votre abonnement Azure**.
- Vérifiez les permissions Azure DevOps. 
- Consultez les quotas des Managed DevOps Pools. <br>
Pour plus d'informations sur les preréquis merci de consulter la page https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops&tabs=azure-portal. <br>
Pour enregistrer le fournisseur de ressources Managed DevOps Pools dans votre abonnement Azure, il suffit d'ouvrir cotre portail azure et sélectionnez votre abonnement azure , sous l'onglet paramètres, allez à Fournisseurs de ressources et activez Microsoft.DevOpsInfrastructure comme indiqué dans la figure suivante :
   
   ![0  Register](https://github.com/user-attachments/assets/272d9f8f-4fe9-462c-aab8-a1c63deb70c7)


2. **Vérification des permissions Azure DevOps :** <br>
 Cette étape fait aussi partie des prerequis  avant de commencer la configuration d'un Managed DevOps Pools : https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops&tabs=azure-portal

- Connectez votre organisation Azure DevOps au même annuaire Microsoft Entra que votre abonnement Azure.
- Enregistrez le fournisseur de ressources Managed DevOps Pools dans votre abonnement Azure.
- **Vérifiez les permissions Azure DevOps**. 
- Consultez les quotas des Managed DevOps Pools. <br>

En effet, lors de la création d'un Managed DevOps Pool, votre identité est utilisée pour créer un pool d'agents  dans votre organisation Azure DevOps. <br>
Pour créer un Managed DevOps Pool avec succès, vous devez disposer d'une des permissions suivantes dans votre organisation Azure DevOps.
Ces permissions sont listées par ordre croissant de privilèges.

- Administrateur des pools d'agents au niveau de l'organisation : Les administrateurs des pools d'agents au niveau de l'organisation peuvent créer de nouveaux pools d'agents et effectuer toutes les opérations sur ceux-ci.
- Administrateur de la collection de projets : Le groupe des administrateurs de la collection de projets est le principal groupe de sécurité administrative défini pour une organisation et peut effectuer toutes les opérations au sein d'une organisation Azure DevOps, y compris la création de nouveaux pools.
  https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/prerequisites?view=azure-devops&tabs=azure-portal#verify-azure-devops-permissions  <br>
  
En fait, votre identité est utilisée pour créer un pool d'agents dans votre organisation Azure DevOps. Pour créer avec succès un Managed DevOps Pool, j'ai ajouté mon user dans les permissions (Administrateur de la collection de projets.)  dans mon  organisation Azure DevOps comme indiquée dans la figure suivantes : <br>

   ![0b  devops](https://github.com/user-attachments/assets/858ed313-e213-45ea-8ca0-00270b2c0573)


3. **Création d'un Dev Center et d'un projet Dev Center :** <br>
Avant de créer un managed devops pool , nous devons d'abord créer et dev center et dev center project. <br>
Pour plus d'informations sur les étapes, merci de consulter le lien suivant : https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/quickstart-azure-portal?view=azure-devops

Pour cela, nous allons créez un groupe de ressources : `RG_MANAGED_DEVOPS_POOL`. <br>
Puis dans votre portail azure , rechercher << Dev centers >> et cliquer sur créer commse suit :
   
   ![1  dev center](https://github.com/user-attachments/assets/71805f1d-5b37-470a-b299-c590839d6668)

Attendre que le deploiement soit terminé puis, dans l'onglet manage, cliquer sur projet pour créer un nouveau projet

   ![2a  dev center project](https://github.com/user-attachments/assets/87e33aa2-017b-4a59-8921-a76e6e959196)

   Founir les informations necessaires, resources group, nom, description et puis cliquer sur  review + create

![2b  dev center project](https://github.com/user-attachments/assets/04986b8d-3e11-4ddc-8a8f-07ddff1bb05a)


4. **Création de la ressource Managed DevOps Pools :**

Connectez-vous au portail Azure.

Recherchez Managed DevOps Pools et cliquer sur  Créer un Managed DevOps Pool

   ![3a  managed devops pool](https://github.com/user-attachments/assets/45622893-a462-427f-bb6f-26ac2f3c9d53)

Renseignez les informations necessaires :
nom de group de ressources, utiliser le  dev center et le dev center porject precedemment crée, puis dans Azure DevOps organization, **fournissez votre organisation devops**, dans mon cas, il s'agit de https://dev.azure.com/datasynchro. <br>
Donner un nom à votre pool (datasynchro-managed-devops-pool-ado dans mon cas). <br>
Pour le reste , vous pouvez laisser la configuration par défaut ou le réajuter selon vos exigences en terme de maximum agent, Agent size, OS disk type, Images utilisé par les agents.
Cliquer sur suivant

![3b  managed devops pool](https://github.com/user-attachments/assets/de02d9bf-d2ee-4fbd-9b40-770375b7a842)

Prendre connaissance de la configuration par défaut du scaling, et cliquer sur suivant
La personalisation du scaling fera l'objet d'un sujet à part

![3c  managed devops pool](https://github.com/user-attachments/assets/0f06dfb5-7d31-4aa7-8b30-42688a301459)

Prendre connaissance de la configuration par défaut du networking , et cliquer sur suivant
La personalisation du networking fera l'objet d'un sujet à part

![3d  managed devops pool](https://github.com/user-attachments/assets/14a10a1c-48e8-4f62-8005-5c79710a6d30)

Prendre connaissance de la configuration par défaut du storage , et cliquer sur suivant
La personalisation du storage fera l'objet d'un sujet à part

![3e  managed devops pool](https://github.com/user-attachments/assets/b04e3d9b-b403-4328-8582-47542ea75287)

Prendre connaissance de la configuration par défaut de la sécurité , et cliquer sur suivant
La personalisation de la sécurité fera l'objet d'un sujet à part

![3f  managed devops pool](https://github.com/user-attachments/assets/107669a1-2112-4d2e-864d-8b47a15f9ed8)

Cliquer sur Review + Create pour terminer la congiration de la ressource Managed DevOps Pool.

Attendre jusqu'à ce que le deploiement soit terminé , et puis vérifier les pools dans votre organisation :  cliquez sur Projest Settings puis  Agent Pools. <br>
Le pool precedemment configuré doit être affiché comme dans la figure suivante, sinon revoir votre configuration 

![3g  managed devops pool](https://github.com/user-attachments/assets/1da4abfd-89dc-49a9-bf78-d39e532e91cd)


5. **Configuration de l'image :**

Les Managed DevOps Pools offrent plusieurs options pour la configuration des images qui tournent sur les machines virtuelles permettant d'exécuter les pipelines dans le pool. <br>
Nous pouvons créer notre pool avec les options suivantes : 
- utilisation des images de machines virtuelles depuis Azure Marketplace.
- utilisation de nos propres images personnalisées de la Azure Compute Gallery.
- utilisation des mêmes images que les agents hébergés par Microsoft dans Azure Pipelines.

Les Managed DevOps Pools peuvent être configurés avec une seule image ou plusieurs images (en spécifiant un alias). <br>
Pour plus d'informations sur la configuration des images , merci de consulter le lien suivant : https://learn.microsoft.com/en-us/azure/devops/managed-devops-pools/configure-images?view=azure-devops&tabs=azure-portal

   ![4a  Configure image](https://github.com/user-attachments/assets/f0dc08fc-b013-4eda-9cfe-2a4304f5663d)
 
Nous allons utiliser les 2 images Azure Pipelines Windows Server 2022 et Ubuntu 20.04 car ils contiennent les outils necessaires pour configurer notre pipelines sans avoir besoin d'installer d'outils supplémentaires
- https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md
- https://github.com/actions/runner-images/blob/main/images/ubuntu/Ubuntu2004-Readme.md

   ![4b  Configure image](https://github.com/user-attachments/assets/9a3ab50a-54e7-4b84-8d6d-57888b5024ba)

  Cliquer sur Add puis sur Apply
  
   ![4c  Configure image](https://github.com/user-attachments/assets/306a0333-9437-4e21-9be5-0a678cf3782c)

7. **Configurer le pipeline de build :** <br>
   La configuration de notre Managed DevOps Pool est prête et opérationnelle, dans cette section, nous allons créer un pipeline dans azure devops et utiliser notre Managed DevOps Pool.
   
   Pour ce faire, il suffit de remplacer l'image par défaut (vmImage: ubuntu-latest) par notre  Managed DevOps Pool (name: datasynchro-managed-devops-pool-ado)

   ```yaml
   # Dans la configuration suivante, remplacer  vmImage: ubuntu-latest (où ubuntu-latest est l'image par defaut)  par  name: datasynchro-managed-devops-pool-ado (où datasynchro-managed-devops-pool-ado est le nom de notre managed devops pool)
   pool:
     vmImage: ubuntu-latest

   pool:
     name: datasynchro-managed-devops-pool-ado```

## B. Utilisation du managed devops pool dans un réseau privé
Dans la partie A , nous avons terminé la configuration de notre managed devops pool, qui est opérationnel pour des deploiements dans une architecture sans restriction réseaux. 
En effet, dans notre architecture mise en place cf  Fugure A, La function app ainsi que le compte de stockage sont privés , donc les agents par defaut du genre ubuntu-latest ou windows-latest ne pourront pas deployer du code dans la function app car les vm ne peuvent pas entrer dans notre réseau privé.
Pour résoudre ce blocage, nous allons ajouter notre managed devops pool dans un réseau virtual ( notre reseau interne)

1. **Configuration du networking :**

Ouvrir votre managed DevOps Pool under settings, selctionner Networking puis cliquer sur Agents injected into existing virtual network
Cliquer sur configure et selectionner notre réseau virtuel et le subnet 

![5a  networking](https://github.com/user-attachments/assets/f6cb85fa-bad1-4bde-831c-0e8702c50d5d)

2. **Terminer la congiguration :**

Notre Managed devops pool est configuré dans un vnet (managed-devops-pool-vnet) qui  est différant du vnet dans le quel est configuré notre function app (vnet-funcapp-dev).

Nous devons donc faire un peering entre les 2 vnet dans les deux sens  (vnet managed-devops-pool-vnet  <--->  peering avec le vnet vnet-funcapp-dev)

![6a  peering](https://github.com/user-attachments/assets/70a1052e-fa1f-4b0d-ac2d-e3ad74603269)

![6b  peering](https://github.com/user-attachments/assets/bd1f7c00-d717-4daa-833a-0e44c66fb0c2)


Enfin , étant donné que notre architecture utilise des privates endpoint, il nous faudra ajouter un Virtual Network Links entre nos virtual network vnet managed-devops-pool-vnet et  peering avec le vnet vnet-funcapp-dev  et les private dns zones ( privatelink.blob.core.windows.net  pour le compte de stockage et privatelink.azurewebsites.net pour la function app)
 

![7a vnet link](https://github.com/user-attachments/assets/186f4d16-d92c-4017-97f2-6448530ae0c0)

![7b vnet link](https://github.com/user-attachments/assets/c51aec3d-022e-4897-82ea-97bd7de103be)

## B. Summary 

Nous avons terminé la configuration d'un pool DevOps géré et l'avons ajouté à notre réseau privé pour pouvoir effectuer des déploiements au sein de notre architecture privée. Avec ce nouveau service maintenant en préversion publique, Microsoft introduit une fonctionnalité très importante et attendue dans le monde du DevOps : la mise en place d'agents DevOps privés.

En plus de cette fonctionnalité de mise en réseau, d'autres fonctionnalités clés ont été ajoutées. Je vous invite à lire le blog officiel pour plus d'informations : https://devblogs.microsoft.com/devops/managed-devops-pools/.

