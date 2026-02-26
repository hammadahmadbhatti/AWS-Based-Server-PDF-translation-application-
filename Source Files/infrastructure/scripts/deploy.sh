#!/bin/bash
set -euo pipefail

# =============================================================================
# AWS PDF Translator - Deployment Script (CORRECTED VERSION)
# =============================================================================
# FIXES APPLIED:
# - Fixed path resolution to work from any directory
# - Added robust error handling
# - Improved output messages

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# FIX: Get script directory reliably, regardless of where script is called from
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE_DIR="$PROJECT_ROOT/infrastructure/cloudformation"
FRONTEND_DIR="$PROJECT_ROOT/src/frontend"

# Default values
ENVIRONMENT="dev"
REGION="us-east-1"
PROJECT_NAME="pdf-translator"
STACK_NAME=""
DRY_RUN=false
SKIP_VALIDATION=false

# =============================================================================
# FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}============================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy the AWS PDF Translator infrastructure.

Options:
    -e, --env           Environment (dev|staging|prod) [default: dev]
    -r, --region        AWS Region [default: us-east-1]
    -p, --project       Project name [default: pdf-translator]
    -n, --stack-name    Override stack name
    -d, --dry-run       Show what would be deployed without deploying
    -s, --skip-validate Skip template validation
    -h, --help          Show this help message

Examples:
    $(basename "$0") --env dev --region us-east-1
    $(basename "$0") --env prod --region eu-west-1
    $(basename "$0") --dry-run

Paths:
    Script Dir:    $SCRIPT_DIR
    Project Root:  $PROJECT_ROOT
    Templates:     $TEMPLATE_DIR

EOF
    exit 0
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local errors=0
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        print_info "Install from: https://aws.amazon.com/cli/"
        ((errors++))
    else
        local aws_version=$(aws --version 2>&1 | cut -d/ -f2 | cut -d' ' -f1)
        print_success "AWS CLI is installed (v$aws_version)"
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        print_info "Run 'aws configure' to set up credentials"
        ((errors++))
    else
        local account_id=$(aws sts get-caller-identity --query Account --output text)
        local user_arn=$(aws sts get-caller-identity --query Arn --output text)
        print_success "AWS credentials configured"
        print_info "  Account: $account_id"
        print_info "  Identity: $user_arn"
    fi
    
    # Check template directory exists
    if [ ! -d "$TEMPLATE_DIR" ]; then
        print_error "Template directory not found: $TEMPLATE_DIR"
        ((errors++))
    else
        print_success "Template directory found: $TEMPLATE_DIR"
    fi
    
    # Check main template exists
    if [ ! -f "$TEMPLATE_DIR/main.yaml" ]; then
        print_error "Main template not found: $TEMPLATE_DIR/main.yaml"
        ((errors++))
    else
        print_success "Main template found"
    fi
    
    # Check jq (optional but helpful)
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed (optional, for JSON parsing)"
        print_info "Install with: sudo apt install jq (Linux) or brew install jq (Mac)"
    else
        print_success "jq is installed"
    fi
    
    if [ $errors -gt 0 ]; then
        echo ""
        print_error "Prerequisites check failed with $errors error(s). Please fix the errors above."
        exit 1
    fi
    
    echo ""
    print_success "All prerequisites satisfied!"
    echo ""
}

validate_templates() {
    print_header "Validating CloudFormation Templates"
    
    local validation_errors=0
    
    # Validate main template
    if [ -f "$TEMPLATE_DIR/main.yaml" ]; then
        print_info "Validating main.yaml..."
        if aws cloudformation validate-template \
            --template-body "file://$TEMPLATE_DIR/main.yaml" \
            --region "$REGION" > /dev/null 2>&1; then
            print_success "main.yaml is valid"
        else
            print_error "main.yaml validation failed:"
            aws cloudformation validate-template \
                --template-body "file://$TEMPLATE_DIR/main.yaml" \
                --region "$REGION" 2>&1 || true
            ((validation_errors++))
        fi
    else
        print_error "main.yaml not found at $TEMPLATE_DIR/main.yaml"
        ((validation_errors++))
    fi
    
    if [ $validation_errors -gt 0 ]; then
        print_error "Template validation failed"
        exit 1
    fi
    
    echo ""
}

