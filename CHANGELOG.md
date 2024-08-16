## 08/16/2024 [1.2.1]
1. Add Swagger 2.0, OpenAPI 3.0 URLs:

   /api/info/2

   /api/info/3

2. Add OpenAPI API Call: /api/chat

   ```
    {
    "history": [
        [
        [
            "What is the main topic of this article?",
            "The main topic of this article is about the Advanced RAG Service Studio."
        ]
        ]
    ],
    "indexName": "azuresearch_0",
    "indexType": "Azure AI Search",
    "message": "What is the main topic of this article?",
    "streaming": false,
    "systemMessage": "You are a helpful AI assistant. Answer questions clearly with only necessary words and completed sentences."
    }
   ```

3. Add OpenAPI toggle settings in .env.sample

## 08/15/2024 [1.2.0]

1. Add auto-deployment scripts deploy_aoai.sh, deploy_acr_app.sh, and deploy_storage.sh

2. Azure Container App can mount Azure File Share with deploy_storage.sh. This is for scaling out infra in production.

3. Add Default_Storage setting in .env.sample for non temporary storage.

4. Multiple files Index processing for Azure AI Search, Knowledge Graph, Summary, and Recursive Retriever.

5. Index Name can be short index name or full index folder path for Knowledge Graph, Summary, and Recursive Retriever now. 

