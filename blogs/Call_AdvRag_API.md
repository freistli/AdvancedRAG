# How to call Advanced RAG service through OpenAPI spec

## Understand the API parameters and responses

    http://localhost:8000/openapi/info/2

    Note: 
    
    This is swagger 2. 
    
    It is for Power Platform Connector access purpose because it only supports swagger 2 spec.


    http://localhost:8000/openapi/info/3

    Note: 
    
    This is OpenAPI 3.0. 
    
    This can be used by any HTTP client, including Office Addin, Copilot Studio, Declarative Copilot, and Copilot OpenAPI Plugin.


## Sample Request

### With chat history

POST http://localhost:8000/api/chat

content-type: application/json

```
 {
 "history": [
     
     [
         "What is the main topic of this article?",
         "The main topic of this article is about the Advanced RAG Service Studio."
     ]
     
 ],
 "indexName": "azuresearch_0",
 "indexType": "Azure AI Search",
 "message": "What is the main topic of this article?",
 "streaming": false,
 "systemMessage": "You are a helpful AI assistant. Answer questions clearly with only necessary words and completed sentences."
 }
 ```

 ### Without chat history

 
POST http://localhost:8000/api/chat

content-type: application/json

```
{ 
    "message": "provide summary for the document",
    "history": [],    
    "indexType":"Tree Mode Summary",   
    "indexName":"TM01",    
    "systemMessage":"You are a friendly AI Assistant" ,
    "streaming":false     
}

```

## Sample Response

```
{
  "response": "Here is the summary [1][2]",
  "citations": ["Source 1: content...","Source 2: content..."]
}
```