lint_templates() {
    print_header "Linting CloudFormation Templates"
    
    # Check if cfn-lint is installed
    if command -v cfn-lint &> /dev/null; then
        print_info "Running cfn-lint..."
        if cfn-lint "$TEMPLATE_DIR"/*.yaml 2>/dev/null; then
            print_success "All templates passed linting"
        else
            print_warning "Linting found issues (non-blocking)"
        fi
    else
        print_warning "cfn-lint not installed, skipping linting"
        print_info "Install with: pip install cfn-lint"
    fi
    
    echo ""
}

estimate_costs() {
    print_header "Estimated Monthly Costs"
    
    cat << EOF
┌─────────────────────────────────────────────────────────┐
│ Service                │ Estimated Cost (low-medium)   │
├────────────────────────┼───────────────────────────────┤
│ Lambda Functions       │ \$0.00 - \$5.00               │
│ S3 Storage             │ \$0.50 - \$2.00               │
│ API Gateway            │ \$0.00 - \$3.50               │
│ DynamoDB (On-Demand)   │ \$0.00 - \$2.00               │
│ CloudFront             │ \$0.00 - \$5.00               │
│ Cognito (50k MAU free) │ \$0.00                        │
│ CloudWatch Logs        │ \$0.50 - \$2.00               │
│ Amazon Translate       │ \$15.00/million chars         │
├────────────────────────┼───────────────────────────────┤
│ TOTAL ESTIMATED        │ \$16.00 - \$35.00/month       │
└─────────────────────────────────────────────────────────┘

Note: Actual costs depend on usage. First 12 months may be
covered by AWS Free Tier for new accounts.

EOF
}

deploy_stack() {
    print_header "Deploying CloudFormation Stack"
    
    local stack_name="${STACK_NAME:-$PROJECT_NAME-$ENVIRONMENT}"
    
    print_info "Configuration:"
    echo "  Stack Name:   $stack_name"
    echo "  Environment:  $ENVIRONMENT"
    echo "  Region:       $REGION"
    echo "  Template:     $TEMPLATE_DIR/main.yaml"
    echo ""
    
    # Check if stack exists
    local stack_status=""
    if aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" &> /dev/null; then
        stack_status=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$REGION" \
            --query 'Stacks[0].StackStatus' \
            --output text)
        print_info "Existing stack found with status: $stack_status"
    fi
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN - Would deploy stack with the above configuration"
        print_info "Run without --dry-run to actually deploy"
        return 0
    fi
    
    # Handle failed stacks
    if [ -n "$stack_status" ]; then
        if [[ "$stack_status" == *"ROLLBACK"* ]] || [[ "$stack_status" == "DELETE_FAILED" ]]; then
            print_warning "Stack is in $stack_status state. Deleting and recreating..."
            aws cloudformation delete-stack --stack-name "$stack_name" --region "$REGION"
            print_info "Waiting for stack deletion..."
            aws cloudformation wait stack-delete-complete --stack-name "$stack_name" --region "$REGION" || true
            print_success "Stack deleted"
            stack_status=""
        fi
    fi
    
    print_info "Starting stack deployment..."
    echo ""
    
    # Deploy stack
    if aws cloudformation deploy \
        --template-file "$TEMPLATE_DIR/main.yaml" \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --parameter-overrides \
            Environment="$ENVIRONMENT" \
            ProjectName="$PROJECT_NAME" \
        --capabilities CAPABILITY_NAMED_IAM \
        --tags \
            Environment="$ENVIRONMENT" \
            Project="$PROJECT_NAME" \
            ManagedBy=CloudFormation \
        --no-fail-on-empty-changeset; then
        print_success "Stack deployment completed successfully!"
    else
        local exit_code=$?
        if [ $exit_code -eq 255 ]; then
            print_warning "No changes to deploy"
        else
            print_error "Stack deployment failed with exit code $exit_code"
            print_info "Check CloudFormation console for details"
            exit 1
        fi
    fi
    
    echo ""
}

print_outputs() {
    print_header "Stack Outputs"
    
    local stack_name="${STACK_NAME:-$PROJECT_NAME-$ENVIRONMENT}"
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN - Outputs not available"
        return 0
    fi
    
    # Get outputs
    local outputs
    outputs=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output json 2>/dev/null || echo "[]")
    
    if [ "$outputs" != "[]" ] && [ -n "$outputs" ] && [ "$outputs" != "null" ]; then
        echo ""
        if command -v jq &> /dev/null; then
            echo "$outputs" | jq -r '.[] | "  \(.OutputKey): \(.OutputValue)"'
        else
            aws cloudformation describe-stacks \
                --stack-name "$stack_name" \
                --region "$REGION" \
                --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
                --output table
        fi
        echo ""
    else
        print_warning "No outputs available yet"
    fi
}

create_config_file() {
    print_header "Creating Frontend Configuration"
    
    local stack_name="${STACK_NAME:-$PROJECT_NAME-$ENVIRONMENT}"
    
    if [ "$DRY_RUN" = true ]; then
        print_warning "DRY RUN - Config file not created"
        return 0
    fi
    
    # Get stack outputs
    local api_endpoint user_pool_id client_id
    
    api_endpoint=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiEndpoint`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    user_pool_id=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    client_id=$(aws cloudformation describe-stacks \
        --stack-name "$stack_name" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' \
        --output text 2>/dev/null || echo "")
    
    if [ -n "$api_endpoint" ] && [ -n "$user_pool_id" ] && [ -n "$client_id" ]; then
        # Create frontend directory if needed
        mkdir -p "$FRONTEND_DIR"
        
        local config_file="$FRONTEND_DIR/.env.$ENVIRONMENT"
        
        cat > "$config_file" << EOF
# Auto-generated by deploy.sh on $(date)
# Do not commit to version control!

REACT_APP_API_ENDPOINT=$api_endpoint
REACT_APP_USER_POOL_ID=$user_pool_id
REACT_APP_USER_POOL_CLIENT_ID=$client_id
REACT_APP_REGION=$REGION
REACT_APP_ENVIRONMENT=$ENVIRONMENT
EOF
        
        print_success "Frontend config created: $config_file"
        
        # Also create a .env file for local development
        if [ "$ENVIRONMENT" = "dev" ]; then
            cp "$config_file" "$FRONTEND_DIR/.env"
            print_success "Copied to .env for local development"
        fi
    else
        print_warning "Could not retrieve all stack outputs for config"
        print_info "Manually create .env file with outputs from CloudFormation"
    fi
    
    echo ""
}

print_next_steps() {
    print_header "Deployment Complete! 🎉"
    
    local stack_name="${STACK_NAME:-$PROJECT_NAME-$ENVIRONMENT}"
    
    # Get CloudFront URL
    local cloudfront_url=""
    local frontend_bucket=""
    local dist_id=""
    
    if [ "$DRY_RUN" = false ]; then
        cloudfront_url=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDomain`].OutputValue' \
            --output text 2>/dev/null || echo "")
        
        frontend_bucket=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`FrontendBucketName`].OutputValue' \
            --output text 2>/dev/null || echo "")
        
        dist_id=$(aws cloudformation describe-stacks \
            --stack-name "$stack_name" \
            --region "$REGION" \
            --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
            --output text 2>/dev/null || echo "")
    fi
    
    echo ""
    print_info "Next steps to deploy the frontend:"
    echo ""
    echo "  1. Navigate to frontend directory:"
    echo "     cd $FRONTEND_DIR"
    echo ""
    echo "  2. Install dependencies:"
    echo "     npm install"
    echo ""
    echo "  3. Build the application:"
    echo "     npm run build"
    echo ""
    
    if [ -n "$frontend_bucket" ]; then
        echo "  4. Deploy to S3:"
        echo "     aws s3 sync build/ s3://$frontend_bucket --delete"
        echo ""
    else
        echo "  4. Deploy to S3:"
        echo "     aws s3 sync build/ s3://\$(FRONTEND_BUCKET) --delete"
        echo ""
    fi
    
    if [ -n "$dist_id" ]; then
        echo "  5. Invalidate CloudFront cache:"
        echo "     aws cloudfront create-invalidation --distribution-id $dist_id --paths '/*'"
        echo ""
    else
        echo "  5. Invalidate CloudFront cache:"
        echo "     aws cloudfront create-invalidation --distribution-id \$(DIST_ID) --paths '/*'"
        echo ""
    fi
    
    if [ -n "$cloudfront_url" ]; then
        echo ""
        print_success "Your application will be available at:"
        echo "     https://$cloudfront_url"
    fi
    
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -p|--project)
            PROJECT_NAME="$2"
            shift 2
            ;;
        -n|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -s|--skip-validate)
            SKIP_VALIDATION=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            usage
            ;;
    esac
done

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_info "Valid options: dev, staging, prod"
    exit 1
fi

# Production deployment warning
if [ "$ENVIRONMENT" = "prod" ] && [ "$DRY_RUN" = false ]; then
    echo ""
    print_warning "╔════════════════════════════════════════════════════════╗"
    print_warning "║  WARNING: You are about to deploy to PRODUCTION!       ║"
    print_warning "╚════════════════════════════════════════════════════════╝"
    echo ""
    read -p "Are you sure you want to continue? Type 'yes' to confirm: " confirm
    if [ "$confirm" != "yes" ]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    echo ""
fi

# Run deployment steps
echo ""
print_header "AWS PDF Translator Deployment"
echo "Environment:  $ENVIRONMENT"
echo "Region:       $REGION"
echo "Project:      $PROJECT_NAME"
echo "Template Dir: $TEMPLATE_DIR"
echo ""

check_prerequisites

if [ "$SKIP_VALIDATION" = false ]; then
    validate_templates
    lint_templates
fi

estimate_costs

if [ "$DRY_RUN" = true ]; then
    print_warning "═══════════════════════════════════════════"
    print_warning " DRY RUN MODE - No changes will be made"
    print_warning "═══════════════════════════════════════════"
    echo ""
fi

read -p "Continue with deployment? (y/n): " proceed
if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
    print_info "Deployment cancelled"
    exit 0
fi

echo ""
deploy_stack
print_outputs
create_config_file
print_next_steps
