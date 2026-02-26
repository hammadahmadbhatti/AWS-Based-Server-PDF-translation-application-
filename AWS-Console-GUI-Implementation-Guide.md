# AWS PDF Translator - Complete AWS Console GUI Implementation Guide

## Table of Contents

1. [Prerequisites & Account Setup](#1-prerequisites--account-setup)
2. [Phase 1: Create IAM Role](#2-phase-1-create-iam-role)
3. [Phase 2: Create S3 Buckets](#3-phase-2-create-s3-buckets)
4. [Phase 3: Create DynamoDB Table](#4-phase-3-create-dynamodb-table)
5. [Phase 4: Create Cognito User Pool](#5-phase-4-create-cognito-user-pool)
6. [Phase 5: Create Lambda Functions](#6-phase-5-create-lambda-functions)
7. [Phase 6: Create API Gateway](#7-phase-6-create-api-gateway)
8. [Phase 7: Configure S3 Event Trigger](#8-phase-7-configure-s3-event-trigger)
9. [Phase 8: Create CloudFront Distribution](#9-phase-8-create-cloudfront-distribution)
10. [Phase 9: Deploy Frontend](#10-phase-9-deploy-frontend)
11. [Phase 10: Testing](#11-phase-10-testing)

---

## 1. Prerequisites & Account Setup

### 1.1 Create AWS Account (if needed)

1. Go to **https://aws.amazon.com**
2. Click **"Create an AWS Account"** (top right)
3. Follow the registration process:
   - Enter email address
   - Create password
   - Enter account name
   - Add payment information (credit card required)
   - Verify phone number
   - Select support plan (Free tier is fine)

### 1.2 Sign In to AWS Console

1. Go to **https://console.aws.amazon.com**
2. Enter your email and password
3. You'll see the AWS Management Console home page

### 1.3 Select Your Region

1. Look at the **top-right corner** of the console
2. Click the region name (e.g., "N. Virginia")
3. Select **"US East (N. Virginia) us-east-1"** from the dropdown
   - This region has all required services
   - Keep this region selected throughout the guide

### 1.4 Note Your Account ID

1. Click your **account name** in the top-right corner
2. Your **12-digit Account ID** will be displayed
3. **Write this down** - you'll need it for bucket names and policies

```
Example Account ID: 123456789012
```

---

## 2. Phase 1: Create IAM Role

The IAM role allows Lambda functions to access other AWS services.

### Step 1: Navigate to IAM

1. In the AWS Console search bar at the top, type **"IAM"**
2. Click **"IAM"** from the results
3. You'll see the IAM Dashboard

### Step 2: Create New Role

1. In the left sidebar, click **"Roles"**
2. Click the **"Create role"** button (blue button, top right)

### Step 3: Select Trusted Entity

1. **Trusted entity type**: Select **"AWS service"**
2. **Use case**: 
   - Under "Service or use case", select **"Lambda"**
   - Click the **"Lambda"** radio button
3. Click **"Next"** button

### Step 4: Add Permissions Policies

1. In the search box, type **"AWSLambdaBasicExecutionRole"**
2. Check the box next to **"AWSLambdaBasicExecutionRole"**
3. Clear the search box, then search for **"AWSXRayDaemonWriteAccess"**
4. Check the box next to **"AWSXRayDaemonWriteAccess"**
5. Click **"Next"** button

### Step 5: Name and Create Role

1. **Role name**: Enter `pdf-translator-lambda-role-dev`
2. **Description**: Enter `Lambda execution role for PDF Translator service`
3. Scroll down and click **"Create role"** button
4. You'll see a green success message

### Step 6: Add Custom Inline Policies

Now we need to add specific permissions for S3, DynamoDB, and Translate.

1. Click on the role name **"pdf-translator-lambda-role-dev"** to open it
2. Click the **"Add permissions"** dropdown button
3. Select **"Create inline policy"**

#### Policy 1: S3 Access

1. Click the **"JSON"** tab (instead of Visual editor)
2. Delete the existing content and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::pdf-translator-uploads-dev-YOUR_ACCOUNT_ID/*",
                "arn:aws:s3:::pdf-translator-outputs-dev-YOUR_ACCOUNT_ID/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListBucket",
            "Resource": [
                "arn:aws:s3:::pdf-translator-uploads-dev-YOUR_ACCOUNT_ID",
                "arn:aws:s3:::pdf-translator-outputs-dev-YOUR_ACCOUNT_ID"
            ]
        }
    ]
}
```

3. **IMPORTANT**: Replace `YOUR_ACCOUNT_ID` with your actual 12-digit account ID (4 places)
4. Click **"Next"**
5. **Policy name**: Enter `S3Access`
6. Click **"Create policy"**

#### Policy 2: DynamoDB Access

1. Click **"Add permissions"** → **"Create inline policy"** again
2. Click **"JSON"** tab and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:PutItem",
                "dynamodb:UpdateItem",
                "dynamodb:DeleteItem",
                "dynamodb:Query"
            ],
            "Resource": [
                "arn:aws:dynamodb:us-east-1:YOUR_ACCOUNT_ID:table/pdf-translator-jobs-dev",
                "arn:aws:dynamodb:us-east-1:YOUR_ACCOUNT_ID:table/pdf-translator-jobs-dev/index/*"
            ]
        }
    ]
}
```

3. Replace `YOUR_ACCOUNT_ID` with your account ID (2 places)
4. Click **"Next"**
5. **Policy name**: Enter `DynamoDBAccess`
6. Click **"Create policy"**

#### Policy 3: Translate Access

1. Click **"Add permissions"** → **"Create inline policy"** again
2. Click **"JSON"** tab and paste:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "translate:TranslateText",
                "translate:TranslateDocument",
                "comprehend:DetectDominantLanguage"
            ],
            "Resource": "*"
        }
    ]
}
```

3. Click **"Next"**
4. **Policy name**: Enter `TranslateAccess`
5. Click **"Create policy"**

### Step 7: Copy Role ARN

1. On the role summary page, find **"ARN"**
2. Click the **copy icon** next to it
3. Save this ARN somewhere - you'll need it for Lambda functions

```
Example: arn:aws:iam::123456789012:role/pdf-translator-lambda-role-dev
```

---

## 3. Phase 2: Create S3 Buckets

We need 3 buckets: uploads, outputs, and frontend.

### 3.1 Create Upload Bucket

#### Step 1: Navigate to S3

1. In the search bar, type **"S3"**
2. Click **"S3"** from the results

#### Step 2: Create Bucket

1. Click **"Create bucket"** button (orange button)

#### Step 3: Configure Bucket

1. **Bucket name**: Enter `pdf-translator-uploads-dev-YOUR_ACCOUNT_ID`
   - Replace YOUR_ACCOUNT_ID with your 12-digit account ID
   - Example: `pdf-translator-uploads-dev-123456789012`
2. **AWS Region**: Should already be **US East (N. Virginia) us-east-1**

#### Step 4: Object Ownership

1. Keep **"ACLs disabled (recommended)"** selected

#### Step 5: Block Public Access

1. Keep **"Block all public access"** checked ✅
2. Check the acknowledgment box at the bottom

#### Step 6: Bucket Versioning

1. Keep **"Disabled"** selected (saves costs)

#### Step 7: Default Encryption

1. **Encryption type**: Select **"Server-side encryption with Amazon S3 managed keys (SSE-S3)"**
2. **Bucket Key**: Keep **"Enable"** selected

#### Step 8: Create Bucket

1. Scroll down and click **"Create bucket"**
2. You'll see a green success message

#### Step 9: Configure CORS

1. Click on your new bucket name to open it
2. Click the **"Permissions"** tab
3. Scroll down to **"Cross-origin resource sharing (CORS)"**
4. Click **"Edit"**
5. Paste the following:

```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "PUT", "POST"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": [],
        "MaxAgeSeconds": 3600
    }
]
```

6. Click **"Save changes"**

#### Step 10: Configure Lifecycle Rules

1. Click the **"Management"** tab
2. Under **"Lifecycle rules"**, click **"Create lifecycle rule"**

**Rule 1: Delete Incomplete Uploads**
1. **Lifecycle rule name**: `DeleteIncompleteUploads`
2. **Choose a rule scope**: Select **"Apply to all objects in the bucket"**
3. Check the acknowledgment box
4. **Lifecycle rule actions**: Check **"Delete expired object delete markers or incomplete multipart uploads"**
5. Under **"Delete incomplete multipart uploads"**: Enter `1` day
6. Click **"Create rule"**

**Rule 2: Delete Old Uploads**
1. Click **"Create lifecycle rule"** again
2. **Lifecycle rule name**: `DeleteOldUploads`
3. **Choose a rule scope**: Select **"Limit the scope of this rule using one or more filters"**
4. **Prefix**: Enter `uploads/`
5. **Lifecycle rule actions**: Check **"Expire current versions of objects"**
6. **Days after object creation**: Enter `7`
7. Check the acknowledgment box
8. Click **"Create rule"**

---

### 3.2 Create Output Bucket

1. Go back to S3 main page (click **"Amazon S3"** → **"Buckets"** in breadcrumb)
2. Click **"Create bucket"**
3. **Bucket name**: `pdf-translator-outputs-dev-YOUR_ACCOUNT_ID`
4. Keep all other settings the same as Upload bucket:
   - Block all public access: ✅
   - SSE-S3 encryption
5. Click **"Create bucket"**

#### Configure CORS for Output Bucket

1. Click on the output bucket
2. Go to **"Permissions"** tab
3. Scroll to **"Cross-origin resource sharing (CORS)"**
4. Click **"Edit"** and paste:

```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET"],
        "AllowedOrigins": ["*"],
        "ExposeHeaders": [],
        "MaxAgeSeconds": 3600
    }
]
```

5. Click **"Save changes"**

---

### 3.3 Create Frontend Bucket

1. Go back to S3 buckets list
2. Click **"Create bucket"**
3. **Bucket name**: `pdf-translator-frontend-dev-YOUR_ACCOUNT_ID`
4. **Block all public access**: Keep checked ✅
5. Click **"Create bucket"**

#### Enable Static Website Hosting

1. Click on the frontend bucket
2. Click the **"Properties"** tab
3. Scroll down to **"Static website hosting"**
4. Click **"Edit"**
5. **Static website hosting**: Select **"Enable"**
6. **Hosting type**: Select **"Host a static website"**
7. **Index document**: Enter `index.html`
8. **Error document**: Enter `index.html`
9. Click **"Save changes"**

---

## 4. Phase 3: Create DynamoDB Table

### Step 1: Navigate to DynamoDB

1. In the search bar, type **"DynamoDB"**
2. Click **"DynamoDB"** from the results

### Step 2: Create Table

1. Click **"Create table"** button

### Step 3: Configure Table

1. **Table name**: Enter `pdf-translator-jobs-dev`
2. **Partition key**: Enter `jobId` (keep type as **String**)
3. **Sort key**: Leave empty

### Step 4: Table Settings

1. Select **"Customize settings"**

### Step 5: Read/Write Capacity

1. **Capacity mode**: Select **"On-demand"**
   - This is pay-per-request and more cost-effective for variable workloads

### Step 6: Create Table

1. Scroll down and click **"Create table"**
2. Wait for the table status to change to **"Active"** (may take a minute)

### Step 7: Create Global Secondary Index (GSI)

1. Click on the table name **"pdf-translator-jobs-dev"**
2. Click the **"Indexes"** tab
3. Click **"Create index"**
4. Configure the index:
   - **Partition key**: Enter `userId` (String)
   - **Sort key**: Enter `createdAt` (String)
   - **Index name**: Enter `UserIndex`
   - **Projected attributes**: Select **"All"**
5. Click **"Create index"**
6. Wait for index status to become **"Active"**

### Step 8: Enable TTL

1. Click the **"Additional settings"** tab (or scroll down)
2. In the **"Time to Live (TTL)"** section, click **"Turn on"**
3. **TTL attribute name**: Enter `ttl`
4. Click **"Turn on TTL"**

---

## 5. Phase 4: Create Cognito User Pool

### Step 1: Navigate to Cognito

1. In the search bar, type **"Cognito"**
2. Click **"Amazon Cognito"** from the results

### Step 2: Create User Pool

1. Click **"Create user pool"** button

### Step 3: Configure Sign-in Experience

1. **Authentication providers**: Keep **"Cognito user pool"** selected
2. **Cognito user pool sign-in options**: Check **"Email"** only
3. Click **"Next"**

### Step 4: Configure Security Requirements

1. **Password policy**: 
   - Select **"Custom"**
   - **Password minimum length**: `8`
   - Check: ✅ Contains at least 1 number
   - Check: ✅ Contains at least 1 lowercase letter
   - Check: ✅ Contains at least 1 uppercase letter
   - Uncheck: ❌ Contains at least 1 special character
2. **Multi-factor authentication**: Select **"No MFA"**
3. **User account recovery**: Keep **"Enable self-service account recovery"** checked
   - Delivery method: **"Email only"**
4. Click **"Next"**

### Step 5: Configure Sign-up Experience

1. **Self-service sign-up**: Keep **"Enable self-registration"** checked
2. **Attribute verification**: Keep **"Send email message, verify email address"**
3. **Required attributes**: 
   - **email** should already be listed
4. Click **"Next"**

### Step 6: Configure Message Delivery

1. **Email provider**: Select **"Send email with Cognito"**
   - This uses Amazon SES in sandbox mode (fine for development)
2. **FROM email address**: Keep the default
3. Click **"Next"**

### Step 7: Integrate Your App

1. **User pool name**: Enter `pdf-translator-users-dev`
2. **Hosted authentication pages**: Check **"Use the Cognito Hosted UI"**
3. **Domain type**: Select **"Use a Cognito domain"**
4. **Cognito domain**: Enter a unique prefix like `pdf-translator-dev-YOUR_ACCOUNT_ID`

#### Initial App Client

1. **App type**: Select **"Public client"**
2. **App client name**: Enter `pdf-translator-client-dev`
3. **Client secret**: Select **"Don't generate a client secret"**
4. **Authentication flows**: Check:
   - ✅ ALLOW_USER_PASSWORD_AUTH
   - ✅ ALLOW_REFRESH_TOKEN_AUTH
   - ✅ ALLOW_USER_SRP_AUTH
5. **Allowed callback URLs**: Enter `http://localhost:3000/callback`
6. **Allowed sign-out URLs**: Enter `http://localhost:3000`

### Step 8: Review and Create

1. Review all settings
2. Click **"Create user pool"**
3. Wait for creation to complete

### Step 9: Note Important Values

After creation, click on your user pool and note these values:

1. **User Pool ID**: Found on the overview page
   - Example: `us-east-1_AbCdEfGhI`
2. Click **"App integration"** tab
3. Scroll to **"App clients and analytics"**
4. Click on your app client name
5. **Client ID**: Copy this value
   - Example: `1abc2def3ghi4jkl5mno6pqr`

**SAVE THESE VALUES** - You'll need them for the frontend!

---

## 6. Phase 5: Create Lambda Functions

We need 3 Lambda functions: Upload, Translate, and Status.

### 6.1 Create Upload Lambda Function

#### Step 1: Navigate to Lambda

1. In the search bar, type **"Lambda"**
2. Click **"Lambda"** from the results

#### Step 2: Create Function

1. Click **"Create function"** button

#### Step 3: Configure Function

1. Select **"Author from scratch"**
2. **Function name**: Enter `pdf-translator-upload-dev`
3. **Runtime**: Select **"Python 3.11"**
4. **Architecture**: Keep **"x86_64"**

#### Step 4: Permissions

1. Expand **"Change default execution role"**
2. Select **"Use an existing role"**
3. **Existing role**: Select `pdf-translator-lambda-role-dev`
4. Click **"Create function"**

#### Step 5: Add Function Code

1. In the **"Code"** tab, you'll see `lambda_function.py`
2. Delete all existing code
3. Paste the following code:

```python
import json
import boto3
import uuid
import os
from datetime import datetime, timedelta
from botocore.exceptions import ClientError

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """Generate presigned URL for PDF upload and create job record."""
    try:
        # Parse request
        body = json.loads(event.get('body', '{}'))
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        filename = body.get('filename', 'document.pdf')
        target_language = body.get('targetLanguage', 'es')
        source_language = body.get('sourceLanguage', 'auto')
        
        # Validate input
        if not filename.lower().endswith('.pdf'):
            return response(400, {'error': 'Only PDF files are supported'})
        
        # Generate job ID and S3 key
        job_id = str(uuid.uuid4())
        s3_key = f"uploads/{user_id}/{job_id}/{filename}"
        
        # Generate presigned URL
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': os.environ['UPLOAD_BUCKET'],
                'Key': s3_key,
                'ContentType': 'application/pdf'
            },
            ExpiresIn=3600
        )
        
        # Create job record
        table = dynamodb.Table(os.environ['JOBS_TABLE'])
        now = datetime.utcnow()
        ttl = int((now + timedelta(days=30)).timestamp())
        
        table.put_item(Item={
            'jobId': job_id,
            'userId': user_id,
            'filename': filename,
            'sourceLanguage': source_language,
            'targetLanguage': target_language,
            'status': 'PENDING_UPLOAD',
            'createdAt': now.isoformat(),
            'updatedAt': now.isoformat(),
            's3Key': s3_key,
            'ttl': ttl
        })
        
        return response(200, {
            'jobId': job_id,
            'uploadUrl': presigned_url,
            'message': 'Upload URL generated successfully'
        })
        
    except ClientError as e:
        print(f"AWS Error: {e}")
        return response(500, {'error': 'Failed to generate upload URL'})
    except Exception as e:
        print(f"Error: {e}")
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'OPTIONS,POST,GET'
        },
        'body': json.dumps(body)
    }
```

4. Click **"Deploy"** button (or press Ctrl+S)

#### Step 6: Configure Environment Variables

1. Click the **"Configuration"** tab
2. Click **"Environment variables"** in the left sidebar
3. Click **"Edit"**
4. Click **"Add environment variable"** and add:

| Key | Value |
|-----|-------|
| `UPLOAD_BUCKET` | `pdf-translator-uploads-dev-YOUR_ACCOUNT_ID` |
| `JOBS_TABLE` | `pdf-translator-jobs-dev` |
| `ENVIRONMENT` | `dev` |

5. Click **"Save"**

#### Step 7: Configure Timeout

1. Click **"General configuration"** in the left sidebar
2. Click **"Edit"**
3. **Timeout**: Set to `30` seconds
4. **Memory**: Keep at `256` MB
5. Click **"Save"**

---

### 6.2 Create Translate Lambda Function

#### Step 1: Create New Function

1. Go back to Lambda functions list
2. Click **"Create function"**
3. **Function name**: Enter `pdf-translator-translate-dev`
4. **Runtime**: Select **"Python 3.11"**
5. **Existing role**: Select `pdf-translator-lambda-role-dev`
6. Click **"Create function"**

#### Step 2: Add Lambda Layer for PyPDF2

1. Scroll down to **"Layers"** section
2. Click **"Add a layer"**
3. Select **"Specify an ARN"**
4. Enter: `arn:aws:lambda:us-east-1:770693421928:layer:Klayers-p311-PyPDF2:1`
5. Click **"Add"**

#### Step 3: Add Function Code

1. In the **"Code"** tab, delete existing code and paste:

```python
import json
import boto3
import os
from datetime import datetime
from botocore.exceptions import ClientError
import io

s3_client = boto3.client('s3')
translate_client = boto3.client('translate')
comprehend_client = boto3.client('comprehend')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """Process S3 upload event and translate PDF content."""
    try:
        # Parse S3 event
        for record in event.get('Records', []):
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            # Extract job info from key
            parts = key.split('/')
            if len(parts) < 4:
                print(f"Invalid key format: {key}")
                continue
            
            user_id = parts[1]
            job_id = parts[2]
            
            # Update job status
            table = dynamodb.Table(os.environ['JOBS_TABLE'])
            update_job_status(table, job_id, 'PROCESSING')
            
            try:
                # Get job details
                job = table.get_item(Key={'jobId': job_id})['Item']
                target_lang = job.get('targetLanguage', 'es')
                source_lang = job.get('sourceLanguage', 'auto')
                
                # Download and process PDF
                pdf_content = download_pdf(bucket, key)
                text_content = extract_text_from_pdf(pdf_content)
                
                if not text_content.strip():
                    update_job_status(table, job_id, 'FAILED', 'No text found in PDF')
                    continue
                
                # Detect source language if auto
                if source_lang == 'auto':
                    source_lang = detect_language(text_content[:5000])
                
                # Translate text
                translated_text = translate_text(text_content, source_lang, target_lang)
                
                # Create output file (text format for simplicity)
                output_key = f"translated/{user_id}/{job_id}/translated_{job['filename'].replace('.pdf', '.txt')}"
                
                s3_client.put_object(
                    Bucket=os.environ['OUTPUT_BUCKET'],
                    Key=output_key,
                    Body=translated_text.encode('utf-8'),
                    ContentType='text/plain; charset=utf-8'
                )
                
                # Generate download URL
                download_url = s3_client.generate_presigned_url(
                    'get_object',
                    Params={'Bucket': os.environ['OUTPUT_BUCKET'], 'Key': output_key},
                    ExpiresIn=86400
                )
                
                # Update job with success
                table.update_item(
                    Key={'jobId': job_id},
                    UpdateExpression='SET #status = :status, downloadUrl = :url, outputKey = :key, updatedAt = :time, detectedLanguage = :lang',
                    ExpressionAttributeNames={'#status': 'status'},
                    ExpressionAttributeValues={
                        ':status': 'COMPLETED',
                        ':url': download_url,
                        ':key': output_key,
                        ':time': datetime.utcnow().isoformat(),
                        ':lang': source_lang
                    }
                )
                
            except Exception as e:
                print(f"Processing error for job {job_id}: {e}")
                update_job_status(table, job_id, 'FAILED', str(e))
        
        return {'statusCode': 200, 'body': 'Processing complete'}
        
    except Exception as e:
        print(f"Handler error: {e}")
        return {'statusCode': 500, 'body': str(e)}

def download_pdf(bucket, key):
    response = s3_client.get_object(Bucket=bucket, Key=key)
    return response['Body'].read()

def extract_text_from_pdf(pdf_content):
    try:
        import fitz  # PyMuPDF
        doc = fitz.open(stream=pdf_content, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text()
        doc.close()
        return text
    except Exception as e:
        print(f"PDF extraction error: {e}")
        return ""


def detect_language(text):
    try:
        response = comprehend_client.detect_dominant_language(Text=text)
        return response['Languages'][0]['LanguageCode']
    except:
        return 'en'

def translate_text(text, source_lang, target_lang):
    # Split text into chunks (Translate has 10000 byte limit)
    max_chunk = 9000
    chunks = [text[i:i+max_chunk] for i in range(0, len(text), max_chunk)]
    
    translated_chunks = []
    for chunk in chunks:
        if chunk.strip():
            response = translate_client.translate_text(
                Text=chunk,
                SourceLanguageCode=source_lang,
                TargetLanguageCode=target_lang
            )
            translated_chunks.append(response['TranslatedText'])
    
    return ''.join(translated_chunks)

def update_job_status(table, job_id, status, error=None):
    update_expr = 'SET #status = :status, updatedAt = :time'
    expr_values = {
        ':status': status,
        ':time': datetime.utcnow().isoformat()
    }
    if error:
        update_expr += ', errorMessage = :error'
        expr_values[':error'] = error
    
    table.update_item(
        Key={'jobId': job_id},
        UpdateExpression=update_expr,
        ExpressionAttributeNames={'#status': 'status'},
        ExpressionAttributeValues=expr_values
    )
```

2. Click **"Deploy"**

#### Step 4: Configure Environment Variables

1. Click **"Configuration"** tab
2. Click **"Environment variables"**
3. Click **"Edit"** and add:

| Key | Value |
|-----|-------|
| `UPLOAD_BUCKET` | `pdf-translator-uploads-dev-YOUR_ACCOUNT_ID` |
| `OUTPUT_BUCKET` | `pdf-translator-outputs-dev-YOUR_ACCOUNT_ID` |
| `JOBS_TABLE` | `pdf-translator-jobs-dev` |
| `ENVIRONMENT` | `dev` |

4. Click **"Save"**

#### Step 5: Configure Timeout and Memory

1. Click **"General configuration"**
2. Click **"Edit"**
3. **Memory**: Set to `1024` MB
4. **Timeout**: Set to `5` minutes (`5` min `0` sec)
5. Click **"Save"**

---

### 6.3 Create Status Lambda Function

#### Step 1: Create Function

1. Go to Lambda functions list
2. Click **"Create function"**
3. **Function name**: Enter `pdf-translator-status-dev`
4. **Runtime**: Select **"Python 3.11"**
5. **Existing role**: Select `pdf-translator-lambda-role-dev`
6. Click **"Create function"**

#### Step 2: Add Function Code

```python
import json
import boto3
import os
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
s3_client = boto3.client('s3')

def lambda_handler(event, context):
    """Get job status or list user's jobs."""
    try:
        user_id = event['requestContext']['authorizer']['claims']['sub']
        path_params = event.get('pathParameters') or {}
        job_id = path_params.get('jobId')
        
        table = dynamodb.Table(os.environ['JOBS_TABLE'])
        
        if job_id:
            # Get specific job
            result = table.get_item(Key={'jobId': job_id})
            job = result.get('Item')
            
            if not job:
                return response(404, {'error': 'Job not found'})
            
            if job['userId'] != user_id:
                return response(403, {'error': 'Access denied'})
            
            # Refresh download URL if completed
            if job.get('status') == 'COMPLETED' and job.get('outputKey'):
                job['downloadUrl'] = s3_client.generate_presigned_url(
                    'get_object',
                    Params={
                        'Bucket': os.environ['OUTPUT_BUCKET'],
                        'Key': job['outputKey']
                    },
                    ExpiresIn=86400
                )
            
            # Remove internal fields
            job.pop('s3Key', None)
            job.pop('outputKey', None)
            job.pop('ttl', None)
            
            return response(200, job)
        else:
            # List user's jobs
            result = table.query(
                IndexName='UserIndex',
                KeyConditionExpression=Key('userId').eq(user_id),
                ScanIndexForward=False,
                Limit=50
            )
            
            jobs = []
            for job in result.get('Items', []):
                jobs.append({
                    'jobId': job['jobId'],
                    'filename': job['filename'],
                    'status': job['status'],
                    'targetLanguage': job['targetLanguage'],
                    'createdAt': job['createdAt']
                })
            
            return response(200, {'jobs': jobs})
            
    except ClientError as e:
        print(f"AWS Error: {e}")
        return response(500, {'error': 'Database error'})
    except Exception as e:
        print(f"Error: {e}")
        return response(500, {'error': 'Internal server error'})

def response(status_code, body):
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'OPTIONS,GET'
        },
        'body': json.dumps(body)
    }
```

1. Click **"Deploy"**

#### Step 3: Configure Environment Variables

| Key | Value |
|-----|-------|
| `JOBS_TABLE` | `pdf-translator-jobs-dev` |
| `OUTPUT_BUCKET` | `pdf-translator-outputs-dev-YOUR_ACCOUNT_ID` |
| `ENVIRONMENT` | `dev` |

#### Step 4: Configure Timeout

1. Set **Timeout**: `30` seconds
2. Set **Memory**: `256` MB

---

## 7. Phase 6: Create API Gateway

### Step 1: Navigate to API Gateway

1. In the search bar, type **"API Gateway"**
2. Click **"API Gateway"** from the results

### Step 2: Create REST API

1. Find **"REST API"** (not REST API Private)
2. Click **"Build"**
3. **Choose the protocol**: Select **"REST"**
4. **Create new API**: Select **"New API"**
5. **API name**: Enter `pdf-translator-api-dev`
6. **Description**: Enter `PDF Translation API`
7. **Endpoint Type**: Select **"Regional"**
8. Click **"Create API"**

### Step 3: Create Cognito Authorizer

1. In the left sidebar, click **"Authorizers"**
2. Click **"Create New Authorizer"**
3. Configure:
   - **Name**: `CognitoAuthorizer`
   - **Type**: Select **"Cognito"**
   - **Cognito User Pool**: Select `pdf-translator-users-dev`
   - **Token Source**: Enter `Authorization`
4. Click **"Create"**

---

### Step 4: Create /upload Endpoint

#### Create Resource

1. Click **"Resources"** in the left sidebar
2. With **"/"** selected, click **"Actions"** → **"Create Resource"**
3. **Resource Name**: Enter `upload`
4. **Resource Path**: Should auto-fill as `upload`
5. Check **"Enable API Gateway CORS"**
6. Click **"Create Resource"**

#### Create POST Method

1. With `/upload` selected, click **"Actions"** → **"Create Method"**
2. Select **"POST"** from the dropdown
3. Click the checkmark ✓
4. Configure integration:
   - **Integration type**: Select **"Lambda Function"**
   - **Use Lambda Proxy integration**: Check ✅
   - **Lambda Region**: `us-east-1`
   - **Lambda Function**: Type `pdf-translator-upload-dev` and select it
5. Click **"Save"**
6. Click **"OK"** on the permission popup

#### Add Authorization to POST

1. Click on the **"POST"** method under `/upload`
2. Click **"Method Request"**
3. Click the pencil icon next to **"Authorization"**
4. Select **"CognitoAuthorizer"** from the dropdown
5. Click the checkmark ✓

---

### Step 5: Create /jobs Endpoint

#### Create Resource

1. Click on **"/"** resource
2. Click **"Actions"** → **"Create Resource"**
3. **Resource Name**: Enter `jobs`
4. Check **"Enable API Gateway CORS"**
5. Click **"Create Resource"**

#### Create GET Method

1. With `/jobs` selected, click **"Actions"** → **"Create Method"**
2. Select **"GET"**
3. Click the checkmark ✓
4. Configure:
   - **Integration type**: Lambda Function
   - **Use Lambda Proxy integration**: Check ✅
   - **Lambda Function**: `pdf-translator-status-dev`
5. Click **"Save"** and **"OK"**

#### Add Authorization to GET

1. Click on **"GET"** method
2. Click **"Method Request"**
3. Set **"Authorization"** to **"CognitoAuthorizer"**

---

### Step 6: Create /jobs/{jobId} Endpoint

#### Create Resource

1. With `/jobs` selected, click **"Actions"** → **"Create Resource"**
2. **Resource Name**: Enter `{jobId}`
3. **Resource Path**: Should show `{jobId}`
4. Check **"Enable API Gateway CORS"**
5. Click **"Create Resource"**

#### Create GET Method

1. With `/{jobId}` selected, click **"Actions"** → **"Create Method"**
2. Select **"GET"**
3. Configure:
   - **Integration type**: Lambda Function
   - **Use Lambda Proxy integration**: Check ✅
   - **Lambda Function**: `pdf-translator-status-dev`
4. Click **"Save"** and **"OK"**

#### Add Authorization

1. Click **"Method Request"**
2. Set **"Authorization"** to **"CognitoAuthorizer"**

---

### Step 7: Deploy API

1. Click **"Actions"** → **"Deploy API"**
2. **Deployment stage**: Select **"[New Stage]"**
3. **Stage name**: Enter `dev`
4. **Stage description**: Enter `Development stage`
5. Click **"Deploy"**

### Step 8: Note API Endpoint URL

1. After deployment, you'll see the **"Invoke URL"** at the top
2. **Copy this URL** - you'll need it for the frontend

```
Example: https://abc123xyz.execute-api.us-east-1.amazonaws.com/dev
```

---

## 8. Phase 7: Configure S3 Event Trigger

This triggers the Translate Lambda when a PDF is uploaded.

### Step 1: Add Permission to Lambda

1. Go to **Lambda** → **Functions** → **pdf-translator-translate-dev**
2. Click the **"Configuration"** tab
3. Click **"Permissions"** in the left sidebar
4. Scroll down to **"Resource-based policy statements"**
5. Click **"Add permissions"**
6. Select **"AWS service"**
7. Configure:
   - **Service**: Select **"S3"**
   - **Statement ID**: Enter `s3-trigger`
   - **Principal**: `s3.amazonaws.com`
   - **Source ARN**: Enter `arn:aws:s3:::pdf-translator-uploads-dev-YOUR_ACCOUNT_ID`
   - **Action**: Select **"lambda:InvokeFunction"**
8. Click **"Save"**

### Step 2: Configure S3 Event Notification

1. Go to **S3** → Click on **pdf-translator-uploads-dev-YOUR_ACCOUNT_ID**
2. Click the **"Properties"** tab
3. Scroll down to **"Event notifications"**
4. Click **"Create event notification"**
5. Configure:
   - **Event name**: Enter `PDFUploadTrigger`
   - **Prefix**: Enter `uploads/`
   - **Suffix**: Enter `.pdf`
   - **Event types**: Check **"All object create events"** (or specifically `s3:ObjectCreated:*`)
   - **Destination**: Select **"Lambda function"**
   - **Lambda function**: Select **"pdf-translator-translate-dev"**
6. Click **"Save changes"**

---

## 9. Phase 8: Create CloudFront Distribution

### Step 1: Navigate to CloudFront

1. In the search bar, type **"CloudFront"**
2. Click **"CloudFront"** from the results

### Step 2: Create Origin Access Control

1. In the left sidebar, click **"Origin access"**
2. Under **"Origin access control"**, click **"Create control setting"**
3. Configure:
   - **Name**: Enter `pdf-translator-oac-dev`
   - **Signing behavior**: Select **"Sign requests (recommended)"**
   - **Origin type**: Select **"S3"**
4. Click **"Create"**

### Step 3: Create Distribution

1. Click **"Distributions"** in the left sidebar
2. Click **"Create distribution"**

#### Configure Origin

1. **Origin domain**: Click the dropdown and select your frontend bucket:
   - `pdf-translator-frontend-dev-YOUR_ACCOUNT_ID.s3.us-east-1.amazonaws.com`
2. **Origin path**: Leave empty
3. **Name**: Auto-filled
4. **Origin access**: Select **"Origin access control settings (recommended)"**
5. **Origin access control**: Select **"pdf-translator-oac-dev"**

#### Default Cache Behavior

1. **Viewer protocol policy**: Select **"Redirect HTTP to HTTPS"**
2. **Allowed HTTP methods**: Select **"GET, HEAD"**
3. **Cache policy**: Select **"CachingOptimized"**

#### Settings

1. **Price class**: Select **"Use only North America and Europe"** (cost savings)
2. **Default root object**: Enter `index.html`
3. Leave other settings as default

### Step 4: Create Distribution

1. Click **"Create distribution"**
2. **IMPORTANT**: You'll see a yellow banner saying you need to update the S3 bucket policy
3. Click **"Copy policy"** button

### Step 5: Update S3 Bucket Policy

1. Go to **S3** → **pdf-translator-frontend-dev-YOUR_ACCOUNT_ID**
2. Click **"Permissions"** tab
3. Scroll to **"Bucket policy"**
4. Click **"Edit"**
5. Paste the policy you copied from CloudFront
6. Click **"Save changes"**

### Step 6: Configure Error Pages

1. Go back to **CloudFront** → Your distribution
2. Click the **"Error pages"** tab
3. Click **"Create custom error response"**
4. Configure for 403 error:
   - **HTTP error code**: Select **"403: Forbidden"**
   - **Customize error response**: Select **"Yes"**
   - **Response page path**: Enter `/index.html`
   - **HTTP response code**: Select **"200: OK"**
5. Click **"Create custom error response"**
6. Repeat for **404 error** with same settings

### Step 7: Note CloudFront Domain

1. On the distribution details page, find **"Distribution domain name"**
2. Copy this value (e.g., `d1234567890abc.cloudfront.net`)
3. This is your application URL!

---

## 10. Phase 9: Deploy Frontend

### Step 1: Prepare Frontend Files

You need to create or download the frontend React application. Create these files on your computer:

#### Create Project Structure

Create a folder called `pdf-translator-frontend` with this structure:

```
pdf-translator-frontend/
├── public/
│   └── index.html
├── src/
│   ├── App.js
│   ├── App.css
│   ├── index.js
│   └── index.css
├── package.json
└── .env
```

#### Create .env File

Create a file named `.env` in the root folder:

```
REACT_APP_API_ENDPOINT=https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/dev
REACT_APP_USER_POOL_ID=us-east-1_XXXXXXXXX
REACT_APP_USER_POOL_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
REACT_APP_REGION=us-east-1
```

Replace the values with your actual:
- API Gateway URL (from Step 7)
- Cognito User Pool ID (from Step 5)
- Cognito Client ID (from Step 5)

### Step 2: Build the Frontend

On your local computer:

1. Open a terminal/command prompt
2. Navigate to your project folder
3. Run:

```bash
npm install
npm run build
```

This creates a `build` folder with the compiled application.

### Step 3: Upload to S3

#### Using AWS Console

1. Go to **S3** → **pdf-translator-frontend-dev-YOUR_ACCOUNT_ID**
2. Click **"Upload"**
3. Click **"Add files"** and select all files from the `build` folder
4. Click **"Add folder"** and select the `static` folder
5. Click **"Upload"**

#### Alternative: Use S3 Sync in CloudShell

1. In AWS Console, click the **CloudShell** icon (terminal icon in top navigation)
2. Wait for CloudShell to initialize
3. Upload your `build` folder to CloudShell
4. Run:

```bash
aws s3 sync build/ s3://pdf-translator-frontend-dev-YOUR_ACCOUNT_ID --delete
```

### Step 4: Invalidate CloudFront Cache

1. Go to **CloudFront** → Your distribution
2. Click the **"Invalidations"** tab
3. Click **"Create invalidation"**
4. **Object paths**: Enter `/*`
5. Click **"Create invalidation"**
6. Wait for status to change to **"Completed"**

### Step 5: Access Your Application

1. Open a web browser
2. Navigate to: `https://YOUR_CLOUDFRONT_DOMAIN.cloudfront.net`
3. You should see the login page!

---

## 11. Phase 10: Testing

### Test 1: Create a User Account

1. On the login page, click **"Create Account"** or **"Sign Up"**
2. Enter:
   - Email: your email address
   - Password: at least 8 characters with uppercase, lowercase, and number
3. Click **"Sign Up"**
4. Check your email for a verification code
5. Enter the verification code
6. You should now be logged in

### Test 2: Upload a PDF

1. On the main page, drag and drop a PDF file or click to select one
2. Select a target language (e.g., Spanish)
3. Click **"Translate"**
4. You should see a success message with a Job ID

### Test 3: Check Translation Status

1. In the **"Your Translations"** section, you should see your job
2. Status will change from **"PENDING_UPLOAD"** → **"PROCESSING"** → **"COMPLETED"**
3. This may take 1-5 minutes depending on PDF size

### Test 4: Download Translation

1. Once status is **"COMPLETED"**, click the **"Download"** button
2. The translated document will download

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Network Error" on login | Check Cognito User Pool Client settings |
| "Unauthorized" error | Verify API Gateway authorizer is configured |
| Upload fails | Check S3 CORS configuration |
| Translation stuck on "Processing" | Check Lambda logs in CloudWatch |
| Can't access website | Verify CloudFront distribution is deployed and bucket policy is correct |

### Viewing Logs

1. Go to **CloudWatch** → **Log groups**
2. Find `/aws/lambda/pdf-translator-translate-dev`
3. Click on the latest log stream
4. Look for error messages

---

## Cost Summary

With this setup in the AWS Free Tier (first 12 months):

| Service | Free Tier Allowance |
|---------|-------------------|
| Lambda | 1M requests/month |
| S3 | 5GB storage |
| DynamoDB | 25GB storage |
| CloudFront | 1TB transfer |
| Cognito | 50,000 MAU |
| API Gateway | 1M calls/month |

**Estimated monthly cost after free tier: $5-20** depending on usage.

---

## Cleanup (Delete All Resources)

To avoid ongoing charges, delete resources in this order:

1. **CloudFront**: Disable, then delete distribution
2. **S3**: Empty all buckets, then delete them
3. **Lambda**: Delete all 3 functions
4. **API Gateway**: Delete the API
5. **DynamoDB**: Delete the table
6. **Cognito**: Delete the user pool
7. **IAM**: Delete the role

---

**Congratulations!** 🎉 You've successfully deployed the AWS PDF Translator using the AWS Console!
