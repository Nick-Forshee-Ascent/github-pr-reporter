#!/bin/bash

# GitHub Pull Request Report Generator
# Generates reports for all repositories showing PRs merged into a specified branch

# Don't use set -e as we want to continue processing even if some repos fail

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --start-date DATE    Start date in YYYY-MM-DD format (required)"
    echo "  --end-date DATE      End date in YYYY-MM-DD format (optional, defaults to today)"
    echo "  --org ORG            GitHub organization name (required)"
    echo "  --branch BRANCH      Branch name to check (optional, defaults to 'develop')"
    echo "  --skip-repos LIST    Comma-separated list of repositories to skip (optional)"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --start-date 2024-11-01 --end-date 2025-10-31 --org MyOrganization"
    echo "  $0 --start-date 2024-11-01 --org MyOrganization"
    echo "  $0 --start-date 2024-11-01 --end-date 2025-10-31 --org MyOrg --branch main"
    echo "  $0 --start-date 2024-11-01 --org MyOrg --branch master"
    echo "  $0 --start-date 2024-11-01 --org MyOrg --skip-repos project_x,project_y"
    exit 1
}

# Parse command line arguments
START_DATE=""
END_DATE=""
ORG=""
BRANCH="develop"
SKIP_REPOS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --start-date)
            START_DATE="$2"
            shift 2
            ;;
        --end-date)
            END_DATE="$2"
            shift 2
            ;;
        --org)
            ORG="$2"
            shift 2
            ;;
        --branch)
            BRANCH="$2"
            shift 2
            ;;
        --skip-repos)
            SKIP_REPOS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Interactive wizard mode if no arguments provided
