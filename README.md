# Advanced RAG Service - Container Version

RAG = Retrieval Augmented Generation

## Project Overview

This project serves as a quick Minimum Viable Product (MVP) or Proof of Concept (POC) playground. It is designed to verify which type of index can most accurately address specific use cases related to Large Language Models (LLMs) and Retrieval-Augmented Generation (RAG). These use cases are usually concerned with accuracy versus time/cost tradeoffs.

By using a smaller, flexible, multi-algorithm testing environment you can understand the trade-offs on small dataset and measure the return on investment that you will get for the costs of various systems.

## Containerized Advanced RAG

This repository is designed to build a containerized version of the service.
While the Advanced RAG AI Service runs inside Docker it can be used as both:

1. Quick MVP/POCm playground to verify which Index algorithm and retrieval algorithm can address the specific (accurate) LLM RAG use case.

2. [OpenAPI interface](https://github.com/freistli/AdvancedRAG/blob/main/blogs/Call_AdvRag_API.md) and Gradio REST API interface are supported.

This means, Http Clients, Power platform workflows, and MS Office Word/Outlook Add-In can easily use proper vector index types to search document information and generate an LLM response using the retrieved infromation.  

<img src="https://github.com/user-attachments/assets/71ca8893-e5f7-4f1b-9306-353cf599f333" alt="drawing" width="400"/>

## Why use AdvancedRAG as a playground?

AdvancedRAG provides a valuable playground for building AI-based applications. Here are some reasons why it is useful:

1. **Fast start**: AdvancedRAG allows you to quickly explore and experiment with different approaches to obtain accurate responses. This saves you time and effort in finding the best approach for your specific use case.

2. **Multiple options**: With AdvancedRAG, you have access to a wide range of options. You can compare different approaches, prompts, system prompts, and hyperparameters to fine-tune your AI models and improve their performance.

3. **Integration flexibility**: Once you have identified the optimal configuration in the playground, you can easily integrate AdvancedRAG with other parts of your solution using FAST APIs. This enables seamless integration of AI capabilities into your applications.

By leveraging the capabilities of AdvancedRAG, you can accelerate the development of AI-based applications, improve accuracy, and achieve better results in a shorter time frame.

## What's included?

The service can help developers quickly check different RAG indexing techniques for accuracy, performance and computational cost.  They can also explore prompts for generating output or use interactive chat mode questioning of the knowledge in the documents.   An additonal Proofreading mode is supplied to apply a ruleset to a document.

The docker container can be run locally, or in the cloud e.g az an Azure Contasiner Appps.  While running it can build indexes and perform queries using multiple important state of the art Index types to allow them to be tested one after another. More information about these indexes is included below: 

### Azure AI Search:

- Azure AI Search: Azure AI Search Python SDK + [Hybrid Semantic Search](https://techcommunity.microsoft.com/t5/ai-azure-ai-services-blog/azure-ai-search-outperforming-vector-search-with-hybrid/ba-p/3929167) + [Sub Question Query](https://docs.llamaindex.ai/en/v0.10.17/api_reference/query/query_engines/sub_question_query_engine.html)
   Azure AI Search: Azure AI Search utilizes the Azure AI Search Python SDK along with Hybrid Semantic Search and Sub Question Query techniques. It is commonly used for performing advanced search operations on large datasets, providing accurate and relevant search results.

### GraphRAG provided from MS Research
  - MS GraghRAG Local: REST APIs Provided by [GraghRAG accelerator](https://github.com/azure-samples/graphrag-accelerator)
  - MS GraghRAG Global: REST APIs Provided by [GraghRAG accelerator](https://github.com/azure-samples/graphrag-accelerator)
    - MS GraghRAG Local: MS GraghRAG Local utilizes REST APIs provided by the GraghRAG accelerator. It is a technology used for retrieval-augmented generation, combining retrieval-based methods with generative models to improve the accuracy and relevance of generated content.  
    
    Note:  Be aware of costs --this is an advanced technique and uses a significant number of Azure services to create high quality indexes.    https://www.microsoft.com/en-us/research/blog/graphrag-unlocking-llm-discovery-on-narrative-private-data/
    
### Advanced Indexing techniques from LlamdaIndex
- Knowledge Graph: [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/index_structs/knowledge_graph/KnowledgeGraphDemo/)
  - Knowledge Graph: Knowledge Graph is a technology provided by LlamaIndex. It is used for building and querying graph-based knowledge representations, allowing for efficient and comprehensive knowledge retrieval.
- Recursive Retriever: [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/retrievers/recursive_retriever_nodes/?h=recursive+retriever)
  - Recursive Retriever: Recursive Retriever is a technique provided by LlamaIndex. It is used for performing recursive retrieval on hierarchical data structures, enabling efficient and accurate retrieval of information from nested contexts.
- Summary Index: [LlamaIndex](https://docs.llamaindex.ai/en/latest/api_reference/indices/summary/)
  - Summary Index: Summary Index is a feature provided by LlamaIndex. It is used for creating and querying summary indices, allowing for quick and concise retrieval of key information from large datasets.
  
  Note:  Be aware of costs -- different indexes use different algorithms and may use more tokens from LLMs.  

- CSV Query Engine: [LlamaIndex](https://docs.llamaindex.ai/en/stable/examples/query_engine/pandas_query_engine/)   

<img src="https://github.com/user-attachments/assets/e5d5da11-7091-4565-95ab-b6a1f0918283" alt="drawing" width="800"/>


<img src="https://github.com/user-attachments/assets/42b556a2-2862-4dc0-9511-25dd9a01ffc3" alt="drawing" width="800"/>

## Latest Features Update

Please check the [Change Log](CHANGELOG.md)

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

3. Input an Index name, click Submit
4. Wait till the index building completed, the right pane will update the status in real time.
5. After you see this words, means it is completed:

```
2024-06-13T10:04:54.120027: Index is persisted in /tmp/index_cache/yourindexname
```

**/tmp/index_cache/yourindexname** or **yourindexname** can be used as your Index name.

6. You can download the index files to local by clicking the Download Index button, so that can use it in your own docker image

  ![image](/blogs/media/9.png)

  ![image](/blogs/media/10.png)

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

