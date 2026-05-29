#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Common Functions Library
# Version: 2.0.0
# Description: Shared functions used across all CIS compliance modules
################################################################################

################################################################################
# GLOBAL VARIABLES
################################################################################

SCRIPT_VERSION="2.0.0"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Directories
BACKUP_DIR="/var/cis-compliance/backups/${TIMESTAMP}"
LOG_DIR="/var/cis-compliance/log"
REPORT_DIR="/var/cis-compliance/reports"
ROLLBACK_DIR="/var/cis-compliance/rollback"

# Files
LOG_FILE="${LOG_DIR}/cis-compliance-${TIMESTAMP}.log"
FAILED_LOG="${LOG_DIR}/failed-checks-${TIMESTAMP}.log"
FAILED_CSV="${LOG_DIR}/failed-checks-${TIMESTAMP}.csv"
MANUAL_LOG="${LOG_DIR}/manual-checks-${TIMESTAMP}.log"
MANUAL_CSV="${LOG_DIR}/manual-checks-${TIMESTAMP}.csv"
REPORT_FILE="${REPORT_DIR}/compliance-report-${TIMESTAMP}.html"
REPORT_TEXT="${REPORT_DIR}/compliance-report-${TIMESTAMP}.txt"
ROLLBACK_SCRIPT="${ROLLBACK_DIR}/rollback-${TIMESTAMP}.sh"
STATE_FILE="${BACKUP_DIR}/state.json"

# Execution modes
DRY_RUN=false
INTERACTIVE=false
AUTO_MODE=false
BACKUP_ONLY=false
ROLLBACK_MODE=false
REPORT_ONLY=false
SECTION_SELECT=false
SELECTED_SECTIONS=()
CUSTOM_BANNER_FILE=""

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
REMEDIATED_CHECKS=0
MANUAL_CHECKS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# LOGGING FUNCTIONS
################################################################################

log_message() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "${LOG_FILE}" 2>/dev/null || true
}

