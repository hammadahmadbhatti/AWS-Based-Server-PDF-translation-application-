# AWS PDF Translation Application

A serverless, cost-effective PDF translation application built on AWS with clean architecture, CI/CD pipeline, and comprehensive error handling.

## ⚠️ Corrected Version

This version includes fixes for the following issues:
- ✅ Fixed S3 bucket naming consistency (`outputs` vs `output`)
- ✅ Fixed circular dependency in S3 → Lambda notification
- ✅ Fixed missing `Bearer` prefix in Authorization headers
- ✅ Replaced `reportlab` with `fpdf2` Lambda layer (more widely available)
- ✅ Fixed frontend build environment variables in CI/CD pipeline
- ✅ Fixed deploy script path resolution
- ✅ Fixed emoji encoding issues

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              AWS PDF Translator                                  │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌──────────┐    ┌─────────────┐    ┌─────────────┐    ┌──────────────────┐    │
│  │ CloudFront│───▶│  S3 (Static │    │   Cognito   │    │   CloudWatch     │    │
│  │   (CDN)   │    │   Website)  │    │  User Pool  │    │   (Monitoring)   │    │
│  └──────────┘    └─────────────┘    └──────┬──────┘    └──────────────────┘    │
│                                             │                                    │
│                                             ▼                                    │
│  ┌──────────────────────────────────────────────────────────────────────────┐   │
│  │                          API Gateway (REST API)                           │   │
│  └────────────────────────────────┬─────────────────────────────────────────┘   │
│                                   │                                              │
│           ┌───────────────────────┼───────────────────────┐                     │
│           ▼                       ▼                       ▼                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │  Lambda:Upload  │    │Lambda:Translate │    │  Lambda:Status  │             │
│  └────────┬────────┘    └────────┬────────┘    └────────┬────────┘             │
│           │                      │                      │                       │
│           ▼                      ▼                      ▼                       │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐             │
│  │ S3: Upload      │    │ Amazon Translate│    │ DynamoDB: Jobs  │             │
│  │     Bucket      │───▶│    Service      │───▶│    Table        │             │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘             │
│           │                      │                                              │
│           │                      ▼                                              │
│           │             ┌─────────────────┐                                     │
│           └────────────▶│ S3: Outputs     │                                     │
│                         │    Bucket       │                                     │
│                         └─────────────────┘                                     │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Features

- **User Authentication**: Secure login/signup via Amazon Cognito
- **PDF Upload**: Drag-and-drop or click to upload PDF documents
- **Multi-language Translation**: Support for 70+ languages via Amazon Translate
- **Real-time Status**: Track translation progress
- **Download Translated Documents**: Get your translated PDF back
- **Cost-Effective**: Serverless architecture - pay only for what you use

## Project Structure

```
aws-pdf-translator/
├── infrastructure/
│   ├── cloudformation/
│   │   └── main.yaml              # Main CloudFormation template
│   └── scripts/
│       └── deploy.sh              # Deployment script
├── src/
│   └── frontend/
│       ├── src/
│       │   ├── App.js             # Main React component
│       │   └── App.css            # Styles
│       └── package.json           # Dependencies
├── .github/
│   └── workflows/
│       └── pipeline.yaml          # CI/CD pipeline
└── README.md
```

## Prerequisites

- AWS CLI v2 configured with appropriate credentials
- Node.js 18+ and npm
- Git

## Quick Start

### 1. Clone or Download the Project
```bash
# Create project directory
mkdir aws-pdf-translator
cd aws-pdf-translator
```

### 2. Set Up AWS Credentials
```bash
# Configure AWS CLI
aws configure
# Enter your AWS Access Key ID, Secret Access Key, and region (us-east-1)

# Verify configuration
aws sts get-caller-identity
```

### 3. Deploy Infrastructure
```bash
# Navigate to scripts directory
cd infrastructure/scripts

# Make deploy script executable
chmod +x deploy.sh

# Run deployment (dev environment)
./deploy.sh --env dev --region us-east-1

# Or deploy directly with AWS CLI
aws cloudformation deploy \
    --template-file ../cloudformation/main.yaml \
    --stack-name pdf-translator-dev \
    --parameter-overrides Environment=dev ProjectName=pdf-translator \
    --capabilities CAPABILITY_NAMED_IAM
```

