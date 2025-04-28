```mermaid
graph TD
    %% Define nodes with AWS service icons
    User((User))
    WAF[AWS WAF]
    CF[CloudFront Distribution]
    S3Web[S3 Website Bucket]
    APIG[API Gateway]
    Lambda[Lambda Function]
    S3Doc[S3 Document Bucket]
    Kendra[Amazon Kendra]
    Bedrock[Amazon Bedrock]
    
    %% Define connections
    User -->|1. Web Access| CF
    CF -->|2. Serve Static Content| S3Web
    User -->|3. API Queries| APIG
    APIG -->|4. Process Query| Lambda
    Lambda -->|5. Search Documents| Kendra
    Lambda -->|6. Generate Response| Bedrock
    Kendra -->|7. Index/Retrieve| S3Doc
    
    %% Security layer
    WAF -->|IP Filtering| CF
    WAF -->|IP Filtering| APIG
    
    %% Styling
    classDef user fill:#4285f4,stroke:#333,stroke-width:1px,color:white;
    classDef storage fill:#7AA116,stroke:#333,stroke-width:1px,color:white;
    classDef compute fill:#F37A12,stroke:#333,stroke-width:1px,color:white;
    classDef api fill:#4878BC,stroke:#333,stroke-width:1px,color:white;
    classDef ai fill:#232F3E,stroke:#333,stroke-width:1px,color:white;
    classDef security fill:#D13212,stroke:#333,stroke-width:1px,color:white;
    classDef distribution fill:#FF9900,stroke:#333,stroke-width:1px,color:white;
    
    %% Apply styles
    class User user;
    class S3Web,S3Doc storage;
    class Lambda compute;
    class APIG api;
    class Bedrock,Kendra ai;
    class WAF security;
    class CF distribution;
    
    %% Subgraphs for organization
    subgraph "Frontend Layer"
        CF
        S3Web
    end
    
    subgraph "API Layer"
        APIG
    end
    
    subgraph "Processing Layer"
        Lambda
    end
    
    subgraph "Storage Layer"
        S3Doc
    end
    
    subgraph "AI Services"
        Kendra
        Bedrock
    end
    
    subgraph "Security"
        WAF
    end