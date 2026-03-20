# Classic Invoice BCDR Infrastructure Automation Knowledgebase

1. **Introduction**
   
   #### This solution will create all needed resources in the failover region.
   #### This solution will configure Vms after failover

2. **List of Unique Main Files Used for BCDR Activities**
   1. Invoice.Global.Infrastructure\ArmDeployers\ClassicInvoice\azuredeploy.json
   2. Invoice.Global.Infrastructure\ArmDeployers\ClassicInvoice\azuredeploy.parameters-ppe-bcdr.json
   3. Invoice.Global.Infrastructure\ArmDeployers\ClassicInvoice\azuredeploy.parameters-prd-bcdr.json
   4. Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-resources.json
   5. Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-vm-configuration.json
   6. Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-vm-extensions.json
   7. Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-vm-scripts.json
3. **Understanding the Parameter File azuredeploy.parameters-[env]-bcdr.json**
   1. **artifactsSaBaseUri** = the base url with the container name of the storge account with all the templates have been copied to. i.e https://invrprdsaclassicglobal.blob.core.windows.net/armresources
   2. **artifactsSaSasToken** = A SAS token to access the above storage account
   3. **baseName** = 3 to 5 letters prefix to name all resources
   4. **environment** = 3 to 5 letters enviroment
   5. **isBCDR** = This flag will be set to true for bcdr purposes. The default value is false
   6. **deploymentFlags**
      * **isNewEnvironment** = When set to true, the deployment will create all resources from scratch. Therefore all secrets defined under settings/secretManager/secrets/secretList need to be passed so they can be populated into the application keyvault.
      * **deployCommonStorage** = When set to true, the deployment will create the storage accounts defined under setting/common/storage.
      * **deploySecrets** = When set to true, all secrets defined under settings/secretManager/secrets/secretList will be pushed into the application keyvault.
      * **setAppKeyVaultPermissions** = When set to true, accounts listed under settings/secretManager/permissions/accountList will be added to the keyvault access policy.
      * **deployAlertingMonitoring** = When set to true, it will create all alerts and configuration defined in Invoice.Global.Infrastructure\ArmResources\Components\Classic\Common\alerting-monitoring.json
      * **deployAutomationBundle** = When set to true, it will create all alerts and configuration defined in Invoice.Global.Infrastructure\ArmResources\Components\Classic\Common\automation-bundle.json
      * **deployRecoveryServices** = When set to true, it will create all alerts and configuration defined in Invoice.Global.Infrastructure\ArmResources\Components\Classic\Recovery\recovery-services.json
      * **deployCacheServices** = When set to true, it will create all alerts and configuration defined in Invoice.Global.Invoice.Global.Infrastructure\ArmResources\Components\Classic\CacheServices\cache-services.json
      * **bcdrRebuildFailoverServers** = When true, the vm extesnion and are reinstalled and if it a windows cluster it will rebuild the cluster Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-vm-configuration.json
      * **deployIIS** = Leave always as false for BCDR.
      * **deployIIS2** = Leave always as false for BCDR.
   7. **settings**
      * **common** = Environmental properties that are used accross all the this template solution
      * **secretManager** = Environmental properties that are used in the configuration of the application keyvault.
      * **automationAccount** = Enviromental properties that are used in the configuration of the enviroment automation account.
      * **cacheServices** = Environmental properties that are used for the configuration of cache services. In this case we only use Redis cache.
      * **recoveryServices** = Environmental properties for the configuration of Azure Site Recovery (ASR) and the creation of an automation account and storage account that is needed by ASR.
      * **BCDRResources** = Environmental properties to create Load Balancers and Availability Sets that are needed by the IaaS VMs after failover using ASR. This setion is used to trigger Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-resources.json The **loadBalancedComponents** array used to define the environmental properties of each component that needs a load balancer. The **avsetComponentList** defines a list of components that need an availability. all IaaS Components need one.
      * **DRVMDetails** = Environmental properties that define IaaS components that need to be reconfigured after ASR failover. This setion is used to trigger Invoice.Global.Infrastructure\ArmResources\Components\Classic\BCDR\bcdr-vm-configuration.json. This will take of installing all required vm extensions it will also run scripts to rebuild the servers and clusters. Each component object within this array is defined as: 
        * **serverTag** = The tag used for the component.
        * **vmNames** = The list of vm names that are part of this component.
        * **resourceGroupName** = The resource group name where ASR will failover the vms.
        * **clusterType** = 
          * if it is not a clustered component, set it as "None"
          * if it is a sql always on cluster, set it as "AlwaysOn"
          * if it is a file server cluster, set it as "S2D"
        * **clusterRoleName** =
          * if it is not a clustered component, set it as "None"
          * this value is the name of the cluster role. When you open cluster manager and select **"Roles"** you should be able to see it. If the vms were created with the solution, this value should be for sql always on cluster **[baseName][serverTag][environment]**. For File Cluster should be **[baseName][serverTag][environment][listenerNamePostFix]**
4. **BCDR Activities**
   1. **Last Failover Documentation**
      * [FailoverActivities](https://microsoft.sharepoint.com/:w:/t/MicrosoftInvoiceCentral/EayOFmlchfFClSbv90anJcIBEcefDZ3A-bHJnf5Sap4MTQ?e=A1ve4i)

<br>