#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark Automated Compliance Tool (Modular Version)
# Version: 2.0.0
# Description: Comprehensive automated compliance tool for configuring Red Hat
#              Enterprise Linux 9 servers to meet CIS Benchmark standards.
#              Operates entirely offline in air-gapped environments.
#
# Usage: ./rhel9-cis-compliance-modular.sh [OPTIONS]
#
# Options:
#   --dry-run          Report compliance status without making changes
#   --interactive      Prompt for confirmation before each remediation
#   --auto             Apply all remediations without interaction
#   --sections         Select specific sections to remediate (interactive menu)
#   --section=N        Remediate specific section (e.g., --section=1 or --section=1.1)
#   --banner-file=PATH Custom banner text file for warning banners
#   --backup-only      Create backups without applying changes
#   --rollback         Restore from previous backup
#   --report           Generate compliance report only
#   --help             Display this help message
#
# Requirements:
#   - Root privileges
#   - RHEL 9 operating system
#   - Sufficient disk space for backups
#
################################################################################

set -o pipefail

################################################################################
# SCRIPT INITIALIZATION
################################################################################

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions library
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
    source "${SCRIPT_DIR}/lib/common.sh"
else
    echo "ERROR: Cannot find lib/common.sh"
    exit 1
fi

# Source section modules
for section in {1..7}; do
    section_file="${SCRIPT_DIR}/lib/section-${section}.sh"
    if [[ -f "${section_file}" ]]; then
        source "${section_file}"
    else
        log_error "Cannot find ${section_file}"
        exit 1
    fi
done

################################################################################
# MAIN REMEDIATION RUNNER
################################################################################

run_all_remediations() {
    run_section_1
    run_section_2
    run_section_3
    run_section_4
    run_section_5
    run_section_6
    run_section_7
}

################################################################################
# MAIN FUNCTION
################################################################################

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --sections)
                SECTION_SELECT=true
                shift
                ;;
            --section=*)
                SELECTED_SECTIONS+=("${1#*=}")
                shift
                ;;
            --banner-file=*)
                CUSTOM_BANNER_FILE="${1#*=}"
                shift
                ;;
            --backup-only)
                BACKUP_ONLY=true
                shift
                ;;
            --rollback)
                ROLLBACK_MODE=true
                shift
                ;;
            --report)
                REPORT_ONLY=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Print banner
    print_banner
    
    # Perform pre-execution validation
    pre_execution_validation
    
    # Handle rollback mode
    if [[ "${ROLLBACK_MODE}" == true ]]; then
        log_info "Rollback functionality not yet implemented"
        exit 0
    fi
    
    # Handle report-only mode
    if [[ "${REPORT_ONLY}" == true ]]; then
        generate_html_report
        generate_text_report
        log_info "Reports generated successfully"
        exit 0
    fi
    
    # Show section selection menu if requested
    if [[ "${SECTION_SELECT}" == true ]]; then
        show_section_menu
    fi
    
    # Set default mode if none specified
    if [[ "${DRY_RUN}" == false ]] && [[ "${INTERACTIVE}" == false ]] && [[ "${AUTO_MODE}" == false ]]; then
        log_warning "No execution mode specified. Using --dry-run mode by default."
        DRY_RUN=true
    fi
    
    # Display execution mode
    if [[ "${DRY_RUN}" == true ]]; then
        log_info "Running in DRY-RUN mode - no changes will be made"
    elif [[ "${INTERACTIVE}" == true ]]; then
        log_info "Running in INTERACTIVE mode - you will be prompted for each change"
    elif [[ "${AUTO_MODE}" == true ]]; then
        log_warning "Running in AUTOMATED mode - all changes will be applied automatically"
        sleep 3
    fi
    
    # Display selected sections
    if [[ ${#SELECTED_SECTIONS[@]} -gt 0 ]]; then
        log_info "Selected sections: ${SELECTED_SECTIONS[*]}"
    else
        log_info "Running all sections"
    fi
    
    echo
    log_info "Starting CIS Benchmark compliance assessment..."
    echo
    
    # Run all remediations
    run_all_remediations
    
    # Generate reports
    echo
    log_info "Generating compliance reports..."
    generate_html_report
    generate_text_report
    
    # Display summary
    echo
    log_info "================================================================================"
    log_info "COMPLIANCE ASSESSMENT SUMMARY"
    log_info "================================================================================"
    log_info "Total Checks:           ${TOTAL_CHECKS}"
    log_info "Passed Checks:          ${PASSED_CHECKS}"
    log_info "Failed Checks:          ${FAILED_CHECKS}"
    log_info "Remediated Checks:      ${REMEDIATED_CHECKS}"
    log_info "Manual Review Required: ${MANUAL_CHECKS}"
    log_info "================================================================================"
    
    if [[ ${REMEDIATED_CHECKS} -gt 0 ]]; then
        log_info ""
        log_warning "IMPORTANT: ${REMEDIATED_CHECKS} remediations were applied."
        log_warning "A system reboot may be required for some changes to take effect."
        log_warning "Rollback script available at: ${ROLLBACK_SCRIPT}"
    fi
    
    if [[ ${MANUAL_CHECKS} -gt 0 ]]; then
        log_info ""
        log_warning "ATTENTION: ${MANUAL_CHECKS} items require manual intervention."
        log_warning "Please review the log file for details: ${LOG_FILE}"
    fi
    
    log_info ""
    log_info "Reports generated:"
    log_info "  - HTML Report: ${REPORT_FILE}"
    log_info "  - Text Report: ${REPORT_TEXT}"
    log_info "  - Log File:    ${LOG_FILE}"
    log_info ""
    
    log_success "CIS Benchmark compliance assessment completed successfully!"
    
    exit 0
}

# Execute main function
main "$@"

# Made with Bob
