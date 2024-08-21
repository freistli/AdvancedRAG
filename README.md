# Advanced RAG (Retrieval Augmented Generation) Service

Advanced RAG AI Service running in Docker, it can be used as 

1. Quick MVP/POCm playground to verify which Index type can exactly address the specific (usually related to accuracy) LLM RAG use case.

2. [OpenAPI interface](https://github.com/freistli/AdvancedRAG/blob/main/CHANGELOG.md#08162024-121) and Gradio REST API interface are supported.

    Http Clients, Power platform workflow, and MS Office Word/Outlook Add-In can easily use proper vector index types to search doc info and generate LLM response from the service.


<img src="https://github.com/user-attachments/assets/71ca8893-e5f7-4f1b-9306-353cf599f333" alt="drawing" width="400"/>


## Introduction
The service can help developers quickly verify different RAG indexing techniques (about accuracy and performance) for their own user cases, from Index Generation to verify the output through Chat Mode and Proofreading mode.

It can run as local Docker or put it to Azure Container App, build and perform queries on multiple important Index types. Below is the info about index types and how the project implements them:
      
- Azure AI Search : Azure AI Search Python SDK + [Hybrid Semantic Search](https://techcommunity.microsoft.com/t5/ai-azure-ai-services-blog/azure-ai-search-outperforming-vector-search-with-hybrid/ba-p/3929167) + [Sub Question Query](https://docs.llamaindex.ai/en/v0.10.17/api_reference/query/query_engines/sub_question_query_engine.html)

- MS GraphRAG Local : REST APIs Provided by [GraphRAG accelerator](https://github.com/azure-samples/graphrag-accelerator)
  
- MS GraphRAG Global : REST APIs Provided by [GraphRAG accelerator](https://github.com/azure-samples/graphrag-accelerator)

- Knowledge Graph : [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/index_structs/knowledge_graph/KnowledgeGraphDemo/)

- Recursive Retriever : [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/retrievers/recursive_retriever_nodes/?h=recursive+retriever)

- Summary Index : [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/index_structs/doc_summary/DocSummary/)      

- CSV Query Engine: [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/query_engine/pandas_query_engine/)   


<img src="https://github.com/user-attachments/assets/e5d5da11-7091-4565-95ab-b6a1f0918283" alt="drawing" width="800"/>


<img src="https://github.com/user-attachments/assets/42b556a2-2862-4dc0-9511-25dd9a01ffc3" alt="drawing" width="800"/>

## Latest Features Update

Read in [Change Log](CHANGELOG.md)

## Source Code & Development

https://github.com/freistli/AdvancedRAG_SVC

## Quick Start


1. Download the repo:
   
```
git clone https://github.com/freistli/AdvancedRAG.git
```

2. IMPORTANT: Rename **.env.sample** to **.env**, input necessary environment variables. 

   **Azure OpenAI** resource and **Azure Document Intelligence** resource are must required.

   **Azure AI Search** is optional if you don't build Azure AI Search index or use it.

   **MS GRAPHRAG** is optional. If you want to use it please go through these steps to create GraphRAG backend service on Azure:
   https://github.com/azure-samples/graphrag-accelerator

    Check [Parameters](./Parameters.md) for more details.

3. Build docker image

```
docker build -t docaidemo .
```

4. Run it locally

```
docker run -p 8000:8000 docaidemo
```

5. Access it locally

http://localhost:8000


## Run it on Azure Container App

1. Publish your image to Azure Container Registry or Docker Hub

2. Create Azure Container App, choose the docker image you published, and then deploy the revision pod without any extra command.

Note: If you don't use .env in image, can set environment variables in the Azure Container App.


## Build Index

1. Click one Index Build tab
2. Upload a file to file section

   Note:  The backend is Azure Document Intelligence to read the content, in general it supports lots of file formats, recommend to use PDF (print it as PDF) if the content is complicated

   
3. Click Submit
4. Wait till the index building completed, the right pane will update the status in real time.
5. After you see this words, means it is completed:

```
2024-06-13T10:04:54.120027: Index is persisted in /tmp/index_cache/yourfilename
```

**/tmp/index_cache/yourfilename** can be used as your Index name.

6. You can download the index files to local by clicking the Download Index button, so that can use it in your own docker image

  ![image](https://github.com/user-attachments/assets/a7001056-09b9-4d7f-a08e-22d71fa865da)

  ![image](https://techcommunity.microsoft.com/t5/image/serverpage/image-id/608416iF3ADEB8A991407A0/image-size/large?v=v2&px=999)

  
## (Optional) Setup Your Own Index in the Docker Image

Developers can use their own indexes folders for the docker image:

To make it work:

 1. Move to the solution folder which contains the AdvancedRAG dockerfile
 2. Create a folder to keep the index, for example, index123
 3. Extract the index zip file you get from the step 6 in the "Build Index" section, save index files you downloaded into ./index123
 4. Build the docker image again.

After this, you can use index123 as index name in the Chat mode.

NOTE: You can use the same way to store CSV files, build them with docker if you want to try CSV Query Engine without file uploading.

## Call ADVRAGSVC through REST API CALL

### Endpoint 1: Chat API

  https://{BASEURL}/advchatbot/run/chat

#### METHOD

  POST

#### HEADER

 Content-Type: application/json

####  Sample Data

   ```
   {
     "data": [
       "When did the Author convince his farther",  <----- Prompt
       "", <--- History Object, don't change it
       "Azure AI Search",  <------ Index Type
       "azuresearch_0",   <------- Index Name or Folder
       "You are a friendly AI Assistant",    <----- System Message
       false   <---- Streaming flag, true or false
     ]
   }
   
```

### Endpoint 2: Proofread Addin API

  https://{BASEURL}/proofreadaddin/run/predict

NOTE: "rules" Index Name is predefined for Knowledge Graph Index of proofread addin. Please save Default knowledge graph index into **./rules/storage/rules_original**

#### METHOD

  POST

#### HEADER

 Content-Type: application/json

####  Sample Data

   ```
   {
  "data": [    
    "今回は半導体製造装置セクターの最近の動きを分析します。" , <---- Proofread Content
    false <--- Streaming flag, true or false
  ]
}
```

### Endpoint 3: CSV Query Engine API

  https://{BASEURL}/csvqueryengine/run/chat

#### METHOD

  POST

#### HEADER

 Content-Type: application/json

####  Sample Data

   ```
   {
  "data": [
    "how many records does it have",   
    "", 
    "CSV Query Engine",   
    "./rules/files/sample.csv",    
    "You are a helpful AI assistant. You can help users with a variety of tasks, such as answering questions, providing recommendations, and assisting with tasks. You can also provide information on a wide range of topics from the retieved documents. If you are unsure about something, you can ask for clarification. Please be polite and professional at all times. If you have any questions, feel free to ask." ,
    false   
  ]
}
```
## Consume the service in Office Add-In (use Proofread Addin use case)

Check: https://github.com/freistli/ProofreadAddin

## Integrate to Copilot Studio

[Step by Step: Integrate Advanced RAG Service with Your Own Data into Copilot Studio](https://techcommunity.microsoft.com/t5/modern-work-app-consult-blog/step-by-step-integrate-advanced-rag-service-with-your-own-data/ba-p/4215097)

## Try your index in Chat Mode

1. Click Chat Mode
2. Choose the Index type 
3. Put the index path or Azure AI Search Index name to Index Name text field
4. Now you can try to chat with the document with various system message if need.

## Proofread mode

This is specific for Proofread scenario, especially for non-English Languages. It needs you generate Knowlege Graph Index. 

Generating Knowledge Graph Index steps are the same as others.



## View Knowledge Graph Index 

1. Click the View Knowlege Graph Index tab
2. Put you Knowledge Graph Index name, and click Submit
3. Wait a while, click Download Knowledge Graph View to see the result.

![image](https://github.com/user-attachments/assets/6720ac13-604f-4c94-b638-b9aea807b04a)

