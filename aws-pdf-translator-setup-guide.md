# AWS PDF Translator - Error Analysis & Complete Setup Guide



# Part 2: Complete Step-by-Step Setup Guide

## Prerequisites

### Required Tools
```bash
# 1. AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version  # Should show 2.x.x

# 2. Node.js 18+
# Using nvm (recommended):
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install 18
node --version  # Should show v18.x.x

# 3. Python 3.11+
python3 --version  # Should show 3.11.x

# 4. Git
git --version
```

### AWS Account Setup
1. Create AWS account at https://aws.amazon.com
2. Enable MFA on root account
3. Create IAM admin user (never use root for operations)

### Configure AWS CLI
```bash
aws configure
# Enter:
# - AWS Access Key ID: [Your access key]
# - AWS Secret Access Key: [Your secret key]
# - Default region: us-east-1
# - Default output format: json

# Verify configuration
aws sts get-caller-identity
```

---

## Step 1: Project Structure Setup

Create the following directory structure:

```bash
mkdir -p aws-pdf-translator/{infrastructure/{cloudformation,scripts},src/{frontend,lambda/{upload,translate,status}},tests/{unit,integration}}
cd aws-pdf-translator
```

Expected structure:
```
aws-pdf-translator/
├── infrastructure/
│   ├── cloudformation/
│   │   └── main.yaml
│   └── scripts/
│       └── deploy.sh
├── src/
│   ├── frontend/
│   │   ├── public/
│   │   ├── src/
│   │   │   └── App.js
│   │   └── package.json
│   └── lambda/
│       ├── upload/
│       ├── translate/
│       └── status/
├── tests/
├── .github/
│   └── workflows/
│       └── pipeline.yaml
└── README.md
```

---

## Step 2: Fix and Deploy CloudFormation Template

### 2.1 Apply Critical Fixes to main.yaml

Before deploying, make these changes:

**Fix 1:** Change bucket name on line 111:
```yaml
# Change from:
BucketName: !Sub '${ProjectName}-output-${Environment}-${AWS::AccountId}'
# To:
BucketName: !Sub '${ProjectName}-outputs-${Environment}-${AWS::AccountId}'
```

**Fix 2:** Add DependsOn to UploadBucket (around line 59):
```yaml
UploadBucket:
  Type: AWS::S3::Bucket
  DependsOn: TranslateLambdaPermission
  DeletionPolicy: Retain
  # ... rest of configuration
```

**Fix 3:** Replace the TranslateLambda with a simpler text-based PDF approach (since reportlab layer may not be available):

Replace lines 596-626 with:
```python
def create_translated_pdf(text, output_key, original_filename):
    # Create simple text file as PDF alternative
    # For production, use a proper PDF library with custom layer
    from io import BytesIO
    
    # Simple text content
    content = f"Translated Document: {original_filename}\n\n{text}"
    
    s3_client.put_object(
        Bucket=os.environ['OUTPUT_BUCKET'],
        Key=output_key.replace('.pdf', '.txt'),  # Save as text for now
        Body=content.encode('utf-8'),
        ContentType='text/plain'
    )
```

### 2.2 Validate Template

```bash
# Navigate to cloudformation directory
cd infrastructure/cloudformation

# Validate template
aws cloudformation validate-template --template-body file://main.yaml

# Optional: Install and run cfn-lint
pip install cfn-lint
cfn-lint main.yaml
```

### 2.3 Deploy Infrastructure

```bash
# Set variables
ENVIRONMENT="dev"
PROJECT_NAME="pdf-translator"
REGION="us-east-1"
STACK_NAME="${PROJECT_NAME}-${ENVIRONMENT}"

# Deploy
aws cloudformation deploy \
    --template-file main.yaml \
    --stack-name $STACK_NAME \
    --region $REGION \
    --parameter-overrides \
        Environment=$ENVIRONMENT \
        ProjectName=$PROJECT_NAME \
    --capabilities CAPABILITY_NAMED_IAM \
    --tags \
        Environment=$ENVIRONMENT \
        Project=$PROJECT_NAME

# Check status
aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus'
```

### 2.4 Get Stack Outputs

```bash
# Save outputs to file for reference
aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs' \
    --output table

# Get specific values
API_ENDPOINT=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
    --output text)

USER_POOL_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
    --output text)

CLIENT_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
    --output text)

CLOUDFRONT_DOMAIN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
    --output text)

FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
    --output text)

DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

# Display values
echo "API Endpoint: $API_ENDPOINT"
echo "User Pool ID: $USER_POOL_ID"
echo "Client ID: $CLIENT_ID"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "Frontend Bucket: $FRONTEND_BUCKET"
echo "Distribution ID: $DISTRIBUTION_ID"
```

