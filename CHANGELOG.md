## 08/15/2024 [1.2.0]

1. Add auto-deployment scripts deploy_aoai.sh, deploy_acr_app.sh, and deploy_storage.sh

2. Azure Container App can mount Azure File Share with deploy_storage.sh. This is for scaling out infra in production.

3. Add Defaut_Storage setting in .env.sample for non temporary storage.

4. Multiple files Index processing for Azure AI Search, Knowledge Graph, Summary, and Recursive Retriever.

5. Index Name can be short index name or full index folder path for Knowledge Graph, Summary, and Recursive Retriever now. 

