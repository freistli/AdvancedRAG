# Step by Step: Integrate Advanced RAG Service with your own data into Copilot Studio

This post is going to explain how to use [Advanced RAG Service](https://techcommunity.microsoft.com/t5/modern-work-app-consult-blog/exploring-the-advanced-rag-retrieval-augmented-generation/ba-p/4197836) easily verify proper RAG tech performance for your own data, and integrate it as a service endpoint into Copilot Studio.

This time I will use CSV as a sample. CSV is structure data, when we use basic RAG to process a multiple pages CSV file as Vector Index and perform similarity search using Nature Language on it, the grounded data is always chunked and hardly make LLM to understand the whole data picture. 

For example, if we have 10,000 rows CSV file, when we ask "how many rows does the data contain and what's the mean value of the visits column", usually general semantic search service cannot give exact right answers if it just handles the data as unstructured. We need to use different advanced RAG method to handle the CSV data here.

Thanks to [LLamaIndex Pandas Query Engine](https://docs.llamaindex.ai/en/stable/examples/query_engine/pandas_query_engine/), which provides a good idea of understanding data frame data through natural language way. However how to verify its performance among others and integrate to existing Enterprise environment, such as Copilot Studio or other user facing services? 

It definitely needs AI service developing experience and takes certain learning curve and time efforts from POC to Production.

[Advanced RAG Service](https://techcommunity.microsoft.com/t5/modern-work-app-consult-blog/exploring-the-advanced-rag-retrieval-augmented-generation/ba-p/4197836) now supports 6 latest advacned indexing techs including CSV Query Eninge, with it developers can leverage it to shorten development POC stage, and achieve Production purpose. Here is detail step to step guideline:

## POC Stage

### Prerequist

Azure OpenAI Service: 

Deploy gpt-4o mini or gpt-4o model

Deploy text-embedding-ada-002 model

### Setup

    a. In Docker environment, run this command to clone the dockerfile and related config sample:

        git clone https://github.com/freistli/AdvancedRAG.git
    
    b. In the AdvancedRAG folder, rename .env_4_SC.sample to .env_4_SC

    c. To be continue...





