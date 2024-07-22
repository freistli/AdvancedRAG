# Advanced RAG (Retrieval Augmented Generation) Service

Advanced RAG AI Service running in Docker, it can be used as 

1. Quick MVP/POC/Play Ground to verify which Index type can address the specific (usually related to accuracy) RAG use case.
2. Http Clients and Word Add-In can use proper vector index types to search doc info and generate LLM response from the service:

<img src="https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/86bcfc57-1409-4c63-97c3-969f6b7abd87" alt="drawing" width="600"/>


## Introduction
The service can help developers quickly verify diffrent RAG indexing techniques (about accuracy and performance) for their own user cases, from Index Generation to verify the output through Chat Mode and Proofreading mode.

It can run as local Docker or put it to Azure Container App.

Can work with
      
      Knowledge Graph Indexing
      
      Recursive Retriever query
      
      Tree Mode Summarization
      
      Semantic Hybrid Search + Sub Query Engine with Azure OpenAI

      Microsoft Graph RAG (Local Search + Global Search)
      

<img src="https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/fb2a5762-30a3-46e8-8f8d-c000f4695b18" alt="drawing" width="600"/>

<img src="https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/e8459e09-6785-431d-8de7-7139d84e5e16" alt="drawing" width="600"/>

<img src="https://github.com/user-attachments/assets/580be8d8-4ace-40a9-9337-f4ae17c83ec6" alt="drawing" width="600"/>


## Quick Start


1. git clone https://github.com/freistli_microsoft/AdvancedRAG.git

2. IMPORTANT: Rename **.env_4_SC.sample** to **.env_4_SC**, input necessary environment variables. 

   Azure OpenAI resource and Azure Document Intellegency resource are must required.

   Azure AI Search is optional if you don't build Azure AI Search index or use it.

   MS GRAPHRAG is optional. If you want to use it please go through these steps to create GraphRAG backend service on Azure:
   https://github.com/azure-samples/graphrag-accelerator

4. Build docker image

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

6. You can download the index to local by clicking the Download Index button, so that can use it in your own docker image

  ![image](https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/00460511-2d60-4956-bbd7-9c16d818fa18)

## (Optional) Setup Defaut Rules Index

"rules" Index Name is predefined for Knowledge Graph Index in this solution. It is recommended if you want to use Proofreadaddin REST API Call (Explained below).

To make it work:

 1. Save Default KG index into ./rules/storage/rules_original

 2. (Optional) Save Trained KG index into ./rules/storage/rules_train

  ![image](https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/4c499fee-be42-4049-97ca-54f8f4f697b1)

  ![image](https://github.com/freistli_microsoft/AdvancedRAG/assets/117236408/a75fe8e3-f420-4187-91a5-a199b8e19bc5)


## Call ADVRAGSVC through REST API CALL

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
    "rules",       <------- Index Name or Folder
    "Criticize the proofread content, especially for wrong words..", <----- System Message
 "今回は半導体製造装置セクターの最近の動きを分析します。" <----- Prompt
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
