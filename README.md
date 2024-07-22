# Advanced RAG (Retrieval Augmented Generation) Service

Advanced RAG AI Service running in Docker, it can be used as 

1. Quick MVP/POC/Play Ground to verify which Index type can address the specific (usually related to accuracy) RAG use case.
2. Http Clients and Word Add-In can use proper vector index types to search doc info and generate LLM response from the service:

<img src="https://github.com/user-attachments/assets/71ca8893-e5f7-4f1b-9306-353cf599f333" alt="drawing" width="600"/>

## Introduction
The service can help developers quickly verify diffrent RAG indexing techniques (about accuracy and performance) for their own user cases, from Index Generation to verify the output through Chat Mode and Proofreading mode.

It can run as local Docker or put it to Azure Container App, build and perform queries on multiple importnat Index types. Below is the info about index types and how the project implements them:
      
- Azure AI Search : Azure AI Search Python SDK

- MS GraghRAG Local : REST APIs Provided by GraghRAG accelerator
  
- MS GraghRAG Global : REST APIs Provided by GraghRAG accelerator

- Knowledge Graph : LlamaIndex

- Recursive Retriever : LlamaIndex

- Summary Index : LlamaIndex      

<img src="https://github.com/user-attachments/assets/e5d5da11-7091-4565-95ab-b6a1f0918283" alt="drawing" width="800"/>


## Quick Start


1. Download the repo:
   
```
git clone https://github.com/freistli/AdvancedRAG.git
```

4. IMPORTANT: Rename **.env_4_SC.sample** to **.env_4_SC**, input necessary environment variables. 

   **Azure OpenAI** resource and **Azure Document Intellegency** resource are must required.

   **Azure AI Search** is optional if you don't build Azure AI Search index or use it.

   **MS GRAPHRAG** is optional. If you want to use it please go through these steps to create GraphRAG backend service on Azure:
   https://github.com/azure-samples/graphrag-accelerator

5. Build docker image

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

1. Publish your image to Azure Container Registry or Docke Hub

2. Create Azure Container App, choose the docker image you published, and then deploy the revision pod witout any extra command.

Note: If you don't use .env_4_SC in image, can set environment variables in the Azure Container App.


## Build Index

1. Click one Index Build tab
2. Upload a file to file section

   Note:  The backend is Azure Document Intellegence to read the content, in general it supports lots of file formats, recommend to use PDF (print it as PDF) if the content is complicated

   
3. Click Submit
4. Wait till the index building completed, the right pane will update the status in real time.
5. After you see this words, means it is completed:

```
2024-06-13T10:04:54.120027: Index is persisted in /tmp/index_cache/yourfilename
```

**/tmp/index_cache/yourfilename** can be used as your Index name.

6. You can download the index files to local by clicking the Download Index button, so that can use it in your own docker image

  ![image](https://github.com/user-attachments/assets/a7001056-09b9-4d7f-a08e-22d71fa865da)


## (Optional) Setup Defaut Rules Index

"rules" Index Name is predefined for Knowledge Graph Index of Japanese proofread demo in this solution. Developers can use their own indexes in other folders for the docker:

To make it work:

 1. Move to the folder which contains the AdvancedRAG dockerfile
 2. Create a folder to keep the index, for example, index123
 3. Extract the index zip file you get from the step 6 in the "Build Index" section, save index files you downloaded into ./index123
 4. Build the docker image again.

After this, you can use index123 as index name in the Chat mode.

## Call ADVRAGSVC through REST API CALL

### Endpoint 

  https://{BASEURL}/advchatbot/run/chat

### METHOD

  POST

### HEADER

 Content-Type application/json

###  Sample Data

   ```
   {
     "data": [
       "When did the Author convince his farther",  <----- Prompt
       "", <--- History Object, don't change it
       "Azure AI Search",  <------ Index Type
       "azuresearch_0",   <------- Index Name or Folder
       "You are a friendly AI Assistant"    <----- System Message
     ]
   }
   
```

### Endpoint 

  https://{BASEURL}/proofreadaddin/run/predict

### METHOD

  POST

### HEADER

 Content-Type application/json

###  Sample Data

   ```
   {
  "data": [    
    "今回は半導体製造装置セクターの最近の動きを分析します。" , <---- Proofread Content
    "False" <--- Streaming
  ]
}
```
## Consume the service in Office Add-In (use Proofread Addin use case)

Check: https://github.com/freistli/ProofreadAddin

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

![image](https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/25feda62-6287-4a93-a511-699fea1442f1)

![image](https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/9be1a084-25e9-4fa9-8da8-e6105d568cfc)