---

## Step 3: Fix and Setup Frontend

### 3.1 Create React Application

```bash
cd src/frontend

# Initialize React app (if not already created)
npx create-react-app . --template cra-template

# Install dependencies
npm install aws-amplify @aws-amplify/ui-react
```

### 3.2 Fix App.js

Create a corrected `src/App.js`:

```javascript
import React, { useState, useEffect } from 'react';
import { Amplify } from 'aws-amplify';
import { Authenticator } from '@aws-amplify/ui-react';
import '@aws-amplify/ui-react/styles.css';
import './App.css';

// Configure Amplify
Amplify.configure({
  Auth: {
    Cognito: {
      userPoolId: process.env.REACT_APP_USER_POOL_ID,
      userPoolClientId: process.env.REACT_APP_USER_POOL_CLIENT_ID,
      region: process.env.REACT_APP_REGION || 'us-east-1',
    },
  },
});

const API_ENDPOINT = process.env.REACT_APP_API_ENDPOINT;

// Language options
const LANGUAGES = [
  { code: 'es', name: 'Spanish' },
  { code: 'fr', name: 'French' },
  { code: 'de', name: 'German' },
  { code: 'it', name: 'Italian' },
  { code: 'pt', name: 'Portuguese' },
  { code: 'zh', name: 'Chinese (Simplified)' },
  { code: 'zh-TW', name: 'Chinese (Traditional)' },
  { code: 'ja', name: 'Japanese' },
  { code: 'ko', name: 'Korean' },
  { code: 'ar', name: 'Arabic' },
  { code: 'hi', name: 'Hindi' },
  { code: 'ru', name: 'Russian' },
];

function App() {
  return (
    <Authenticator>
      {({ signOut, user }) => (
        <MainApp user={user} signOut={signOut} />
      )}
    </Authenticator>
  );
}

function MainApp({ user, signOut }) {
  const [file, setFile] = useState(null);
  const [targetLanguage, setTargetLanguage] = useState('es');
  const [uploading, setUploading] = useState(false);
  const [jobs, setJobs] = useState([]);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [dragActive, setDragActive] = useState(false);

  useEffect(() => {
    fetchJobs();
    const interval = setInterval(fetchJobs, 10000);
    return () => clearInterval(interval);
  }, []);

  const getAuthToken = async () => {
    try {
      const { fetchAuthSession } = await import('aws-amplify/auth');
      const session = await fetchAuthSession();
      return session.tokens?.idToken?.toString();
    } catch (err) {
      console.error('Error getting auth token:', err);
      throw new Error('Authentication failed');
    }
  };

  const fetchJobs = async () => {
    try {
      const token = await getAuthToken();
      const response = await fetch(`${API_ENDPOINT}/jobs`, {
        headers: {
          Authorization: `Bearer ${token}`,  // FIXED: Added Bearer prefix
        },
      });

      if (!response.ok) {
        throw new Error('Failed to fetch jobs');
      }

      const data = await response.json();
      setJobs(data.jobs || []);
    } catch (err) {
      console.error('Error fetching jobs:', err);
    }
  };

  const handleFileSelect = (selectedFile) => {
    setError(null);
    setSuccess(null);

    if (!selectedFile.name.toLowerCase().endsWith('.pdf')) {
      setError('Please select a PDF file');
      return;
    }

    if (selectedFile.size > 10 * 1024 * 1024) {
      setError('File size must be less than 10MB');
      return;
    }

    setFile(selectedFile);
  };

  const handleUpload = async () => {
    if (!file) {
      setError('Please select a file first');
      return;
    }

    setUploading(true);
    setError(null);
    setSuccess(null);

    try {
      const token = await getAuthToken();

      // Step 1: Get presigned URL
      const uploadResponse = await fetch(`${API_ENDPOINT}/upload`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token}`,  // FIXED: Added Bearer prefix
        },
        body: JSON.stringify({
          filename: file.name,
          targetLanguage: targetLanguage,
          sourceLanguage: 'auto',
        }),
      });

      if (!uploadResponse.ok) {
        const errorData = await uploadResponse.json();
        throw new Error(errorData.error || 'Failed to get upload URL');
      }

      const { uploadUrl, jobId } = await uploadResponse.json();

      // Step 2: Upload file to S3
      const s3Response = await fetch(uploadUrl, {
        method: 'PUT',
        body: file,
        headers: {
          'Content-Type': 'application/pdf',
        },
      });

      if (!s3Response.ok) {
        throw new Error('Failed to upload file to S3');
      }

      setSuccess(`File uploaded successfully! Job ID: ${jobId}. Translation will start shortly.`);
      setFile(null);
      
      setTimeout(fetchJobs, 2000);
    } catch (err) {
      console.error('Upload error:', err);
      setError(err.message || 'An error occurred during upload');
    } finally {
      setUploading(false);
    }
  };

  const handleDownload = async (jobId) => {
    try {
      const token = await getAuthToken();
      const response = await fetch(`${API_ENDPOINT}/jobs/${jobId}`, {
        headers: {
          Authorization: `Bearer ${token}`,  // FIXED: Added Bearer prefix
        },
      });

      if (!response.ok) {
        throw new Error('Failed to get download URL');
      }

      const job = await response.json();
      if (job.downloadUrl) {
        window.open(job.downloadUrl, '_blank');
      } else {
        setError('Download URL not available');
      }
    } catch (err) {
      console.error('Download error:', err);
      setError(err.message);
    }
  };

  const getStatusBadgeClass = (status) => {
    switch (status) {
      case 'COMPLETED': return 'badge-success';
      case 'PROCESSING': return 'badge-processing';
      case 'FAILED': return 'badge-error';
      default: return 'badge-pending';
    }
  };

  return (
    <div className="app">
      <header className="header">
        <div className="header-content">
          <h1>PDF Translator</h1>
          <div className="user-info">
            <span>Welcome, {user?.signInDetails?.loginId || 'User'}</span>
            <button onClick={signOut} className="btn-secondary">
              Sign Out
            </button>
          </div>
        </div>
      </header>

      <main className="main-content">
        <section className="upload-section">
          <h2>Upload PDF for Translation</h2>

          <div
            className={`dropzone ${dragActive ? 'active' : ''} ${file ? 'has-file' : ''}`}
            onDragEnter={(e) => { e.preventDefault(); setDragActive(true); }}
            onDragLeave={(e) => { e.preventDefault(); setDragActive(false); }}
            onDragOver={(e) => e.preventDefault()}
            onDrop={(e) => {
              e.preventDefault();
              setDragActive(false);
              if (e.dataTransfer.files?.[0]) handleFileSelect(e.dataTransfer.files[0]);
            }}
          >
            <input
              type="file"
              id="file-input"
              accept=".pdf"
              onChange={(e) => e.target.files?.[0] && handleFileSelect(e.target.files[0])}
              className="file-input"
            />
            <label htmlFor="file-input" className="dropzone-content">
              {file ? (
                <>
                  <span className="file-name">{file.name}</span>
                  <span className="file-size">({(file.size / 1024 / 1024).toFixed(2)} MB)</span>
                </>
              ) : (
                <>
                  <span className="dropzone-text">
                    Drag and drop your PDF here, or click to select
                  </span>
                  <span className="dropzone-hint">Maximum file size: 10MB</span>
                </>
              )}
            </label>
          </div>

          <div className="options">
            <div className="form-group">
              <label htmlFor="language">Target Language:</label>
              <select
                id="language"
                value={targetLanguage}
                onChange={(e) => setTargetLanguage(e.target.value)}
                className="select-input"
              >
                {LANGUAGES.map((lang) => (
                  <option key={lang.code} value={lang.code}>
                    {lang.name}
                  </option>
                ))}
              </select>
            </div>

            <button
              onClick={handleUpload}
              disabled={!file || uploading}
              className="btn-primary"
            >
              {uploading ? 'Uploading...' : 'Translate'}
            </button>
          </div>

          {error && <div className="alert alert-error">{error}</div>}
          {success && <div className="alert alert-success">{success}</div>}
        </section>

        <section className="jobs-section">
          <h2>Your Translations</h2>

          {jobs.length === 0 ? (
            <div className="empty-state">
              <p>No translations yet. Upload a PDF to get started!</p>
            </div>
          ) : (
            <div className="jobs-list">
              {jobs.map((job) => (
                <div key={job.jobId} className="job-card">
                  <div className="job-info">
                    <span className="job-filename">{job.filename}</span>
                    <span className="job-date">
                      {new Date(job.createdAt).toLocaleString()}
                    </span>
                    <span className="job-language">
                      → {LANGUAGES.find((l) => l.code === job.targetLanguage)?.name || job.targetLanguage}
                    </span>
                  </div>
                  <div className="job-actions">
                    <span className={`badge ${getStatusBadgeClass(job.status)}`}>
                      {job.status}
                    </span>
                    {job.status === 'COMPLETED' && (
                      <button
                        onClick={() => handleDownload(job.jobId)}
                        className="btn-download"
                      >
                        Download
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </div>
          )}
        </section>
      </main>

      <footer className="footer">
        <p>Powered by AWS Translate</p>
      </footer>
    </div>
  );
}

export default App;
```

### 3.3 Create Environment File

```bash
# Create .env file (don't commit to git!)
cat > .env << EOF
REACT_APP_API_ENDPOINT=${API_ENDPOINT}
REACT_APP_USER_POOL_ID=${USER_POOL_ID}
REACT_APP_USER_POOL_CLIENT_ID=${CLIENT_ID}
REACT_APP_REGION=us-east-1
EOF

# Add to .gitignore
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
```

### 3.4 Create App.css

```css
/* src/App.css */
.app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
}

.header {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  padding: 1rem 2rem;
}

.header-content {
  max-width: 1200px;
  margin: 0 auto;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.header h1 {
  margin: 0;
  font-size: 1.5rem;
}

.user-info {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.main-content {
  flex: 1;
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  width: 100%;
  box-sizing: border-box;
}

.upload-section, .jobs-section {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  margin-bottom: 2rem;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
}

.dropzone {
  border: 2px dashed #ccc;
  border-radius: 8px;
  padding: 3rem 2rem;
  text-align: center;
  cursor: pointer;
  transition: all 0.3s ease;
}

.dropzone.active, .dropzone:hover {
  border-color: #667eea;
  background: #f8f9ff;
}

.dropzone.has-file {
  border-color: #22c55e;
  background: #f0fdf4;
}

.file-input {
  display: none;
}

.dropzone-content {
  cursor: pointer;
}

.dropzone-text {
  display: block;
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
}

.dropzone-hint {
  color: #666;
  font-size: 0.9rem;
}

.options {
  display: flex;
  gap: 1rem;
  margin-top: 1.5rem;
  align-items: flex-end;
}

.form-group {
  flex: 1;
}

.form-group label {
  display: block;
  margin-bottom: 0.5rem;
  font-weight: 500;
}

.select-input {
  width: 100%;
  padding: 0.75rem;
  border: 1px solid #ddd;
  border-radius: 4px;
  font-size: 1rem;
}

.btn-primary {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 0.75rem 2rem;
  border-radius: 4px;
  font-size: 1rem;
  cursor: pointer;
  transition: opacity 0.3s;
}

.btn-primary:hover {
  opacity: 0.9;
}

.btn-primary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-secondary {
  background: transparent;
  color: white;
  border: 1px solid white;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
}

.btn-download {
  background: #22c55e;
  color: white;
  border: none;
  padding: 0.5rem 1rem;
  border-radius: 4px;
  cursor: pointer;
}

.alert {
  padding: 1rem;
  border-radius: 4px;
  margin-top: 1rem;
}

.alert-error {
  background: #fef2f2;
  color: #dc2626;
  border: 1px solid #fecaca;
}

.alert-success {
  background: #f0fdf4;
  color: #16a34a;
  border: 1px solid #bbf7d0;
}

.jobs-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.job-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem;
  border: 1px solid #eee;
  border-radius: 8px;
}

.job-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.job-filename {
  font-weight: 500;
}

.job-date, .job-language {
  font-size: 0.9rem;
  color: #666;
}

.job-actions {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.badge {
  padding: 0.25rem 0.75rem;
  border-radius: 999px;
  font-size: 0.8rem;
  font-weight: 500;
}

.badge-success {
  background: #dcfce7;
  color: #16a34a;
}

.badge-processing {
  background: #fef3c7;
  color: #d97706;
}

.badge-error {
  background: #fef2f2;
  color: #dc2626;
}

.badge-pending {
  background: #f3f4f6;
  color: #6b7280;
}

.empty-state {
  text-align: center;
  padding: 3rem;
  color: #666;
}

.footer {
  background: #f8f9fa;
  text-align: center;
  padding: 1rem;
  color: #666;
}
```

### 3.5 Build and Deploy Frontend

```bash
# Build
npm run build

# Deploy to S3
aws s3 sync build/ s3://$FRONTEND_BUCKET --delete

# Invalidate CloudFront cache
aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/*"

# Wait for invalidation (optional)
echo "Waiting for CloudFront invalidation..."
sleep 30

# Access your app
echo "Your app is available at: https://$CLOUDFRONT_DOMAIN"
```

---

## Step 4: Test the Application

### 4.1 Create Test User

```bash
# Sign up a test user
aws cognito-idp sign-up \
    --client-id $CLIENT_ID \
    --username test@example.com \
    --password "TestPassword123!"

# Confirm the user (admin confirmation)
aws cognito-idp admin-confirm-sign-up \
    --user-pool-id $USER_POOL_ID \
    --username test@example.com
```

### 4.2 Test API Endpoints

```bash
# Get authentication token
AUTH_RESULT=$(aws cognito-idp initiate-auth \
    --client-id $CLIENT_ID \
    --auth-flow USER_PASSWORD_AUTH \
    --auth-parameters USERNAME=test@example.com,PASSWORD="TestPassword123!")

TOKEN=$(echo $AUTH_RESULT | jq -r '.AuthenticationResult.IdToken')

# Test upload endpoint
curl -X POST "$API_ENDPOINT/upload" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"filename": "test.pdf", "targetLanguage": "es"}'

# Test jobs list endpoint
curl -X GET "$API_ENDPOINT/jobs" \
    -H "Authorization: Bearer $TOKEN"
```

### 4.3 End-to-End Test

1. Open `https://$CLOUDFRONT_DOMAIN` in your browser
2. Sign up or sign in with test credentials
3. Upload a PDF file
4. Select target language
5. Wait for translation to complete
6. Download the translated document

---

## Step 5: Troubleshooting

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| CORS errors | API Gateway CORS not configured | Check OPTIONS methods return correct headers |
| 401 Unauthorized | Invalid/expired token | Refresh token or re-authenticate |
| 403 Forbidden | IAM permissions | Check Lambda execution role policies |
| 500 Internal Server Error | Lambda crash | Check CloudWatch logs |
| Translation stuck on PROCESSING | Lambda timeout or error | Increase timeout, check logs |
| Cannot upload file | S3 presigned URL issues | Verify S3 bucket CORS configuration |

### Viewing Logs

```bash
# Lambda logs
aws logs tail /aws/lambda/pdf-translator-upload-dev --follow
aws logs tail /aws/lambda/pdf-translator-translate-dev --follow
aws logs tail /aws/lambda/pdf-translator-status-dev --follow

# API Gateway logs (if enabled)
aws logs tail /aws/api-gateway/pdf-translator-api-dev --follow
```

---

## Step 6: Cleanup (When Done)

```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name $STACK_NAME

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name $STACK_NAME

# Note: S3 buckets with DeletionPolicy: Retain won't be deleted
# Manually empty and delete if needed:
aws s3 rb s3://$FRONTEND_BUCKET --force
```

---

## Quick Reference: All Resource Names

| Resource | Name Pattern |
|----------|-------------|
| Upload Bucket | `pdf-translator-uploads-dev-{account_id}` |
| Output Bucket | `pdf-translator-outputs-dev-{account_id}` |
| Frontend Bucket | `pdf-translator-frontend-dev-{account_id}` |
| DynamoDB Table | `pdf-translator-jobs-dev` |
| User Pool | `pdf-translator-users-dev` |
| App Client | `pdf-translator-client-dev` |
| Upload Lambda | `pdf-translator-upload-dev` |
| Translate Lambda | `pdf-translator-translate-dev` |
| Status Lambda | `pdf-translator-status-dev` |
| API Gateway | `pdf-translator-api-dev` |
| Lambda Role | `pdf-translator-lambda-role-dev` |

---

## Cost Estimate

| Service | Monthly Cost (Low Usage) |
|---------|-------------------------|
| Lambda | $0 - $5 |
| S3 | $0.50 - $2 |
| API Gateway | $0 - $3.50 |
| DynamoDB (On-Demand) | $0 - $2 |
| CloudFront | $0 - $5 |
| Cognito (first 50k MAU) | $0 |
| Amazon Translate | ~$15/million chars |
| **Total** | **$15 - $35/month** |

---

**Setup Complete!** 🎉

Your AWS PDF Translator application should now be fully functional. If you encounter any issues, refer to the Troubleshooting section or check CloudWatch logs for detailed error messages.