if [ $# -eq 0 ]; then
    echo "=========================================="
    echo "GitHub Pull Request Report Generator"
    echo "Interactive Mode"
    echo "=========================================="
    echo ""

    # Prompt for start date
    while [ -z "$START_DATE" ]; do
        read -p "Enter start date (YYYY-MM-DD, required): " START_DATE
        if [ -z "$START_DATE" ]; then
            echo "  Error: Start date is required"
        elif ! [[ "$START_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            echo "  Error: Date must be in YYYY-MM-DD format"
            START_DATE=""
        fi
    done

    # Prompt for end date (optional)
    read -p "Enter end date (YYYY-MM-DD, optional, press Enter for today): " END_DATE_INPUT
    if [ -z "$END_DATE_INPUT" ]; then
        END_DATE=$(date +%Y-%m-%d)
        echo "  Using today's date: $END_DATE"
    else
        if [[ "$END_DATE_INPUT" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            END_DATE="$END_DATE_INPUT"
        else
            echo "  Error: Invalid date format, using today's date"
            END_DATE=$(date +%Y-%m-%d)
        fi
    fi

    # Prompt for organization
    while [ -z "$ORG" ]; do
        read -p "Enter GitHub organization name (required): " ORG
        if [ -z "$ORG" ]; then
            echo "  Error: Organization name is required"
        fi
    done

    # Prompt for branch (optional)
    read -p "Enter branch name (optional, press Enter for 'develop'): " BRANCH_INPUT
    if [ -n "$BRANCH_INPUT" ]; then
        BRANCH="$BRANCH_INPUT"
    fi

    # Prompt for skip repos (optional)
    read -p "Enter repositories to skip (comma-separated, optional, press Enter for none): " SKIP_REPOS

    echo ""
    echo "Configuration:"
    echo "  Start Date: $START_DATE"
    echo "  End Date: $END_DATE"
    echo "  Organization: $ORG"
    echo "  Branch: $BRANCH"
    if [ -n "$SKIP_REPOS" ]; then
        echo "  Skipping: $SKIP_REPOS"
    fi
    echo ""
    read -p "Continue? (y/n): " CONFIRM
    if [ "${CONFIRM,,}" != "y" ] && [ "${CONFIRM,,}" != "yes" ]; then
        echo "Cancelled."
        exit 0
    fi
    echo ""
fi

# Validate required parameters (for command-line mode)
if [ -z "$START_DATE" ]; then
    echo "Error: --start-date is required"
    usage
fi

if [ -z "$ORG" ]; then
    echo "Error: --org is required"
    usage
fi

# Validate date format (basic check)
if ! [[ "$START_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: Start date must be in YYYY-MM-DD format"
    exit 1
fi

# Set end date to today if not provided
if [ -z "$END_DATE" ]; then
    END_DATE=$(date +%Y-%m-%d)
fi

# Validate end date format
if ! [[ "$END_DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Error: End date must be in YYYY-MM-DD format"
    exit 1
fi

# Validate date range
if [ "$START_DATE" \> "$END_DATE" ]; then
    echo "Error: Start date must be before or equal to end date"
    exit 1
fi

OUTPUT_DIR="pr_reports_$(date +%Y%m%d_%H%M%S)"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Check for PDF generation tools
HAS_PANDOC=$(command -v pandoc 2>/dev/null)
HAS_WKHTML=$(command -v wkhtmltopdf 2>/dev/null)
GENERATE_PDF=false
PDF_TOOL=""
PDF_ENGINE=""

if [ -n "$HAS_PANDOC" ]; then
    # Check for available PDF engines
    if command -v pdflatex &>/dev/null; then
        GENERATE_PDF=true
        PDF_TOOL="pandoc"
        PDF_ENGINE="pdflatex"
    elif command -v xelatex &>/dev/null; then
        GENERATE_PDF=true
        PDF_TOOL="pandoc"
        PDF_ENGINE="xelatex"
    elif command -v lualatex &>/dev/null; then
        GENERATE_PDF=true
        PDF_TOOL="pandoc"
        PDF_ENGINE="lualatex"
    elif command -v weasyprint &>/dev/null; then
        GENERATE_PDF=true
        PDF_TOOL="weasyprint"
    elif [ -n "$HAS_WKHTML" ]; then
        GENERATE_PDF=true
        PDF_TOOL="wkhtmltopdf"
    fi
elif [ -n "$HAS_WKHTML" ]; then
    GENERATE_PDF=true
    PDF_TOOL="wkhtmltopdf"
fi

echo "=========================================="
echo "GitHub Pull Request Report Generator"
echo "=========================================="
echo "Organization: $ORG"
echo "Date Range: $START_DATE to $END_DATE"
echo "Branch: $BRANCH"
if [ -n "$SKIP_REPOS" ]; then
    echo "Skipping Repositories: $SKIP_REPOS"
fi
echo "Output Directory: $OUTPUT_DIR"
echo "Timestamp: $TIMESTAMP"
if [ "$GENERATE_PDF" = true ]; then
    if [ "$PDF_TOOL" = "pandoc" ]; then
        echo "PDF Generation: Enabled (pandoc with $PDF_ENGINE)"
    else
        echo "PDF Generation: Enabled ($PDF_TOOL)"
    fi
else
    echo "PDF Generation: Disabled"
    if [ -n "$HAS_PANDOC" ]; then
        echo "  Note: pandoc is installed but no PDF engine found."
        echo "  Install a LaTeX distribution (e.g., 'brew install basictex' on macOS)"
        echo "  or install weasyprint/wkhtmltopdf for PDF support."
    else
        echo "  Install pandoc + LaTeX engine, weasyprint, or wkhtmltopdf for PDF support."
    fi
fi
echo "=========================================="
echo ""

# Function to check if repository should be skipped
should_skip_repo() {
    local repo=$1
    local repo_name=$(basename "$repo")

    if [ -z "$SKIP_REPOS" ]; then
        return 1  # Don't skip if no skip list
    fi

    # Convert comma-separated list to check each repo
    IFS=',' read -ra SKIP_ARRAY <<< "$SKIP_REPOS"
    for skip_repo in "${SKIP_ARRAY[@]}"; do
        # Trim whitespace
        skip_repo=$(echo "$skip_repo" | xargs)
        # Check if repo name matches (case-insensitive)
        if [ "${repo_name,,}" = "${skip_repo,,}" ]; then
            return 0  # Skip this repo
        fi
    done

    return 1  # Don't skip
}

# Function to check if branch exists
check_branch() {
    local repo=$1
    local branch=$2
    gh api "repos/$repo/branches/$branch" &>/dev/null
    return $?
}

# Function to fetch all merged PRs with pagination
fetch_merged_prs() {
    local repo=$1
    local output_file=$2
    local page=1
    local per_page=100
    local temp_file=$(mktemp)
    local total_count=0
    local page_count=0

    echo "  Fetching merged PRs (paginated)..." >&2
    echo -n "  Progress: " >&2

    while true; do
        # Show progress indicator
        echo -n "." >&2

        local response=$(gh api "repos/$repo/pulls?state=closed&base=$BRANCH&per_page=$per_page&page=$page&sort=updated&direction=desc" 2>&1)

        if [ $? -ne 0 ]; then
            echo "" >&2
            echo "  Error fetching page $page" >&2
            break
        fi

        local count=$(echo "$response" | jq '. | length')

        if [ "$count" -eq 0 ]; then
            echo "" >&2
            break
        fi

        # Filter by merged status and date range
        # Note: Detailed approval counts require additional API calls per PR (slow)
        # Merged status indicates PR passed review requirements
        local page_results=$(echo "$response" | jq -r --arg start "$START_DATE" --arg end "$END_DATE" '
            .[] |
            select(.merged_at != null) |
            select(.merged_at >= ($start + "T00:00:00Z") and .merged_at <= ($end + "T23:59:59Z")) |
            [.number, .title, .head.ref, .merged_at, .user.login, .html_url, (.requested_reviewers // [] | length), "See PR URL"] | @tsv
        ')

        if [ -n "$page_results" ]; then
            echo "$page_results" >> "$temp_file"
            local page_pr_count=$(echo "$page_results" | wc -l | tr -d ' ')
            total_count=$((total_count + page_pr_count))
            page_count=$((page_count + 1))
        fi

        if [ "$count" -lt "$per_page" ]; then
            echo "" >&2
            break
        fi

        page=$((page + 1))

        # Safety limit
        if [ "$page" -gt 200 ]; then
            echo "  Reached page limit (200)" >&2
            break
        fi
    done

    # Sort by merged date (newest first) and add header
    echo "  Generating report file..." >&2
    {
        echo -e "Number\tTitle\tBranch\tMerged At\tAuthor\tURL\tReviewers Requested\tApproval Status"
        if [ -s "$temp_file" ]; then
            sort -t$'\t' -k4 -r "$temp_file"
        fi
    } > "$output_file"

    rm "$temp_file"

    echo "$total_count|$page_count"
}

# Function to generate report for a repository
generate_report() {
    local repo=$1
    local repo_name=$(basename "$repo")
    local report_file="$OUTPUT_DIR/${repo_name}_report.csv"
    local command_used="gh api \"repos/$repo/pulls?state=closed&base=$BRANCH&per_page=100&page={page}&sort=updated&direction=desc\" | jq -r '.[] | select(.merged_at != null) | select(.merged_at >= \"${START_DATE}T00:00:00Z\" and .merged_at <= \"${END_DATE}T23:59:59Z\") | [.number, .title, .head.ref, .merged_at, .user.login, .html_url] | @tsv'"

    echo "----------------------------------------"

    # Check if branch exists
    if ! check_branch "$repo" "$BRANCH"; then
        echo "  ⚠ Skipping: $BRANCH branch does not exist"
        echo ""
        return
    fi

    # Fetch PRs
    local result=$(fetch_merged_prs "$repo" "$report_file")
    local total_prs=$(echo "$result" | cut -d'|' -f1)
    local pages_fetched=$(echo "$result" | cut -d'|' -f2)

    if [ "$total_prs" -eq 0 ]; then
        echo "  ⚠ Skipping: No PRs merged in date range"
        rm -f "$report_file"
        echo ""
        return
    fi

    # Create comprehensive report with header (CSV format)
    echo "  Creating report document..." >&2
    local final_report_csv="$OUTPUT_DIR/${repo_name}_PR_Report.csv"
    {
        echo "GitHub Pull Request Report - Merged PRs Evidence"
        echo "========================================================"
        echo ""
        echo "Repository: $repo"
        echo "Organization: $ORG"
        echo "Report Generated: $TIMESTAMP"
        echo "Date Range: $START_DATE to $END_DATE"
        echo "Branch: $BRANCH"
        echo ""
        echo "Command Executed:"
        echo "$command_used"
        echo ""
        echo "Execution Details:"
        echo "  - Timestamp: $TIMESTAMP"
        echo "  - Total PRs Merged: $total_prs"
        echo "  - Pages Fetched: $pages_fetched"
        echo "  - Pagination Required: $([ "$pages_fetched" -gt 1 ] && echo "Yes" || echo "No")"
        echo ""
        echo "========================================================"
        echo "Pull Request Summary"
        echo "========================================================"
        echo ""
        echo "Note: PRs merged into $BRANCH branch indicate they passed"
        echo "      required review and approval processes per branch protection rules."
        echo ""
        cat "$report_file"
    } > "$final_report_csv"

    # Generate PDF if tool is available
    if [ "$GENERATE_PDF" = true ]; then
        local final_report_pdf="$OUTPUT_DIR/${repo_name}_PR_Report.pdf"
        local temp_md=$(mktemp)

        # Create a header LaTeX file for better formatting
        local header_file=$(mktemp)
        {
            echo "\\usepackage{longtable}"
            echo "\\usepackage{url}"
            echo "\\usepackage{booktabs}"
            echo "\\usepackage{array}"
            echo "\\usepackage{geometry}"
            echo "\\geometry{landscape,margin=0.75in}"
            echo "\\usepackage{fancyvrb}"
            echo "\\DefineVerbatimEnvironment{verbatim}{Verbatim}{fontsize=\\scriptsize,breaklines=true,breakanywhere=true}"
        } > "$header_file"

        # Convert CSV report to Markdown format with better formatting
        {
            echo "# GitHub Pull Request Report - Merged PRs Evidence"
            echo ""
            echo "**Repository:** $repo  "
            echo "**Organization:** $ORG  "
            echo "**Report Generated:** $TIMESTAMP  "
            echo "**Date Range:** $START_DATE to $END_DATE  "
            echo "**Branch:** $BRANCH  "
            echo ""
            echo "## Command Executed"
            echo ""
            echo "\`\`\`"
            # Break long command into multiple lines for better PDF rendering
            echo "$command_used" | fold -w 70 -s
            echo "\`\`\`"
            echo ""
            echo "## Execution Details"
            echo ""
            echo "- **Timestamp:** $TIMESTAMP"
            echo "- **Total PRs Merged:** $total_prs"
            echo "- **Pages Fetched:** $pages_fetched"
            echo "- **Pagination Required:** $([ "$pages_fetched" -gt 1 ] && echo "Yes" || echo "No")"
            echo ""
            echo "\\newpage"
            echo ""
            echo "## Pull Request Summary"
            echo ""
            # Use LaTeX longtable for better multi-page support (landscape allows wider columns)
            echo "\\begin{longtable}{|p{0.6cm}|p{6cm}|p{2.5cm}|p{2cm}|p{2cm}|p{1.2cm}|p{1.2cm}|p{3cm}|}"
            echo "\\hline"
            echo "\\textbf{\\#} & \\textbf{Title} & \\textbf{Branch} & \\textbf{Merged} & \\textbf{Author} & \\textbf{Rev} & \\textbf{App} & \\textbf{URL} \\\\"
            echo "\\hline"
            echo "\\endfirsthead"
            echo "\\hline"
            echo "\\textbf{\\#} & \\textbf{Title} & \\textbf{Branch} & \\textbf{Merged} & \\textbf{Author} & \\textbf{Rev} & \\textbf{App} & \\textbf{URL} \\\\"
            echo "\\hline"
            echo "\\endhead"
            echo "\\hline"
            echo "\\endfoot"
            tail -n +2 "$report_file" | while IFS=$'\t' read -r num title branch merged author url reviewers approvals; do
                # Escape LaTeX special characters - careful with order
                # Replace backslash first, then other specials
                title=$(echo "$title" | sed 's/\\/\\textbackslash{}/g' | sed 's/&/\\&/g' | sed 's/%/\\%/g' | sed 's/\$/\\\$/g' | sed 's/#/\\#/g' | sed 's/\^/\\^{}/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g' | sed 's/_/\\_/g')
                branch=$(echo "$branch" | sed 's/\\/\\textbackslash{}/g' | sed 's/&/\\&/g' | sed 's/%/\\%/g' | sed 's/\$/\\\$/g' | sed 's/#/\\#/g' | sed 's/\^/\\^{}/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g' | sed 's/_/\\_/g')
                author=$(echo "$author" | sed 's/\\/\\textbackslash{}/g' | sed 's/&/\\&/g' | sed 's/%/\\%/g' | sed 's/\$/\\\$/g' | sed 's/#/\\#/g' | sed 's/\^/\\^{}/g' | sed 's/{/\\{/g' | sed 's/}/\\}/g' | sed 's/_/\\_/g')
                # Truncate long titles for better table formatting (landscape allows more space)
                title_short=$(echo "$title" | cut -c1-60)
                if [ ${#title} -gt 60 ]; then
                    title_short="${title_short}..."
                fi
                # Format merged date to be shorter (just date, no time)
                merged_date=$(echo "$merged" | cut -d'T' -f1)
                # URL - escape special chars but keep it simple
                url_safe=$(echo "$url" | sed 's/#/\\#/g' | sed 's/%/\\%/g')
                echo "$num & $title_short & $branch & $merged_date & $author & $reviewers & $approvals & \\url{$url_safe} \\\\"
                echo "\\hline"
            done
            echo "\\end{longtable}"
        } > "$temp_md"

        # Convert to PDF
        PDF_SUCCESS=false
        PDF_ERROR=""

        if [ "$PDF_TOOL" = "pandoc" ] && [ -n "$PDF_ENGINE" ]; then
            # Try with specified engine and LaTeX header file for better table formatting
            PDF_ERROR=$(pandoc "$temp_md" -o "$final_report_pdf" --pdf-engine="$PDF_ENGINE" \
                -H "$header_file" \
                -V geometry:landscape,margin=0.75in \
                -V fontsize=9pt \
                --standalone \
                -f markdown+raw_tex \
                2>&1)
            if [ $? -eq 0 ] && [ -f "$final_report_pdf" ] && [ -s "$final_report_pdf" ]; then
                PDF_SUCCESS=true
            else
                # Try with simpler header (just essential packages)
                {
                    echo "\\usepackage{longtable}"
                    echo "\\usepackage{url}"
                    echo "\\usepackage{geometry}"
                    echo "\\geometry{landscape,margin=0.75in}"
                } > "$header_file"

                PDF_ERROR=$(pandoc "$temp_md" -o "$final_report_pdf" --pdf-engine="$PDF_ENGINE" \
                    -H "$header_file" \
                    -V geometry:landscape,margin=0.75in \
                    -V fontsize=9pt \
                    --standalone \
                    -f markdown+raw_tex \
                    2>&1)
                if [ $? -eq 0 ] && [ -f "$final_report_pdf" ] && [ -s "$final_report_pdf" ]; then
                    PDF_SUCCESS=true
                else
                    # Last resort: try without custom header, use basic markdown table
                    echo "  ⚠ Advanced PDF formatting failed, trying basic format..."
                    # Create simpler markdown without LaTeX tables
                    {
                        echo "# GitHub Pull Request Report - Merged PRs Evidence"
                        echo ""
                        echo "**Repository:** $repo  "
                        echo "**Organization:** $ORG  "
                        echo "**Report Generated:** $TIMESTAMP  "
                        echo "**Date Range:** $START_DATE to $END_DATE  "
                        echo "**Branch:** $BRANCH  "
                        echo ""
                        echo "## Command Executed"
                        echo ""
                        echo "\`\`\`"
                        echo "$command_used" | fold -w 70 -s
                        echo "\`\`\`"
                        echo ""
                        echo "## Execution Details"
                        echo ""
                        echo "- **Timestamp:** $TIMESTAMP"
                        echo "- **Total PRs Merged:** $total_prs"
                        echo "- **Pages Fetched:** $pages_fetched"
                        echo ""
                        echo "## Pull Request Summary"
                        echo ""
                        echo "| # | Title | Branch | Merged | Author | Rev | App | URL |"
                        echo "|---|-------|--------|--------|--------|-----|-----|-----|"
                        tail -n +2 "$report_file" | while IFS=$'\t' read -r num title branch merged author url reviewers approvals; do
                            title_short=$(echo "$title" | cut -c1-40)
                            if [ ${#title} -gt 40 ]; then
                                title_short="${title_short}..."
                            fi
                            merged_date=$(echo "$merged" | cut -d'T' -f1)
                            echo "| $num | $title_short | $branch | $merged_date | $author | $reviewers | $approvals | [Link]($url) |"
                        done
                    } > "$temp_md"

                    PDF_ERROR=$(pandoc "$temp_md" -o "$final_report_pdf" --pdf-engine="$PDF_ENGINE" \
                        -V geometry:landscape,margin=0.75in \
                        -V fontsize=9pt \
                        --standalone \
                        2>&1)
                    if [ $? -eq 0 ] && [ -f "$final_report_pdf" ] && [ -s "$final_report_pdf" ]; then
                        PDF_SUCCESS=true
                        echo "  ✓ Generated PDF with basic formatting"
                    else
                        echo "  ⚠ PDF generation failed"
                        if [ -n "$PDF_ERROR" ]; then
                            echo "     Error details:"
                            echo "$PDF_ERROR" | grep -i "error\|fatal\|!" | head -5 | sed 's/^/       /'
                        fi
                        echo "     CSV report is available: $final_report_csv"
                    fi
                fi
            fi
            rm -f "$header_file"
        elif [ "$PDF_TOOL" = "wkhtmltopdf" ]; then
            # Convert markdown to HTML first, then to PDF
            HTML_ERROR=$(pandoc "$temp_md" -o /tmp/temp.html 2>&1)
            if [ $? -eq 0 ]; then
                PDF_ERROR=$(wkhtmltopdf /tmp/temp.html "$final_report_pdf" 2>&1)
                if [ $? -eq 0 ] && [ -f "$final_report_pdf" ]; then
                    PDF_SUCCESS=true
                else
                    echo "  ⚠ PDF generation failed with wkhtmltopdf"
                    if [ -n "$PDF_ERROR" ]; then
                        echo "     Error: $(echo "$PDF_ERROR" | head -1)"
                    fi
                    echo "     CSV report is available: $final_report_csv"
                fi
            else
                echo "  ⚠ Failed to convert markdown to HTML"
                echo "     CSV report is available: $final_report_csv"
            fi
        elif [ "$PDF_TOOL" = "weasyprint" ]; then
            # Convert markdown to HTML first, then to PDF
            HTML_ERROR=$(pandoc "$temp_md" -o /tmp/temp.html 2>&1)
            if [ $? -eq 0 ]; then
                PDF_ERROR=$(weasyprint /tmp/temp.html "$final_report_pdf" 2>&1)
                if [ $? -eq 0 ] && [ -f "$final_report_pdf" ]; then
                    PDF_SUCCESS=true
                else
                    echo "  ⚠ PDF generation failed with weasyprint"
                    if [ -n "$PDF_ERROR" ]; then
                        echo "     Error: $(echo "$PDF_ERROR" | head -1)"
                    fi
                    echo "     CSV report is available: $final_report_csv"
                fi
            else
                echo "  ⚠ Failed to convert markdown to HTML"
                echo "     CSV report is available: $final_report_csv"
            fi
        fi

        rm -f "$temp_md" /tmp/temp.html "$header_file"

        if [ "$PDF_SUCCESS" = true ] && [ -f "$final_report_pdf" ]; then
            echo "  ✓ Generated PDF: $final_report_pdf"
        fi
    fi

    rm -f "$report_file"

    echo "  ✓ Generated report: $total_prs PRs found across $pages_fetched page(s)"
    echo "    CSV saved to: $final_report_csv"
    if [ "$GENERATE_PDF" = true ] && [ -f "$OUTPUT_DIR/${repo_name}_PR_Report.pdf" ]; then
        echo "    PDF saved to: $OUTPUT_DIR/${repo_name}_PR_Report.pdf"
    fi
    echo ""
}

# Get all repositories in the organization (handle pagination)
echo "Fetching list of repositories from $ORG..."
echo -n "Progress: "

REPOS=""
PAGE=1
PER_PAGE=100

while true; do
    echo -n "."
    PAGE_REPOS=$(gh api "orgs/$ORG/repos?per_page=$PER_PAGE&page=$PAGE&type=all" --jq '.[].full_name' 2>/dev/null)

    if [ -z "$PAGE_REPOS" ] || [ "$(echo "$PAGE_REPOS" | wc -l)" -eq 0 ]; then
        break
    fi

    if [ -z "$REPOS" ]; then
        REPOS="$PAGE_REPOS"
    else
        REPOS=$(echo -e "$REPOS\n$PAGE_REPOS")
    fi

    COUNT=$(echo "$PAGE_REPOS" | wc -l | tr -d ' ')
    if [ "$COUNT" -lt "$PER_PAGE" ]; then
        break
    fi

    PAGE=$((PAGE + 1))
done

echo ""
REPOS=$(echo "$REPOS" | sort)

if [ -z "$REPOS" ]; then
    echo "Error: Could not fetch repositories from $ORG"
    exit 1
fi

REPO_COUNT=$(echo "$REPOS" | wc -l | tr -d ' ')
echo "Found $REPO_COUNT repositories"
echo ""
echo "Processing repositories..."
echo ""

# Process each repository
PROCESSED=0
SKIPPED=0
WITH_PRS=0

while IFS= read -r repo; do
    PROCESSED=$((PROCESSED + 1))
    repo_name=$(basename "$repo")

    # Check if this repo should be skipped
    if should_skip_repo "$repo"; then
        echo "[$PROCESSED/$REPO_COUNT] Skipping: $repo_name (excluded via --skip-repos)"
        echo ""
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "[$PROCESSED/$REPO_COUNT] Processing: $repo_name"
    generate_report "$repo"

    if [ -f "$OUTPUT_DIR/$(basename "$repo")_PR_Report.csv" ]; then
        WITH_PRS=$((WITH_PRS + 1))
    else
        SKIPPED=$((SKIPPED + 1))
    fi
done <<< "$REPOS"

# Generate summary report
SUMMARY_FILE="$OUTPUT_DIR/00_SUMMARY.txt"
{
    echo "GitHub Pull Request Report - Summary"
    echo "==================================="
    echo ""
    echo "Report Generated: $TIMESTAMP"
    echo "Organization: $ORG"
    echo "Date Range Requested: $START_DATE to $END_DATE"
    echo "Branch: $BRANCH"
    echo ""
    echo "Statistics:"
    echo "  - Total Repositories Scanned: $REPO_COUNT"
    echo "  - Repositories with Merged PRs: $WITH_PRS"
    echo "  - Repositories Skipped: $SKIPPED"
    if [ -n "$SKIP_REPOS" ]; then
        echo "    (Excluded via --skip-repos, no $BRANCH branch, or no PRs in date range)"
    else
        echo "    (No $BRANCH branch or no PRs in date range)"
    fi
    echo ""
    echo "Individual Reports:"
    echo "-------------------"
    ls -1 "$OUTPUT_DIR"/*_PR_Report.csv 2>/dev/null | while read -r file; do
        repo_name=$(basename "$file" | sed 's/_PR_Report.csv//')
        pr_count=$(tail -n +20 "$file" | wc -l | tr -d ' ')
        echo "  - $repo_name: $pr_count PRs"
    done
    echo ""
    echo "All reports saved in: $OUTPUT_DIR"
} > "$SUMMARY_FILE"

echo "=========================================="
echo "Report Generation Complete"
echo "=========================================="
echo "Total Repositories: $REPO_COUNT"
echo "With Merged PRs: $WITH_PRS"
echo "Skipped: $SKIPPED"
echo ""
echo "Reports saved in: $OUTPUT_DIR"
echo "Summary: $SUMMARY_FILE"
echo ""
