import boto3
import json
import os

# Initialize AWS clients
bedrock_runtime = boto3.client('bedrock-runtime')
kendra = boto3.client('kendra')
s3 = boto3.client('s3')

def lambda_handler(event, context):
    # Extract user query from the request
    body = json.loads(event.get('body', '{}'))
    query = body.get('query', '')
    
    if not query:
        return {
            'statusCode': 400,
            'body': json.dumps({'error': 'Missing query parameter'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
    
    # Step 1: Search documents with Kendra
    kendra_index_id = os.environ.get('KENDRA_INDEX_ID')
    try:
        kendra_response = kendra.query(
            QueryText=query,
            IndexId=kendra_index_id
        )
    except Exception as e:
        print(f"Error querying Kendra: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Error searching documents'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
    
    # Step 2: Format context from relevant documents
    context = ""
    for result in kendra_response.get('ResultItems', []):
        if result.get('Type') == 'DOCUMENT':
            document_title = result.get('DocumentTitle', {}).get('Text', 'Unknown Document')
            document_excerpt = result.get('DocumentExcerpt', {}).get('Text', '')
            context += f"Document: {document_title}\nExcerpt: {document_excerpt}\n\n"
    
    if not context:
        context = "No relevant information found in the documents."
    
    # Step 3: Generate response using Amazon Bedrock (Claude)
    try:
        bedrock_model_id = os.environ.get('BEDROCK_MODEL_ID', 'anthropic.claude-3-sonnet-20240229-v1:0')
        request_body = {
            "modelId": bedrock_model_id,
            "contentType": "application/json",
            "accept": "application/json",
            "body": json.dumps({
                "anthropic_version": "bedrock-2023-05-31",
                "max_tokens": 1000,
                "temperature": 0.7,
                "messages": [
                    {
                        "role": "user",
                        "content": f"You are a helpful assistant answering questions based on the following document context:\n\n{context}\n\nThe query is: {query}\n\nPlease answer based on the information provided in the context. If the context doesn't contain relevant information to answer the query, please say so."
                    }
                ]
            })
        }
        
        bedrock_response = bedrock_runtime.invoke_model(**request_body)
        response_body = json.loads(bedrock_response.get('body').read())
        assistant_response = response_body.get('content')[0].get('text')
        
        return {
            'statusCode': 200,
            'body': json.dumps({'response': assistant_response}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
    except Exception as e:
        print(f"Error generating response with Bedrock: {e}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Error generating response'}),
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'OPTIONS,POST'
            }
        }