log_info() {
    log_message "INFO" "$@"
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    log_message "SUCCESS" "$@"
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    local message="$*"
    log_message "WARNING" "${message}"
    echo -e "${YELLOW}[WARNING]${NC} ${message}"

    # Auto-detect FAIL messages and log to failed checks log
    if [[ "${message}" =~ ^\[([0-9.]+)\]\ FAIL:\ (.+)$ ]]; then
        local check_id="${BASH_REMATCH[1]}"
        local failure_desc="${BASH_REMATCH[2]}"

        # Extract current and expected values if present
        local current_state="${failure_desc}"
        local expected_state="See CIS Benchmark for expected configuration"
        local reason="Check failed during compliance assessment"
        local remediation="Run with --interactive or --auto mode to remediate"

        # Try to parse "current = X (expected Y)" pattern
        if [[ "${failure_desc}" =~ (.+)\ =\ ([^\(]+)\ \(expected\ (.+)\)$ ]]; then
            local param="${BASH_REMATCH[1]}"
            local current_val="${BASH_REMATCH[2]}"
            local expected_val="${BASH_REMATCH[3]}"
            current_state="${param} = ${current_val}"
            expected_state="${param} = ${expected_val}"
            reason="Parameter ${param} is set to ${current_val} but should be ${expected_val}"
            remediation="Set ${param} to ${expected_val} in the appropriate configuration file"
        fi

        # Log to failed checks file
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        cat >> "${FAILED_LOG}" 2>/dev/null << EOF

================================================================================
CHECK ID: ${check_id}
TIMESTAMP: ${timestamp}
STATUS: FAILED
================================================================================
TITLE: ${failure_desc}

CURRENT STATE:
${current_state}

EXPECTED STATE:
${expected_state}

REASON FOR FAILURE:
${reason}

REMEDIATION GUIDANCE:
${remediation}

================================================================================

EOF
    fi
    # Note: MANUAL message auto-detection removed - use log_check_manual() directly instead
}

log_error() {
    log_message "ERROR" "$@"
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    log_message "DEBUG" "$@"
}

# Enhanced logging function for failed checks with detailed information
log_check_failed() {
    local check_id="$1"
    local check_title="$2"
    local current_state="$3"
    local expected_state="$4"
    local reason="$5"
    local remediation_hint="${6:-Manual remediation required}"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to main log file
    log_warning "[${check_id}] FAIL: ${check_title}"

    # Log detailed information to failed checks log
    cat >> "${FAILED_LOG}" << EOF

================================================================================
CHECK ID: ${check_id}
TIMESTAMP: ${timestamp}
STATUS: FAILED
================================================================================
TITLE: ${check_title}

CURRENT STATE:
${current_state}

EXPECTED STATE:
${expected_state}

REASON FOR FAILURE:
${reason}

REMEDIATION GUIDANCE:
${remediation_hint}

================================================================================

EOF

    # Log to CSV file (escape quotes and newlines for CSV format)
    local csv_check_id=$(echo "${check_id}" | sed 's/"/""/g')
    local csv_title=$(echo "${check_title}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_current=$(echo "${current_state}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_expected=$(echo "${expected_state}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_reason=$(echo "${reason}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_remediation=$(echo "${remediation_hint}" | sed 's/"/""/g' | tr '\n' ' ')
    local section="${check_id%%.*}"

    echo "\"${csv_check_id}\",\"${timestamp}\",\"FAILED\",\"${csv_title}\",\"${csv_current}\",\"${csv_expected}\",\"${csv_reason}\",\"${csv_remediation}\",\"${section}\"" >> "${FAILED_CSV}"
}

# Enhanced logging function for manual checks with detailed guidance
log_check_manual() {
    local check_id="$1"
    local check_title="$2"
    local current_state="$3"
    local required_action="$4"
    local verification_steps="$5"
    local additional_info="${6:-See CIS Benchmark documentation for details}"

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Log to main log file
    log_warning "[${check_id}] MANUAL: ${check_title}"

    # Log detailed information to manual checks log
    cat >> "${MANUAL_LOG}" << EOF

================================================================================
CHECK ID: ${check_id}
TIMESTAMP: ${timestamp}
STATUS: REQUIRES MANUAL REVIEW
================================================================================
TITLE: ${check_title}

CURRENT STATE:
${current_state}

REQUIRED ACTION:
${required_action}

VERIFICATION STEPS:
${verification_steps}

ADDITIONAL INFORMATION:
${additional_info}

REFERENCES:
- CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0
- Section: ${check_id%%.*}
- Control: ${check_id}

================================================================================

EOF

    # Log to CSV file (escape quotes and newlines for CSV format)
    local csv_check_id=$(echo "${check_id}" | sed 's/"/""/g')
    local csv_title=$(echo "${check_title}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_current=$(echo "${current_state}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_action=$(echo "${required_action}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_verification=$(echo "${verification_steps}" | sed 's/"/""/g' | tr '\n' ' ')
    local csv_info=$(echo "${additional_info}" | sed 's/"/""/g' | tr '\n' ' ')
    local section="${check_id%%.*}"

    echo "\"${csv_check_id}\",\"${timestamp}\",\"MANUAL\",\"${csv_title}\",\"${csv_current}\",\"${csv_action}\",\"${csv_verification}\",\"${csv_info}\",\"${section}\"" >> "${MANUAL_CSV}"
}

# Initialize detailed log files with headers
initialize_detailed_logs() {
    # Initialize failed checks log
    cat > "${FAILED_LOG}" << 'EOF'
################################################################################
#                                                                              #
#           RHEL 9 CIS Benchmark - Failed Checks Detailed Report              #
#                                                                              #
################################################################################
#
# This log contains detailed information about all failed compliance checks,
# including current system state, expected configuration, and remediation
# guidance to help troubleshoot and resolve compliance issues.
#
################################################################################

EOF

    # Initialize failed checks CSV
    cat > "${FAILED_CSV}" << 'EOF'
"Check ID","Timestamp","Status","Title","Current State","Expected State","Reason","Remediation Guidance","Section"
EOF

    # Initialize manual checks log
    cat > "${MANUAL_LOG}" << 'EOF'
################################################################################
#                                                                              #
#         RHEL 9 CIS Benchmark - Manual Checks Detailed Report                #
#                                                                              #
################################################################################
#
# This log contains detailed information about all checks that require manual
# review and configuration. Each entry includes the current state, required
# actions, and step-by-step verification procedures.
#
################################################################################

EOF

    # Initialize manual checks CSV
    cat > "${MANUAL_CSV}" << 'EOF'
"Check ID","Timestamp","Status","Title","Current State","Required Action","Verification Steps","Additional Information","Section"
EOF

    log_info "Detailed log files initialized:"
    log_info "  - Failed checks: ${FAILED_LOG}"
    log_info "  - Failed checks CSV: ${FAILED_CSV}"
    log_info "  - Manual checks: ${MANUAL_LOG}"
    log_info "  - Manual checks CSV: ${MANUAL_CSV}"
}

################################################################################
# UTILITY FUNCTIONS
################################################################################

print_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                                                              ║
║           RHEL 9 CIS Benchmark Automated Compliance Tool v2.0.0              ║
║                                                                              ║
║  Comprehensive automated compliance tool for configuring Red Hat Enterprise  ║
║  Linux 9 servers to meet CIS Benchmark standards.                            ║
║                                                                              ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
}

print_usage() {
    cat << EOF

Usage: ${SCRIPT_NAME} [OPTIONS]

Options:
  --dry-run          Report compliance status without making changes
  --interactive      Prompt for confirmation before each remediation
  --auto             Apply all remediations without interaction
  --sections         Select specific sections to remediate (interactive menu)
  --section=N        Remediate specific section (e.g., --section=1 or --section=1.1)
  --banner-file=PATH Custom banner text file for warning banners
  --backup-only      Create a baseline configuration backup without applying changes
  --rollback         Restore from the most recent rollback script
  --report           Generate compliance report only
  --help             Display this help message

Examples:
  ${SCRIPT_NAME} --dry-run              # Check compliance without changes
  ${SCRIPT_NAME} --interactive          # Apply fixes with confirmation
  ${SCRIPT_NAME} --auto                 # Apply all fixes automatically
  ${SCRIPT_NAME} --sections --auto      # Select sections interactively
  ${SCRIPT_NAME} --section=1 --auto     # Apply only Section 1 fixes
  ${SCRIPT_NAME} --section=1.1 --auto   # Apply only Section 1.1 fixes
  ${SCRIPT_NAME} --backup-only          # Create a baseline configuration backup
  ${SCRIPT_NAME} --rollback             # Restore from the most recent rollback script

EOF
}

show_section_menu() {
    clear
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                     CIS BENCHMARK SECTION SELECTOR                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

Select sections to remediate (space-separated numbers, or 'all'):

  SECTION 1: Initial Setup
    1.1  - Filesystem Configuration (35 checks)
    1.2  - Software Updates (5 checks)
    1.3  - Mandatory Access Controls - SELinux (8 checks)
    1.4  - Secure Boot Settings (2 checks)
    1.5  - Additional Process Hardening (4 checks)
    1.6  - Crypto Policy (7 checks)
    1.7  - Warning Banners (6 checks)
    1.8  - GNOME Display Manager (10 checks)

  SECTION 2: Services (39 checks)
  SECTION 3: Network Configuration (18 checks)
  SECTION 4: Firewall Configuration (7 checks)
  SECTION 5: Access, Authentication and Authorization (150 checks)
  SECTION 6: Logging and Auditing (100 checks)
  SECTION 7: System Maintenance (22 checks)

Examples:
  all       - Run all sections
  1         - Run entire Section 1
  1.1       - Run only Section 1.1 (Filesystem Configuration)
  1 2 3     - Run Sections 1, 2, and 3
  1.1 1.7   - Run Sections 1.1 and 1.7

EOF

    read -p "Enter your selection: " selection
    echo

    if [[ "${selection}" == "all" ]]; then
        SELECTED_SECTIONS=("all")
        log_info "Selected: All sections"
    else
        SELECTED_SECTIONS=(${selection})
        log_info "Selected sections: ${SELECTED_SECTIONS[*]}"
    fi
}

should_run_section() {
    local section="$1"

    # If no sections selected or "all" selected, run everything
    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi

    # Check if this section should run
    for selected in "${SELECTED_SECTIONS[@]}"; do
        # Exact match (e.g., "1.1" matches "1.1")
        if [[ "${section}" == "${selected}" ]]; then
            return 0
        fi
        # Parent match (e.g., "1" matches "1.1", "1.2", etc.)
        if [[ "${section}" == ${selected}.* ]]; then
            return 0
        fi
        # Check if selected is a parent of section (e.g., selected="1" and section="1.1")
        if [[ "${section}" =~ ^${selected}\. ]]; then
            return 0
        fi
    done

    return 1
}

confirm_action() {
    local prompt="$1"
    local response

    if [[ "${INTERACTIVE}" == true ]]; then
        read -p "${prompt} (y/n): " -n 1 -r response
        echo
        [[ $response =~ ^[Yy]$ ]]
    else
        return 0
    fi
}

# Special confirmation for critical/disruptive changes that should NEVER be auto-applied
confirm_critical_action() {
    local prompt="$1"
    local warning="$2"
    local response

    # ALWAYS require manual confirmation for critical changes, even in --auto mode
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           ⚠️  CRITICAL CHANGE  ⚠️                            ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "${warning}"
    echo ""
    read -p "${prompt} (yes/no): " -r response
    echo
    [[ "${response}" == "yes" ]]
}

create_directories() {
    log_info "Creating required directories..."

    mkdir -p "${BACKUP_DIR}" "${LOG_DIR}" "${REPORT_DIR}" "${ROLLBACK_DIR}" 2>/dev/null || true

    if [[ $? -eq 0 ]]; then
        log_success "Directories created successfully"
        return 0
    else
        log_error "Failed to create directories"
        return 1
    fi
}

create_backup_only_archive() {
    local archive="${BACKUP_DIR}/baseline-config-${TIMESTAMP}.tar.gz"
    local paths=()
    local path

    for path in /etc /boot/grub2 /boot/loader/entries; do
        if [[ -e "${path}" ]]; then
            paths+=("${path}")
        fi
    done

    if [[ ${#paths[@]} -eq 0 ]]; then
        log_error "No baseline configuration paths found to back up"
        return 1
    fi

    log_info "Creating baseline configuration backup archive..."
    if tar -czpf "${archive}" --ignore-failed-read "${paths[@]}" >> "${LOG_FILE}" 2>&1; then
        log_success "Baseline configuration backup created: ${archive}"
        return 0
    fi

    log_error "Failed to create baseline configuration backup: ${archive}"
    return 1
}

backup_file() {
    local file="$1"
    local backup_path="${BACKUP_DIR}${file}"

    if [[ -e "${backup_path}" ]]; then
        log_debug "Backup already exists, preserving original snapshot: ${file}"
        return 0
    fi

    if [[ -f "${file}" ]]; then
        mkdir -p "$(dirname "${backup_path}")" 2>/dev/null
        cp -p "${file}" "${backup_path}" 2>/dev/null
        log_debug "Backed up: ${file}"

        # Add to rollback script
        echo "mkdir -p '$(dirname "${file}")'" >> "${ROLLBACK_SCRIPT}"
        echo "cp -p '${backup_path}' '${file}'" >> "${ROLLBACK_SCRIPT}"
        return 0
    elif [[ -d "${file}" ]]; then
        mkdir -p "$(dirname "${backup_path}")" 2>/dev/null
        cp -rp "${file}" "${backup_path}" 2>/dev/null
        log_debug "Backed up directory: ${file}"

        # Add to rollback script
        echo "rm -rf '${file}'" >> "${ROLLBACK_SCRIPT}"
        echo "mkdir -p '$(dirname "${file}")'" >> "${ROLLBACK_SCRIPT}"
        echo "cp -a '${backup_path}' '${file}'" >> "${ROLLBACK_SCRIPT}"
        return 0
    else
        mkdir -p "$(dirname "${backup_path}")" 2>/dev/null
        log_debug "File does not exist, recording rollback removal: ${file}"
        echo "rm -rf '${file}'" >> "${ROLLBACK_SCRIPT}"
        return 1
    fi
}

perform_rollback() {
    local rollback_script
    local candidate
    local response

    while IFS= read -r candidate; do
        candidate="${candidate#* }"
        if grep -Eq "^(cp -p|cp -a|rm -rf|mkdir -p) " "${candidate}" 2>/dev/null; then
            rollback_script="${candidate}"
            break
        fi
    done < <(find "${ROLLBACK_DIR}" -maxdepth 1 -type f -name 'rollback-*.sh' -printf '%T@ %p\n' 2>/dev/null | sort -nr)

    if [[ -z "${rollback_script}" ]]; then
        log_error "No rollback script found in ${ROLLBACK_DIR}"
        return 1
    fi

    log_warning "Rollback will execute: ${rollback_script}"

    if [[ "${AUTO_MODE}" != true ]]; then
        read -p "Type 'yes' to continue with rollback: " -r response
        if [[ "${response}" != "yes" ]]; then
            log_info "Rollback cancelled"
            return 0
        fi
    fi

    if bash "${rollback_script}" >> "${LOG_FILE}" 2>&1; then
        log_success "Rollback completed successfully"
        return 0
    fi

    log_error "Rollback failed. Review ${LOG_FILE} for details."
    return 1
}

################################################################################
# VALIDATION FUNCTIONS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log_success "Root privileges confirmed"
}

check_rhel9() {
    if [[ -f /etc/redhat-release ]]; then
        local version=$(grep -oP 'release \K[0-9]+' /etc/redhat-release 2>/dev/null || echo "0")
        if [[ "${version}" == "9" ]]; then
            log_success "RHEL 9 detected"
            return 0
        fi
    fi
    log_error "This script requires Red Hat Enterprise Linux 9"
    exit 1
}

check_disk_space() {
    local required_space=1048576  # 1GB in KB
    local available_space=$(df /var | tail -1 | awk '{print $4}')

    if [[ ${available_space} -lt ${required_space} ]]; then
        log_error "Insufficient disk space in /var (need 1GB, have $(( available_space / 1024 ))MB)"
        exit 1
    fi
    log_success "Sufficient disk space available"
}

pre_execution_validation() {
    log_info "Performing pre-execution validation..."
    check_root
    check_rhel9
    check_disk_space
    create_directories

    # Initialize rollback script
    echo "#!/bin/bash" > "${ROLLBACK_SCRIPT}"
    echo "# Rollback script generated on $(date)" >> "${ROLLBACK_SCRIPT}"
    chmod +x "${ROLLBACK_SCRIPT}"

    # Initialize detailed log files
    initialize_detailed_logs

    log_success "Pre-execution validation completed"
}

################################################################################
# REPORT GENERATION
################################################################################

generate_html_report() {
    local compliance_rate="N/A"
    if [[ ${TOTAL_CHECKS} -gt 0 ]]; then
        compliance_rate="$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))%"
    fi

    cat > "${REPORT_FILE}" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>CIS Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background: #f0f0f0; padding: 15px; margin: 20px 0; }
        .pass { color: green; }
        .fail { color: red; }
        .manual { color: orange; }
    </style>
</head>
<body>
    <h1>RHEL 9 CIS Benchmark Compliance Report</h1>
    <div class="summary">
        <h2>Summary</h2>
        <p>Total Checks: ${TOTAL_CHECKS}</p>
        <p class="pass">Passed: ${PASSED_CHECKS}</p>
        <p class="fail">Failed: ${FAILED_CHECKS}</p>
        <p>Remediated: ${REMEDIATED_CHECKS}</p>
        <p class="manual">Manual Review Required: ${MANUAL_CHECKS}</p>
        <p>Compliance Rate: ${compliance_rate}</p>
    </div>
    <p>Generated: $(date)</p>
    <h2>Detailed Findings</h2>
    <p>Failed checks CSV: ${FAILED_CSV}</p>
    <p>Manual checks CSV: ${MANUAL_CSV}</p>
    <h3>Per-Section Findings</h3>
    <table border="1" cellpadding="4" cellspacing="0">
        <tr><th>Section</th><th>Failed</th><th>Manual</th></tr>
$(
    # build table rows by aggregating sections from failed and manual CSVs
    sections=$( (tail -n +2 "${FAILED_CSV}" 2>/dev/null | cut -d',' -f1 | tr -d '"' | sed 's/\..*$//' ; tail -n +2 "${MANUAL_CSV}" 2>/dev/null | awk -F',' '{gsub(/"/,"",$NF); print $NF}') | sort -u)
    for s in ${sections}; do
        if [[ -z "${s}" ]]; then continue; fi
        failed_count=$(awk -F, -v sec="${s}." 'NR>1{gsub(/"/,"",$1); if(index($1,sec)==1) c++} END{print c+0}' "${FAILED_CSV}")
        manual_count=$(awk -F, -v sec="${s}" 'NR>1{gsub(/"/,"",$NF); if($NF==sec) c++} END{print c+0}' "${MANUAL_CSV}")
        printf "        <tr><td>%s</td><td>%s</td><td>%s</td></tr>\n" "${s}" "${failed_count}" "${manual_count}"
    done
)
    </table>
</body>
</html>
EOF
    log_info "HTML report generated: ${REPORT_FILE}"
}

generate_text_report() {
    local compliance_rate="N/A"
    if [[ ${TOTAL_CHECKS} -gt 0 ]]; then
        compliance_rate="$(( PASSED_CHECKS * 100 / TOTAL_CHECKS ))%"
    fi

    cat > "${REPORT_TEXT}" << EOF
RHEL 9 CIS Benchmark Compliance Report
Generated: $(date)

SUMMARY
=======
Total Checks:           ${TOTAL_CHECKS}
Passed Checks:          ${PASSED_CHECKS}
Failed Checks:          ${FAILED_CHECKS}
Remediated Checks:      ${REMEDIATED_CHECKS}
Manual Review Required: ${MANUAL_CHECKS}

Compliance Rate: ${compliance_rate}
 
DETAILED FINDINGS
=================
Failed checks CSV: ${FAILED_CSV}
Manual checks CSV: ${MANUAL_CSV}

Per-Section Findings:

Section | Failed | Manual
-------------------------
$(
    sections=$( (tail -n +2 "${FAILED_CSV}" 2>/dev/null | cut -d',' -f1 | tr -d '"' | sed 's/\..*$//' ; tail -n +2 "${MANUAL_CSV}" 2>/dev/null | awk -F',' '{gsub(/"/,"",$NF); print $NF}') | sort -u)
    for s in ${sections}; do
        if [[ -z "${s}" ]]; then continue; fi
        failed_count=$(awk -F, -v sec="${s}." 'NR>1{gsub(/"/,"",$1); if(index($1,sec)==1) c++} END{print c+0}' "${FAILED_CSV}")
        manual_count=$(awk -F, -v sec="${s}" 'NR>1{gsub(/"/,"",$NF); if($NF==sec) c++} END{print c+0}' "${MANUAL_CSV}")
        printf "%s | %s | %s\n" "${s}" "${failed_count}" "${manual_count}"
    done
)
EOF
    log_info "Text report generated: ${REPORT_TEXT}"
}
