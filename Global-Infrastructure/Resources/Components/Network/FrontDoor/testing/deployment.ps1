





# Deploy using JSON parameters file
az deployment group create `
  --resource-group "rg-frontdoor" `
  --template-file "./frontdoor-cdn-profile.bicep" `
  --parameters "./frontdoor-cdn-profile.parameters.json"