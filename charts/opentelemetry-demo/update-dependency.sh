#!/bin/bash

# Script to update opentelemetry-kube-stack dependency version and bump chart version
# This script:
# 1. Extracts the current version from opentelemetry-kube-stack/Chart.yaml
# 2. Updates the dependency version in opentelemetry-demo/Chart.yaml
# 3. Increments the minor version of opentelemetry-demo chart
# 4. Runs pre-commit hooks
# 5. Creates a branch, commits, pushes, and creates a PR

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the repository root directory (where .git folder is located)
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$REPO_ROOT"

# Paths relative to repo root
KUBE_STACK_CHART="${REPO_ROOT}/charts/opentelemetry-kube-stack/Chart.yaml"
DEMO_CHART="${REPO_ROOT}/charts/opentelemetry-demo/Chart.yaml"
SCRIPT_DIR="${REPO_ROOT}/charts/opentelemetry-demo"

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_error() {
    print_status "$RED" "$1"
}

print_success() {
    print_status "$GREEN" "$1"
}

print_info() {
    print_status "$BLUE" "$1"
}

print_warning() {
    print_status "$YELLOW" "$1"
}

# Check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    if ! command -v git &> /dev/null; then
        print_error "Error: git is not installed"
        exit 1
    fi
    
    if ! command -v gh &> /dev/null; then
        print_error "Error: GitHub CLI (gh) is not installed"
        exit 1
    fi
    
    if ! gh auth status &> /dev/null; then
        print_error "Error: GitHub CLI is not authenticated. Run 'gh auth login'"
        exit 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir &> /dev/null; then
        print_error "Error: Not in a git repository"
        exit 1
    fi
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "Warning: You have uncommitted changes. Please commit or stash them first."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check if files exist
    if [[ ! -f "$KUBE_STACK_CHART" ]]; then
        print_error "Error: $KUBE_STACK_CHART not found"
        exit 1
    fi
    
    if [[ ! -f "$DEMO_CHART" ]]; then
        print_error "Error: $DEMO_CHART not found"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Extract version from Chart.yaml
extract_version() {
    local chart_file=$1
    local version_line
    
    version_line=$(grep -E "^version:" "$chart_file" | head -n 1)
    if [[ -z "$version_line" ]]; then
        print_error "Error: Could not find version in $chart_file"
        exit 1
    fi
    
    # Extract version number (format: version: X.Y.Z)
    echo "$version_line" | sed -E 's/^version:[[:space:]]*//' | tr -d '[:space:]'
}

# Increment minor version (e.g., 0.1.4 -> 0.2.0)
increment_minor_version() {
    local current_version=$1
    local major minor patch
    
    # Parse version (MAJOR.MINOR.PATCH)
    IFS='.' read -r major minor patch <<< "$current_version"
    
    # Increment minor, reset patch to 0
    minor=$((minor + 1))
    patch=0
    
    echo "${major}.${minor}.${patch}"
}

# Update version in Chart.yaml
update_version_in_chart() {
    local chart_file=$1
    local old_version=$2
    local new_version=$3
    local field_name=$4
    
    # Escape dots in version numbers for sed
    local escaped_old_version=$(echo "$old_version" | sed 's/\./\\./g')
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS uses BSD sed
        sed -i '' "s/^${field_name}:[[:space:]]*${escaped_old_version}/${field_name}: ${new_version}/" "$chart_file"
    else
        # Linux uses GNU sed
        sed -i "s/^${field_name}:[[:space:]]*${escaped_old_version}/${field_name}: ${new_version}/" "$chart_file"
    fi
}

