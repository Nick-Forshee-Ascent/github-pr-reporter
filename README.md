# GitHub Pull Request Report Generator

This script generates comprehensive reports showing all pull requests merged into a specified branch (defaults to `develop`) across all repositories in a GitHub organization. Useful for compliance audits, code review tracking, and change management documentation.

Works with any GitHub organization and branch - just specify the organization name and optionally the branch name when running the script.

## Features

- **Automatic Repository Discovery**: Scans all repositories in the organization
- **Smart Filtering**: Only processes repositories with the specified branch (default: `develop`) and PRs in the date range
- **Pagination Support**: Handles repositories with more than 1000 merged PRs
- **Interactive Wizard Mode**: Run without arguments for a guided, step-by-step experience
- **Progress Indicators**: Visual feedback during long-running operations
- **Comprehensive Reports**: Each report includes:
  1. Command executed to fetch the data
  2. Timestamp of when the command was run
  3. Total number of PRs merged into the specified branch
  4. Complete list of PRs with details (Number, Title, Branch, Merged At, Author, URL, Reviewers Requested, Approvals)
  5. Pagination details (how many pages were fetched)
- **Multiple Output Formats**:
  - CSV format (always generated)
  - PDF format (if pandoc or wkhtmltopdf is installed)

## Installation

### Prerequisites

Before using this script, ensure you have the following installed:

1. **GitHub CLI (`gh`)** - Required for API access
   ```bash
   # macOS
   brew install gh

   # Linux (Ubuntu/Debian)
   sudo apt-get install gh

   # Or download from: https://cli.github.com/
   ```

2. **jq** - Required for JSON processing
   ```bash
   # macOS
   brew install jq

   # Linux (Ubuntu/Debian)
   sudo apt-get install jq
   ```

3. **GitHub CLI Authentication** - Required to access repositories
   ```bash
   gh auth login
   ```
   Follow the prompts to authenticate with your GitHub account.

### Setup

1. **Clone or download this repository:**
   ```bash
   git clone <repository-url>
   cd github-pr-reporter
   ```

2. **Make the script executable:**
   ```bash
   chmod +x github_pr_report.sh
   ```

3. **Verify the script is executable:**
   ```bash
   ls -l github_pr_report.sh
   ```
   You should see `-rwxr-xr-x` (the `x` indicates executable permissions).

4. **Test the installation:**
   ```bash
   ./github_pr_report.sh --help
   ```
   This should display the help message.

## Usage

### Interactive Mode (Wizard)

Simply run the script without any arguments to enter interactive mode:

```bash
./github_pr_report.sh
```

The script will prompt you for each required parameter:
- Start date
- End date (optional, defaults to today)
- Organization name
- Branch name (optional, defaults to 'develop')
- Repositories to skip (optional)

### Command-Line Mode

You can also provide all arguments directly:

```bash
# With both start and end dates (uses default 'develop' branch)
./github_pr_report.sh --start-date 2024-11-01 --end-date 2025-10-31 --org MyOrganization

# With only start date (end date defaults to today, branch defaults to 'develop')
./github_pr_report.sh --start-date 2024-11-01 --org MyOrganization

# With custom branch (e.g., 'main' or 'master')
./github_pr_report.sh --start-date 2024-11-01 --org MyOrganization --branch main

# With all options specified
./github_pr_report.sh --start-date 2024-11-01 --end-date 2025-10-31 --org MyOrganization --branch master

# Excluding specific repositories
./github_pr_report.sh --start-date 2024-11-01 --org MyOrganization --skip-repos project_x,project_y

# Combining options
./github_pr_report.sh --start-date 2024-11-01 --org MyOrganization --branch main --skip-repos old-repo,test-repo

# Show help
./github_pr_report.sh --help
```

### Arguments

- `--start-date DATE` (required): Start date in YYYY-MM-DD format
- `--end-date DATE` (optional): End date in YYYY-MM-DD format. If not provided, defaults to today's date
- `--org ORG` (required): GitHub organization name
- `--branch BRANCH` (optional): Branch name to check for merged PRs. Defaults to `develop` if not specified
- `--skip-repos LIST` (optional): Comma-separated list of repository names to exclude from the report

## Output

Reports are saved in a timestamped directory: `pr_reports_YYYYMMDD_HHMMSS/`

Each repository with merged PRs will have:
- `{repo_name}_PR_Report.csv` - CSV format report
- `{repo_name}_PR_Report.pdf` - PDF format (if pandoc is available)

A summary file `00_SUMMARY.txt` is also generated with overall statistics.

## PDF Generation

To enable PDF generation, install pandoc:

```bash
# macOS
brew install pandoc

# Linux
sudo apt-get install pandoc
```

## Report Contents

Each report includes:

1. **Header Information**:
   - Repository name
   - Organization
   - Report generation timestamp
   - Date range requested (as provided by user)
   - Branch name (as specified, defaults to develop)

2. **Command Executed**: The exact GitHub API command used to fetch the data

3. **Execution Details**:
   - Timestamp
   - Total PRs merged
   - Number of pages fetched
   - Whether pagination was required

4. **Pull Request Summary Table**:
   - PR Number
   - Title
   - Branch name
   - Merged timestamp
   - Author
   - URL
   - Reviewers requested count
   - Approvals count

## Use Cases

These reports can be used for:
- **Compliance Audits**: Document that all PRs merged into develop have gone through the review process
- **Code Review Tracking**: Track review processes and ensure they are documented and traceable
- **Change Management**: Maintain records of all changes with timestamps and authors
- **Process Documentation**: Generate evidence of development workflows and review practices
