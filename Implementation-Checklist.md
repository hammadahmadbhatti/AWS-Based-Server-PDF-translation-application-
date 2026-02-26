# AWS PDF Translator - Implementation Checklist

Use this checklist alongside the detailed guide to track your progress.

---

## Important Values to Record

Fill in these values as you create resources:

| Resource | Value |
|----------|-------|
| **AWS Account ID** | `________________________` |
| **Region** | `us-east-1` |
| **IAM Role ARN** | `arn:aws:iam::____________:role/pdf-translator-lambda-role-dev` |
| **Upload Bucket** | `pdf-translator-uploads-dev-____________` |
| **Output Bucket** | `pdf-translator-outputs-dev-____________` |
| **Frontend Bucket** | `pdf-translator-frontend-dev-____________` |
| **DynamoDB Table** | `pdf-translator-jobs-dev` |
| **User Pool ID** | `us-east-1_____________` |
| **Client ID** | `__________________________` |
| **API Endpoint** | `https://__________.execute-api.us-east-1.amazonaws.com/dev` |
| **CloudFront URL** | `https://______________.cloudfront.net` |

---

## Phase 1: IAM Role ☐

- [ ] Navigate to IAM
- [ ] Create role with Lambda trusted entity
- [ ] Attach `AWSLambdaBasicExecutionRole` policy
- [ ] Attach `AWSXRayDaemonWriteAccess` policy
- [ ] Create inline policy: `S3Access`
- [ ] Create inline policy: `DynamoDBAccess`
- [ ] Create inline policy: `TranslateAccess`
- [ ] Copy Role ARN

---

## Phase 2: S3 Buckets ☐

### Upload Bucket
- [ ] Create bucket: `pdf-translator-uploads-dev-{account-id}`
- [ ] Block all public access ✓
- [ ] Enable SSE-S3 encryption
- [ ] Configure CORS
- [ ] Create lifecycle rule: DeleteIncompleteUploads
- [ ] Create lifecycle rule: DeleteOldUploads

### Output Bucket
- [ ] Create bucket: `pdf-translator-outputs-dev-{account-id}`
- [ ] Block all public access ✓
- [ ] Enable SSE-S3 encryption
- [ ] Configure CORS

### Frontend Bucket
- [ ] Create bucket: `pdf-translator-frontend-dev-{account-id}`
- [ ] Block all public access ✓
- [ ] Enable static website hosting
- [ ] Set index.html as index document

---

## Phase 3: DynamoDB ☐

- [ ] Create table: `pdf-translator-jobs-dev`
- [ ] Set partition key: `jobId` (String)
- [ ] Select On-demand capacity mode
- [ ] Create GSI: `UserIndex` (userId + createdAt)
- [ ] Enable TTL with attribute: `ttl`

---

## Phase 4: Cognito ☐

- [ ] Create user pool: `pdf-translator-users-dev`
- [ ] Configure email sign-in
- [ ] Set password policy (8 chars, uppercase, lowercase, number)
- [ ] Disable MFA
- [ ] Create app client: `pdf-translator-client-dev`
- [ ] Disable client secret
- [ ] Note User Pool ID: `______________`
- [ ] Note Client ID: `______________`

---

## Phase 5: Lambda Functions ☐

### Upload Lambda
- [ ] Create function: `pdf-translator-upload-dev`
- [ ] Set runtime: Python 3.11
- [ ] Attach IAM role
- [ ] Add function code
- [ ] Set environment variables:
  - [ ] UPLOAD_BUCKET
  - [ ] JOBS_TABLE
  - [ ] ENVIRONMENT
- [ ] Set timeout: 30 seconds

### Translate Lambda
- [ ] Create function: `pdf-translator-translate-dev`
- [ ] Set runtime: Python 3.11
- [ ] Attach IAM role
- [ ] Add PyPDF2 layer
- [ ] Add function code
- [ ] Set environment variables:
  - [ ] UPLOAD_BUCKET
  - [ ] OUTPUT_BUCKET
  - [ ] JOBS_TABLE
  - [ ] ENVIRONMENT
- [ ] Set timeout: 5 minutes
- [ ] Set memory: 1024 MB

### Status Lambda
- [ ] Create function: `pdf-translator-status-dev`
- [ ] Set runtime: Python 3.11
- [ ] Attach IAM role
- [ ] Add function code
- [ ] Set environment variables:
  - [ ] JOBS_TABLE
  - [ ] OUTPUT_BUCKET
  - [ ] ENVIRONMENT
- [ ] Set timeout: 30 seconds

---

## Phase 6: API Gateway ☐

- [ ] Create REST API: `pdf-translator-api-dev`
- [ ] Create Cognito authorizer
- [ ] Create `/upload` resource with CORS
- [ ] Create POST method → Upload Lambda
- [ ] Add Cognito authorization to POST
- [ ] Create `/jobs` resource with CORS
- [ ] Create GET method → Status Lambda
- [ ] Add Cognito authorization to GET
- [ ] Create `/jobs/{jobId}` resource with CORS
- [ ] Create GET method → Status Lambda
- [ ] Add Cognito authorization to GET
- [ ] Deploy to `dev` stage
- [ ] Note API URL: `______________`

---

## Phase 7: S3 Event Trigger ☐

- [ ] Add Lambda permission for S3
- [ ] Create S3 event notification on upload bucket
- [ ] Configure for `uploads/` prefix
- [ ] Configure for `.pdf` suffix
- [ ] Point to Translate Lambda

---

## Phase 8: CloudFront ☐

- [ ] Create Origin Access Control
- [ ] Create distribution
- [ ] Set origin to frontend bucket
- [ ] Enable HTTPS redirect
- [ ] Set default root object: `index.html`
- [ ] Copy and apply bucket policy
- [ ] Create 403 error page → /index.html
- [ ] Create 404 error page → /index.html
- [ ] Note CloudFront URL: `______________`

---

## Phase 9: Frontend Deployment ☐

- [ ] Create `.env` file with:
  - [ ] REACT_APP_API_ENDPOINT
  - [ ] REACT_APP_USER_POOL_ID
  - [ ] REACT_APP_USER_POOL_CLIENT_ID
  - [ ] REACT_APP_REGION
- [ ] Run `npm install`
- [ ] Run `npm run build`
- [ ] Upload build folder to S3
- [ ] Create CloudFront invalidation

---

## Phase 10: Testing ☐

- [ ] Access application via CloudFront URL
- [ ] Create user account
- [ ] Verify email
- [ ] Log in successfully
- [ ] Upload a PDF
- [ ] See translation status updates
- [ ] Download completed translation

---

## Quick Reference: Service URLs

| Service | Console URL |
|---------|-------------|
| IAM | https://console.aws.amazon.com/iam |
| S3 | https://console.aws.amazon.com/s3 |
| DynamoDB | https://console.aws.amazon.com/dynamodb |
| Cognito | https://console.aws.amazon.com/cognito |
| Lambda | https://console.aws.amazon.com/lambda |
| API Gateway | https://console.aws.amazon.com/apigateway |
| CloudFront | https://console.aws.amazon.com/cloudfront |
| CloudWatch | https://console.aws.amazon.com/cloudwatch |

---

## Troubleshooting Quick Checks

| Issue | Check |
|-------|-------|
| Login fails | Cognito User Pool ID and Client ID in .env |
| API errors | API Gateway authorizer + Lambda permissions |
| Upload fails | S3 CORS + bucket name in Lambda env vars |
| No translation | S3 event trigger + Lambda logs |
| Can't access site | CloudFront distribution + S3 bucket policy |

---

**Total Estimated Setup Time: 2-3 hours**