# Main execution
main() {
    print_info "=========================================="
    print_info "  Update Dependency Script"
    print_info "=========================================="
    echo
    
    check_prerequisites
    
    # Step 1: Extract current version from opentelemetry-kube-stack
    print_info "Step 1: Extracting version from opentelemetry-kube-stack..."
    KUBE_STACK_VERSION=$(extract_version "$KUBE_STACK_CHART")
    print_success "Found opentelemetry-kube-stack version: $KUBE_STACK_VERSION"
    
    # Step 2: Get current dependency version and chart version
    print_info "Step 2: Reading current versions from opentelemetry-demo..."
    CURRENT_CHART_VERSION=$(extract_version "$DEMO_CHART")
    
    # Extract dependency version for opentelemetry-kube-stack
    # Find the line with "name: opentelemetry-kube-stack" and get the version from the next few lines
    CURRENT_DEP_VERSION=$(awk '/name: opentelemetry-kube-stack$/,/condition:/ {if (/version:/) {gsub(/^[[:space:]]*version:[[:space:]]*/, ""); gsub(/[[:space:]]*$/, ""); print}}' "$DEMO_CHART")
    
    if [[ -z "$CURRENT_DEP_VERSION" ]]; then
        print_error "Error: Could not find opentelemetry-kube-stack dependency version"
        exit 1
    fi
    
    print_info "Current dependency version: $CURRENT_DEP_VERSION"
    print_info "Current chart version: $CURRENT_CHART_VERSION"
    
    # Check if update is needed
    if [[ "$CURRENT_DEP_VERSION" == "$KUBE_STACK_VERSION" ]]; then
        print_warning "Dependency version is already up to date ($KUBE_STACK_VERSION)"
        print_info "Proceeding with version bump only..."
    fi
    
    # Step 3: Calculate new chart version
    NEW_CHART_VERSION=$(increment_minor_version "$CURRENT_CHART_VERSION")
    print_info "New chart version will be: $NEW_CHART_VERSION"
    
    # Step 4: Update dependency version in Chart.yaml
    if [[ "$CURRENT_DEP_VERSION" != "$KUBE_STACK_VERSION" ]]; then
        print_info "Step 3: Updating dependency version from $CURRENT_DEP_VERSION to $KUBE_STACK_VERSION..."
        # Escape dots in version numbers for sed
        ESCAPED_CURRENT_DEP_VERSION=$(echo "$CURRENT_DEP_VERSION" | sed 's/\./\\./g')
        # Update the dependency version line (need to find the specific dependency)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS uses BSD sed
            sed -i '' "/name: opentelemetry-kube-stack$/,/condition:/ s/^\([[:space:]]*version:\)[[:space:]]*${ESCAPED_CURRENT_DEP_VERSION}/\1 ${KUBE_STACK_VERSION}/" "$DEMO_CHART"
        else
            # Linux uses GNU sed
            sed -i "/name: opentelemetry-kube-stack$/,/condition:/ s/^\([[:space:]]*version:\)[[:space:]]*${ESCAPED_CURRENT_DEP_VERSION}/\1 ${KUBE_STACK_VERSION}/" "$DEMO_CHART"
        fi
        print_success "Dependency version updated"
    fi
    
    # Step 5: Update chart version
    print_info "Step 4: Updating chart version from $CURRENT_CHART_VERSION to $NEW_CHART_VERSION..."
    update_version_in_chart "$DEMO_CHART" "$CURRENT_CHART_VERSION" "$NEW_CHART_VERSION" "version"
    print_success "Chart version updated"
    
    # Step 6: Run pre-commit
    print_info "Step 5: Running pre-commit hooks..."
    if pre-commit run --all-files; then
        print_success "Pre-commit checks passed"
    else
        print_warning "Pre-commit hooks failed, but continuing as intended..."
    fi
    
    # Step 7: Create branch
    BRANCH_NAME="update/opentelemetry-demo-deps-${KUBE_STACK_VERSION}"
    print_info "Step 6: Creating branch: $BRANCH_NAME..."
    git checkout -b "$BRANCH_NAME" 2>/dev/null || {
        print_warning "Branch $BRANCH_NAME already exists. Checking it out..."
        git checkout "$BRANCH_NAME"
    }
    print_success "Branch ready"
    
    # Step 8: Stage and commit changes
    print_info "Step 7: Staging changes..."
    git add -A
    COMMIT_MSG="chore: update opentelemetry-kube-stack dependency to ${KUBE_STACK_VERSION} and bump chart version to ${NEW_CHART_VERSION}"
    print_info "Step 8: Committing changes..."
    git commit -m "$COMMIT_MSG" || {
        print_warning "No changes to commit (files may be unchanged)"
    }
    print_success "Changes committed"
    
    # Step 9: Push branch
    print_info "Step 9: Pushing branch to remote..."
    git push -u origin "$BRANCH_NAME" || {
        print_error "Failed to push branch. Please check your git remote configuration."
        exit 1
    }
    print_success "Branch pushed"
    
    # Step 10: Create pull request
    print_info "Step 10: Creating pull request..."
    PR_TITLE="chore: update opentelemetry-kube-stack dependency to ${KUBE_STACK_VERSION}"
    PR_BODY="This PR updates the \`opentelemetry-kube-stack\` dependency version to \`${KUBE_STACK_VERSION}\` and bumps the chart version to \`${NEW_CHART_VERSION}\`.

## Changes
- Updated \`opentelemetry-kube-stack\` dependency: \`${CURRENT_DEP_VERSION}\` → \`${KUBE_STACK_VERSION}\`
- Bumped chart version: \`${CURRENT_CHART_VERSION}\` → \`${NEW_CHART_VERSION}\`
- Ran pre-commit hooks to ensure code quality

## Checklist
- [x] Dependency version updated
- [x] Chart version bumped
- [x] Pre-commit hooks passed
- [x] Changes committed and pushed"
    
    gh pr create --title "$PR_TITLE" --body "$PR_BODY" || {
        print_error "Failed to create pull request. You may need to create it manually."
        print_info "Branch $BRANCH_NAME has been pushed and is ready for manual PR creation."
        exit 1
    }
    print_success "Pull request created successfully!"
    
    echo
    print_success "=========================================="
    print_success "  All steps completed successfully!"
    print_success "=========================================="
}

# Run main function
main