### 4. Get Stack Outputs
```bash
# Get all outputs
aws cloudformation describe-stacks \
    --stack-name pdf-translator-dev \
    --query 'Stacks[0].Outputs' \
    --output table
```

### 5. Configure and Deploy Frontend
```bash
cd src/frontend

# Create .env file with your stack outputs
cat > .env << EOF
REACT_APP_API_ENDPOINT=https://YOUR_API_ID.execute-api.us-east-1.amazonaws.com/dev
REACT_APP_USER_POOL_ID=us-east-1_XXXXXXXXX
REACT_APP_USER_POOL_CLIENT_ID=XXXXXXXXXXXXXXXXXXXXXXXXXX
REACT_APP_REGION=us-east-1
EOF

# Install dependencies
npm install

# Build
npm run build

# Deploy to S3
FRONTEND_BUCKET=$(aws cloudformation describe-stacks \
    --stack-name pdf-translator-dev \
    --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
    --output text)

aws s3 sync build/ s3://$FRONTEND_BUCKET --delete

# Invalidate CloudFront
DIST_ID=$(aws cloudformation describe-stacks \
    --stack-name pdf-translator-dev \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

aws cloudfront create-invalidation --distribution-id $DIST_ID --paths "/*"
```

### 6. Access Your Application
```bash
# Get CloudFront URL
CLOUDFRONT_URL=$(aws cloudformation describe-stacks \
    --stack-name pdf-translator-dev \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
    --output text)

echo "Your application is at: https://$CLOUDFRONT_URL"
```

## Supported Languages

The application supports translation between 70+ languages including:
- English, Spanish, French, German, Italian, Portuguese
- Chinese (Simplified/Traditional), Japanese, Korean
- Arabic, Hindi, Russian, and many more

## Cost Optimization

This architecture is designed to be cost-effective:

| Service | Pricing Model | Estimated Monthly Cost* |
|---------|--------------|------------------------|
| Lambda | Per request + duration | $0.00 - $5.00 |
| S3 | Storage + requests | $0.50 - $2.00 |
| API Gateway | Per request | $0.00 - $3.50 |
| Cognito | Per MAU (first 50k free) | $0.00 |
| DynamoDB | On-demand capacity | $0.00 - $2.00 |
| Translate | Per character | $15/million chars |
| CloudFront | Data transfer + requests | $0.00 - $5.00 |

*Estimated for low-medium usage (~1000 translations/month)

## Security Features

- **Authentication**: JWT tokens via Cognito
- **Authorization**: IAM roles with least-privilege
- **Encryption**: S3 server-side encryption (SSE-S3)
- **HTTPS**: All API calls over TLS
- **CORS**: Configured for allowed origins only

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| CORS errors | Check API Gateway OPTIONS methods and S3 bucket CORS |
| 401 Unauthorized | Verify Cognito configuration and token format |
| 403 Forbidden | Check IAM role permissions |
| Lambda timeout | Increase timeout in CloudFormation (currently 300s) |
| No text extracted | PDF might be image-based; OCR not supported |

### Viewing Logs
```bash
# View Lambda logs
aws logs tail /aws/lambda/pdf-translator-upload-dev --follow
aws logs tail /aws/lambda/pdf-translator-translate-dev --follow
aws logs tail /aws/lambda/pdf-translator-status-dev --follow
```

## Cleanup

To delete all resources:
```bash
# Delete CloudFormation stack
aws cloudformation delete-stack --stack-name pdf-translator-dev

# Wait for deletion
aws cloudformation wait stack-delete-complete --stack-name pdf-translator-dev

# Note: S3 buckets with DeletionPolicy: Retain won't be deleted
# Empty and delete them manually if needed
```

## CI/CD Pipeline

The included GitHub Actions pipeline provides:
- Template validation and linting
- Security scanning with cfn-nag and Checkov
- Unit tests for frontend and Lambda
- Automated deployment to dev, staging, and prod
- CloudFront cache invalidation

### Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for dev |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for dev |
| `AWS_ACCESS_KEY_ID_STAGING` | AWS access key for staging |
| `AWS_SECRET_ACCESS_KEY_STAGING` | AWS secret key for staging |
| `AWS_ACCESS_KEY_ID_PROD` | AWS access key for prod |
| `AWS_SECRET_ACCESS_KEY_PROD` | AWS secret key for prod |

## License

MIT License - see LICENSE file for details.
