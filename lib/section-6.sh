#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 6: Logging and Auditing
# Version: 2.0.0
# Description: Implementation of CIS Section 6 controls
################################################################################

################################################################################
# SECTION 6.1: SYSTEM FILE INTEGRITY
################################################################################

# Helper functions for Section 6 automated evaluation
audit_rule_exists() {
    local expected="$1"
    auditctl -l 2>/dev/null | grep -qF -- "$expected"
}

audit_rule_exists_regex() {
    local pattern="$1"
    auditctl -l 2>/dev/null | grep -qE -- "$pattern"
}

journal_conf_value() {
    local key="$1"
    grep -E "^[[:space:]]*${key}[[:space:]]*=" /etc/systemd/journald.conf 2>/dev/null | tail -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/,"", $2); print $2}'
}

auditd_conf_value() {
    local key="$1"
    grep -E "^[[:space:]]*${key}[[:space:]]*=" /etc/audit/auditd.conf 2>/dev/null | tail -n1 | awk -F= '{gsub(/^[[:space:]]+|[[:space:]]+$/,"", $2); print $2}'
}

remediate_aide() {
    if ! should_run_section "6.1"; then
        log_info "Skipping Section 6.1: System File Integrity (not selected)"
        return 0
    fi
    
    log_info "=== Section 6.1: System File Integrity ==="
    
    local control_id="6.1.1"
    log_info "[${control_id}] Ensure AIDE is installed"
    ((TOTAL_CHECKS++))
    
    if rpm -q aide &>/dev/null; then
        log_success "[${control_id}] PASS: AIDE is installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure AIDE is installed" \
            "AIDE package status: $(rpm -q aide 2>&1 || echo 'Not installed')" \
            "AIDE package should be installed" \
            "AIDE (Advanced Intrusion Detection Environment) is not installed on the system" \
            "Install AIDE using: dnf install -y aide"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Install AIDE?"; then
        log_info "Installing AIDE (this may take a moment)..."
        dnf install -y aide &>/dev/null && log_success "[${control_id}] Remediated: AIDE installed" && ((REMEDIATED_CHECKS++))
    fi
    
    control_id="6.1.2"
    log_info "[${control_id}] Ensure filesystem integrity is regularly checked"
    ((TOTAL_CHECKS++))
    
    if ! rpm -q aide &>/dev/null; then
        log_warning "[${control_id}] SKIP: AIDE is not installed"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        if [[ -f /var/lib/aide/aide.db.gz ]]; then
            log_success "[${control_id}] PASS: AIDE database exists"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: AIDE database missing"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Initialize AIDE database and schedule checks?"; then
        if [[ ! -f /var/lib/aide/aide.db.gz ]]; then
            log_info "Initializing AIDE database (this may take several minutes)..."
            aide --init &>/dev/null && mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz 2>/dev/null
        fi
        
        cat > /etc/systemd/system/aidecheck.service << 'EOF'
[Unit]
Description=AIDE Integrity Check

[Service]
Type=oneshot
ExecStart=/usr/sbin/aide --check
EOF
        
        cat > /etc/systemd/system/aidecheck.timer << 'EOF'
[Unit]
Description=AIDE Integrity Check Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
        
        systemctl daemon-reload 2>/dev/null
        systemctl enable aidecheck.timer 2>/dev/null
        systemctl start aidecheck.timer 2>/dev/null
        
        log_success "[${control_id}] Remediated: AIDE configured and scheduled"
        ((REMEDIATED_CHECKS++))
    fi

    control_id="6.1.3"
    log_info "[${control_id}] Ensure cryptographic mechanisms are used to protect the integrity of audit tools"
    ((TOTAL_CHECKS++))

    if ! rpm -q aide &>/dev/null; then
        log_warning "[${control_id}] SKIP: AIDE is not installed"
    else
        local AIDE_CONF="/etc/aide.conf"
        if [[ ! -f "${AIDE_CONF}" ]]; then
            log_check_failed "${control_id}" \
                "Ensure cryptographic mechanisms are used to protect the integrity of audit tools" \
                "AIDE configuration not found: ${AIDE_CONF}" \
                "Configure AIDE with audit tool integrity rules and cryptographic hashes" \
                "AIDE is installed but its configuration file is missing or not accessible" \
                "Create or restore ${AIDE_CONF} and configure AIDE to monitor audit tool files with SHA512 checksums"
            ((FAILED_CHECKS++))
        else
            local audit_tools=(auditctl auditd ausearch aureport autrace augenrules)
            local missing_tools=()
            for tool in "${audit_tools[@]}"; do
                if ! grep -q -E "(^|/)${tool}(\b|$)" "${AIDE_CONF}" 2>/dev/null; then
                    missing_tools+=("${tool}")
                fi
            done
            local sha_check=false
            if grep -qi 'sha512' "${AIDE_CONF}" 2>/dev/null; then
                sha_check=true
            fi

            if [[ ${#missing_tools[@]} -eq 0 && "${sha_check}" == true ]]; then
                log_success "[${control_id}] PASS: audit tools are protected with cryptographic mechanisms"
                ((PASSED_CHECKS++))
            else
                local current_state="AIDE config: $(grep -nE '(^|/)(auditctl|auditd|ausearch|aureport|autrace|augenrules)(\b|$)' \"${AIDE_CONF}\" 2>/dev/null || echo 'No audit tool paths found')"
                if [[ "${sha_check}" != true ]]; then
                    current_state+="; SHA512 not found in config"
                fi
                log_check_failed "${control_id}" \
                    "Ensure cryptographic mechanisms are used to protect the integrity of audit tools" \
                    "${current_state}" \
                    "AIDE config must include audit tool file entries and SHA512 cryptographic protection" \
                    "AIDE is not configured to protect audit tools using cryptographic hashes" \
                    "Update ${AIDE_CONF} to include audit tool paths and the required SHA512 hash options"
                ((FAILED_CHECKS++))
            fi
        fi
    fi
}

################################################################################
# SECTION 6.2: SYSTEM LOGGING
################################################################################

remediate_system_logging() {
    if ! should_run_section "6.2"; then
        log_info "Skipping Section 6.2: System Logging (not selected)"
        return 0
    fi
    
    log_info "=== Section 6.2: System Logging ==="
    
    # 6.2.1.1 - Ensure journald service is enabled and active
    local control_id="6.2.1.1"
    log_info "[${control_id}] Ensure journald service is enabled and active"
    ((TOTAL_CHECKS++))
    
    if systemctl is-enabled systemd-journald.service &>/dev/null && systemctl is-active systemd-journald.service &>/dev/null; then
        log_success "[${control_id}] PASS: systemd-journald is enabled and active"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        local enabled_status=$(systemctl is-enabled systemd-journald.service 2>&1 || echo "disabled")
        local active_status=$(systemctl is-active systemd-journald.service 2>&1 || echo "inactive")
        log_check_failed "${control_id}" \
            "Ensure journald service is enabled and active" \
            "Enabled: ${enabled_status}, Active: ${active_status}" \
            "Enabled: enabled, Active: active" \
            "systemd-journald service is not properly configured" \
            "Enable and start the service using: systemctl enable --now systemd-journald.service"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Enable and start systemd-journald?"; then
        systemctl unmask systemd-journald.service 2>/dev/null
        systemctl enable systemd-journald.service 2>/dev/null
        systemctl start systemd-journald.service 2>/dev/null
        log_success "[${control_id}] Remediated: systemd-journald enabled and started"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 6.2.1.2 - Ensure journald log file access is configured (Manual)
    control_id="6.2.1.2"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure journald log file access is configured" \
        "Current permissions: $(ls -ld /var/log/journal 2>/dev/null || echo 'Directory not found')" \
        "Configure appropriate permissions on /var/log/journal directory" \
        "1. Check current permissions: ls -ld /var/log/journal
2. Set ownership: chown root:systemd-journal /var/log/journal
3. Set permissions: chmod 2755 /var/log/journal
4. Verify: ls -ld /var/log/journal" \
        "Proper log file access controls prevent unauthorized viewing or modification of system logs"
    ((MANUAL_CHECKS++))
    
    # 6.2.1.3 - Ensure journald log file rotation is configured (Manual)
    control_id="6.2.1.3"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure journald log file rotation is configured" \
        "Current settings: $(grep -E 'SystemMaxUse|SystemKeepFree|RuntimeMaxUse|RuntimeKeepFree' /etc/systemd/journald.conf 2>/dev/null || echo 'Using defaults')" \
        "Configure log rotation in /etc/systemd/journald.conf" \
        "1. Edit /etc/systemd/journald.conf
2. Set SystemMaxUse (e.g., SystemMaxUse=1G)
3. Set SystemKeepFree (e.g., SystemKeepFree=500M)
4. Restart journald: systemctl restart systemd-journald
5. Verify: journalctl --disk-usage" \
        "Log rotation prevents disk space exhaustion and maintains system stability"
    ((MANUAL_CHECKS++))
    
    # 6.2.1.4 - Ensure only one logging system is in use (Automated)
    control_id="6.2.1.4"
    log_info "[${control_id}] Ensure only one logging system is in use"
    ((TOTAL_CHECKS++))

    if systemctl is-active --quiet rsyslog.service; then
        log_success "[${control_id}] PASS: rsyslog is active as the primary logging system"
        ((PASSED_CHECKS++))
    elif systemctl is-active --quiet systemd-journald.service; then
        log_success "[${control_id}] PASS: systemd-journald is active as the primary logging system"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure only one logging system is in use" \
            "Active logging services: rsyslog=$(systemctl is-active rsyslog.service 2>/dev/null || echo 'inactive'), systemd-journald=$(systemctl is-active systemd-journald.service 2>/dev/null || echo 'inactive')" \
            "Either rsyslog or systemd-journald must be active as the single logging system" \
            "No supported local logging service is active" \
            "Enable and configure exactly one logging system: systemd-journald OR rsyslog" \
            "/usr/bin/systemctl is-active rsyslog.service /usr/bin/systemctl is-active systemd-journald.service"
        ((FAILED_CHECKS++))
    fi

    # 6.2.2.1.x - Configure journald remote
    for i in {1..4}; do
        control_id="6.2.2.1.${i}"
        ((TOTAL_CHECKS++))
        case ${i} in
            1)
                if rpm -q systemd-journal-remote &>/dev/null; then
                    log_success "[${control_id}] PASS: systemd-journal-remote is installed"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure systemd-journal-remote is installed" \
                        "systemd-journal-remote package is not installed" \
                        "Install systemd-journal-remote if remote journal collection is required" \
                        "systemd-journal-remote is required for receiving remote journal logs" \
                        "Install package: dnf install -y systemd-journal-remote"
                    ((FAILED_CHECKS++))
                fi
                ;;
            2)
                log_check_manual "${control_id}" \
                    "Ensure systemd-journal-upload authentication is configured" \
                    "Current setting: $(grep -E '^\s*Server=.*' /etc/systemd/journal-upload.conf 2>/dev/null || echo 'Check authentication settings manually')" \
                    "Configure authentication in /etc/systemd/journal-upload.conf" \
                    "1. Review CIS Benchmark Section ${control_id}
2. Configure journal-upload authentication
3. Restart: systemctl restart systemd-journal-upload
4. Verify: journal-upload can authenticate to remote server" \
                    "Remote journal upload authentication is an organization-specific requirement"
                ((MANUAL_CHECKS++))
                ;;
            3)
                if systemctl is-enabled --quiet systemd-journal-upload.service && systemctl is-active --quiet systemd-journal-upload.service; then
                    log_success "[${control_id}] PASS: systemd-journal-upload is enabled and active"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure systemd-journal-upload is enabled and active" \
                        "systemd-journal-upload is not enabled or active" \
                        "Enable and start systemd-journal-upload.service" \
                        "systemd-journal-upload must be running to send remote journal logs" \
                        "Enable: systemctl enable systemd-journal-upload.service; Start: systemctl start systemd-journal-upload.service"
                    ((FAILED_CHECKS++))
                fi
                ;;
            4)
                if ! systemctl is-active --quiet systemd-journal-remote.service && ! systemctl is-enabled --quiet systemd-journal-remote.service; then
                    log_success "[${control_id}] PASS: systemd-journal-remote is not in use"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure systemd-journal-remote service is not in use" \
                        "systemd-journal-remote service is enabled or active" \
                        "Disable systemd-journal-remote.service if not used" \
                        "Remote journal receiving is not desired for this configuration" \
                        "Disable: systemctl disable --now systemd-journal-remote.service"
                    ((FAILED_CHECKS++))
                fi
                ;;
        esac
    done
    
    # 6.2.2.2 - Ensure journald ForwardToSyslog is disabled
    control_id="6.2.2.2"
    ((TOTAL_CHECKS++))
    local forward_to_syslog="$(journal_conf_value ForwardToSyslog)"
    if [[ "${forward_to_syslog,,}" == "no" ]]; then
        log_success "[${control_id}] PASS: ForwardToSyslog is disabled"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure journald ForwardToSyslog is disabled" \
            "Current setting: ${forward_to_syslog:-Not explicitly set}" \
            "ForwardToSyslog=no in /etc/systemd/journald.conf" \
            "ForwardToSyslog should be disabled when using journald as the local logging system" \
            "Edit /etc/systemd/journald.conf and set ForwardToSyslog=no"
        ((FAILED_CHECKS++))
    fi
    
    # 6.2.2.3 - Ensure journald Compress is configured
    control_id="6.2.2.3"
    ((TOTAL_CHECKS++))
    local compress_setting="$(journal_conf_value Compress)"
    if [[ -z "${compress_setting}" || "${compress_setting,,}" == "yes" ]]; then
        log_success "[${control_id}] PASS: Compress is configured"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure journald Compress is configured" \
            "Current setting: ${compress_setting:-Using default (yes)}" \
            "Compress=yes in /etc/systemd/journald.conf" \
            "Journald log compression should be enabled" \
            "Edit /etc/systemd/journald.conf and set Compress=yes"
        ((FAILED_CHECKS++))
    fi
    
    # 6.2.2.4 - Ensure journald Storage is configured
    control_id="6.2.2.4"
    ((TOTAL_CHECKS++))
    local storage_setting="$(journal_conf_value Storage)"
    if [[ "${storage_setting,,}" == "persistent" ]]; then
        log_success "[${control_id}] PASS: Storage is configured as persistent"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure journald Storage is configured" \
            "Current setting: ${storage_setting:-Using default (auto)}" \
            "Storage=persistent in /etc/systemd/journald.conf" \
            "Persistent storage is required to retain logs across reboots" \
            "Edit /etc/systemd/journald.conf and set Storage=persistent"
        ((FAILED_CHECKS++))
    fi
    
    # 6.2.3.x - Configure rsyslog
    for i in {1..8}; do
        control_id="6.2.3.${i}"
        ((TOTAL_CHECKS++))
        case ${i} in
            1)
                if rpm -q rsyslog &>/dev/null; then
                    log_success "[${control_id}] PASS: rsyslog is installed"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure rsyslog is installed" \
                        "rsyslog package is not installed" \
                        "Install rsyslog if local or remote syslog processing is required" \
                        "rsyslog is the syslog daemon used for centralized logging" \
                        "Install package: dnf install -y rsyslog"
                    ((FAILED_CHECKS++))
                fi
                ;;
            2)
                if systemctl is-enabled --quiet rsyslog.service && systemctl is-active --quiet rsyslog.service; then
                    log_success "[${control_id}] PASS: rsyslog service is enabled and active"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure rsyslog service is enabled and active" \
                        "rsyslog service is not enabled or active" \
                        "Enable and start the rsyslog service" \
                        "rsyslog must be running for local syslog processing" \
                        "Enable: systemctl enable --now rsyslog.service"
                    ((FAILED_CHECKS++))
                fi
                ;;
            3)
                local forward_setting="$(journal_conf_value ForwardToSyslog)"
                if [[ "${forward_setting,,}" == "yes" ]]; then
                    log_success "[${control_id}] PASS: journald forwards logs to rsyslog"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure journald is configured to send logs to rsyslog" \
                        "Current ForwardToSyslog setting: ${forward_setting:-Not explicitly set}" \
                        "ForwardToSyslog=yes in /etc/systemd/journald.conf" \
                        "journald should forward logs to rsyslog when rsyslog is the local logging system" \
                        "Edit /etc/systemd/journald.conf and set ForwardToSyslog=yes"
                    ((FAILED_CHECKS++))
                fi
                ;;
            4)
                if grep -qE '^[[:space:]]*FileCreateMode[[:space:]]*=' /etc/rsyslog.conf 2>/dev/null || grep -qrE '^[[:space:]]*FileCreateMode[[:space:]]*=' /etc/rsyslog.d/ 2>/dev/null; then
                    log_success "[${control_id}] PASS: rsyslog file creation mode is configured"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure rsyslog log file creation mode is configured" \
                        "FileCreateMode is not configured in rsyslog configuration" \
                        "Configure FileCreateMode in /etc/rsyslog.conf or /etc/rsyslog.d/*.conf" \
                        "rsyslog log file creation mode should be restricted to appropriate permissions" \
                        "Add a FileCreateMode directive to rsyslog configuration"
                    ((FAILED_CHECKS++))
                fi
                ;;
            5)
                log_check_manual "${control_id}" \
                    "Ensure rsyslog logging is configured" \
                    "Check rsyslog configuration in /etc/rsyslog.conf and /etc/rsyslog.d/" \
                    "Configure rsyslog logging rules per organizational requirements" \
                    "1. Review CIS Benchmark Section ${control_id}
2. Edit /etc/rsyslog.conf or /etc/rsyslog.d/*.conf
3. Restart: systemctl restart rsyslog
4. Verify rsyslog accepts and writes logs as expected" \
                    "rsyslog logging setup depends on organizational policy"
                ((MANUAL_CHECKS++))
                ;;
            6)
                log_check_manual "${control_id}" \
                    "Ensure rsyslog is configured to send logs to a remote log host" \
                    "Check /etc/rsyslog.conf and /etc/rsyslog.d/ for remote host configuration" \
                    "Configure rsyslog forwarding per organizational requirements" \
                    "1. Review CIS Benchmark Section ${control_id}
2. Add remote host forwarding directives to rsyslog config
3. Restart: systemctl restart rsyslog
4. Verify remote host is receiving logs" \
                    "Remote log host configuration varies by environment"
                ((MANUAL_CHECKS++))
                ;;
            7)
                if grep -qE '^[[:space:]]*(module\(load\s*=\s*"imudp"\)|module\(load\s*=\s*"imtcp"\)|\$ModLoad\s+imudp|\$ModLoad\s+imtcp)' /etc/rsyslog.conf 2>/dev/null || grep -qrE '^[[:space:]]*(module\(load\s*=\s*"imudp"\)|module\(load\s*=\s*"imtcp"\)|\$ModLoad\s+imudp|\$ModLoad\s+imtcp)' /etc/rsyslog.d/ 2>/dev/null; then
                    log_check_failed "${control_id}" \
                        "Ensure rsyslog is not configured to receive logs from a remote client" \
                        "rsyslog is configured to receive remote log input" \
                        "Remove or disable remote log receiving modules" \
                        "The host should not accept remote logs unless explicitly required" \
                        "Disable imudp/imtcp modules in rsyslog configuration"
                    ((FAILED_CHECKS++))
                else
                    log_success "[${control_id}] PASS: rsyslog is not configured to receive remote logs"
                    ((PASSED_CHECKS++))
                fi
                ;;
            8)
                log_check_manual "${control_id}" \
                    "Ensure rsyslog logrotate is configured" \
                    "Check /etc/logrotate.d/rsyslog or related logrotate configuration" \
                    "Configure rsyslog logrotate rules per site policy" \
                    "1. Review CIS Benchmark Section ${control_id}
2. Configure /etc/logrotate.d/rsyslog
3. Verify log files are rotated properly" \
                    "Log rotation configuration depends on logging retention policies"
                ((MANUAL_CHECKS++))
                ;;
        esac
    done
    
    # 6.2.4.1 - Ensure access to all logfiles has been configured (Automated)
    control_id="6.2.4.1"
    log_info "[${control_id}] Ensure access to all logfiles has been configured"
    ((TOTAL_CHECKS++))

    local failed_entries=()
    local audit_files=()
    while IFS= read -r -d '' logfile; do
        audit_files+=("${logfile}")
    done < <(find /var/log -type f -print0 2>/dev/null)

    if [[ ${#audit_files[@]} -eq 0 ]]; then
        log_check_failed "${control_id}" \
            "Ensure access to all logfiles has been configured" \
            "No log files found under /var/log" \
            "Log files under /var/log must have restrictive ownership and permissions" \
            "The /var/log directory does not contain any regular log files or is inaccessible" \
            "Verify /var/log exists and contains log files with appropriate permissions"
        ((FAILED_CHECKS++))
    else
        for logfile in "${audit_files[@]}"; do
            local base=$(basename "${logfile}")
            local mode owner group
            read -r mode owner group < <(stat -Lc '%a %U %G' "${logfile}" 2>/dev/null)
            local maxperm
            local allowed_users
            local allowed_groups
            if [[ "${base}" =~ ^(lastlog|lastlog\..*|wtmp|wtmp\..*|btmp|btmp\..*)$ ]]; then
                maxperm=664
                allowed_users='root'
                allowed_groups='root'
            elif [[ "${base}" =~ ^(gdm|gdm3|SSSD).* ]]; then
                maxperm=660
                allowed_users='root|SSSD'
                allowed_groups='root|SSSD|gdm|gdm3'
            else
                maxperm=640
                allowed_users='root|syslog'
                allowed_groups='root|adm'
            fi

            if (( 10#${mode} > 10#${maxperm} )); then
                failed_entries+=("${logfile}: mode ${mode} is more permissive than ${maxperm}")
            fi
            if ! [[ "${owner}" =~ ^(${allowed_users})$ ]]; then
                failed_entries+=("${logfile}: owner ${owner} is not one of ${allowed_users}")
            fi
            if ! [[ "${group}" =~ ^(${allowed_groups})$ ]]; then
                failed_entries+=("${logfile}: group ${group} is not one of ${allowed_groups}")
            fi
        done

        if [[ ${#failed_entries[@]} -eq 0 ]]; then
            log_success "[${control_id}] PASS: /var/log file permissions and ownership are compliant"
            ((PASSED_CHECKS++))
        else
            local current_state="$(printf '%s
' "${failed_entries[@]}" | head -20)"
            log_check_failed "${control_id}" \
                "Ensure access to all logfiles has been configured" \
                "Non-compliant log files found:\n${current_state}" \
                "Log files under /var/log must have appropriate ownership and permissions per CIS guidance" \
                "Some /var/log files do not meet CIS ownership or permission requirements" \
                "Review /var/log file permissions and ownership, and correct them to match CIS 6.2.4.1 rules"
            ((FAILED_CHECKS++))
        fi
    fi
}

################################################################################
# SECTION 6.3: SYSTEM AUDITING
################################################################################

remediate_auditd() {
    if ! should_run_section "6.3"; then
        log_info "Skipping Section 6.3: System Auditing (not selected)"
        return 0
    fi
    
    log_info "=== Section 6.3: System Auditing ==="
    
    # 6.3.1.1 - Ensure auditd packages are installed
    local control_id="6.3.1.1"
    log_info "[${control_id}] Ensure auditd packages are installed"
    ((TOTAL_CHECKS++))
    
    if rpm -q audit audit-libs &>/dev/null; then
        log_success "[${control_id}] PASS: auditd packages are installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure auditd packages are installed" \
            "Package status: $(rpm -q audit audit-libs 2>&1 || echo 'Not installed')" \
            "Packages audit and audit-libs should be installed" \
            "Required auditd packages are not installed on the system" \
            "Install packages using: dnf install -y audit audit-libs"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Install auditd packages?"; then
        if dnf install -y audit audit-libs &>/dev/null; then
            log_success "[${control_id}] Remediated: auditd packages installed"
            ((REMEDIATED_CHECKS++))
        else
            log_error "[${control_id}] Failed to install auditd packages"
            ((FAILED_CHECKS++))
        fi
    fi
    
    # 6.3.1.2 - Ensure auditing for processes that start prior to auditd is enabled
    control_id="6.3.1.2"
    ((TOTAL_CHECKS++))
    if grep -q -E '(^|[[:space:]])audit=1($|[[:space:]])' /proc/cmdline 2>/dev/null; then
        log_success "[${control_id}] PASS: audit=1 is present in the kernel command line"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure auditing for processes that start prior to auditd is enabled" \
            "Current kernel command line: $(cat /proc/cmdline 2>/dev/null || echo 'Unavailable')" \
            "Add audit=1 to GRUB_CMDLINE_LINUX in /etc/default/grub and regenerate GRUB config" \
            "Early boot auditing captures events before auditd starts" \
            "Edit /etc/default/grub, regenerate GRUB config, and reboot to apply audit=1"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.1.3 - Ensure audit_backlog_limit is sufficient
    control_id="6.3.1.3"
    ((TOTAL_CHECKS++))
    local backlog_limit="$(grep -oE 'audit_backlog_limit=[0-9]+' /proc/cmdline 2>/dev/null | cut -d= -f2 | tail -n1 || true)"
    if [[ -n "${backlog_limit}" && ${backlog_limit} -ge 8192 ]]; then
        log_success "[${control_id}] PASS: audit_backlog_limit=${backlog_limit} is configured"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure audit_backlog_limit is sufficient" \
            "Current kernel command line: $(cat /proc/cmdline 2>/dev/null || echo 'Unavailable')" \
            "Add audit_backlog_limit=8192 to GRUB_CMDLINE_LINUX in /etc/default/grub" \
            "Sufficient backlog prevents audit event loss during high activity" \
            "Edit /etc/default/grub, regenerate GRUB config, and reboot to apply audit_backlog_limit=8192"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.1.4 - Ensure auditd service is enabled and active
    control_id="6.3.1.4"
    ((TOTAL_CHECKS++))
    if systemctl is-enabled --quiet auditd.service && systemctl is-active --quiet auditd.service; then
        log_success "[${control_id}] PASS: auditd service is enabled and active"
        ((PASSED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure auditd service is enabled and active" \
            "Status: $(systemctl is-enabled auditd 2>&1), $(systemctl is-active auditd 2>&1)" \
            "auditd should be enabled and active" \
            "Active auditd service is required for system auditing" \
            "Enable and start auditd using: systemctl enable --now auditd.service"
        ((FAILED_CHECKS++))
    fi
    
    # Section 6.3.2: Configure Data Retention (checks 1-4)
    local retention_checks=(
        "Ensure audit log storage size is configured|Edit /etc/audit/auditd.conf and set max_log_file|max_log_file should be set based on site policy"
        "Ensure audit logs are not automatically deleted|Edit /etc/audit/auditd.conf and set max_log_file_action=keep_logs|Prevents automatic deletion of audit logs"
        "Ensure system is disabled when audit logs are full|Edit /etc/audit/auditd.conf: space_left_action=email, admin_space_left_action=halt|System halts when audit storage is full"
        "Ensure system warns when audit logs are low on space|Edit /etc/audit/auditd.conf: space_left and action_mail_acct|Alerts administrators before disk fills"
    )
    
    for i in {1..4}; do
        control_id="6.3.2.${i}"
        ((TOTAL_CHECKS++))
        case ${i} in
            1)
                local max_log_file="$(auditd_conf_value max_log_file)"
                if [[ -n "${max_log_file}" && ${max_log_file} -gt 0 ]]; then
                    log_success "[${control_id}] PASS: max_log_file=${max_log_file} is configured"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure audit log storage size is configured" \
                        "Current max_log_file setting: ${max_log_file:-Not configured}" \
                        "Configure max_log_file in /etc/audit/auditd.conf" \
                        "Audit log storage size must be explicitly configured" \
                        "Set max_log_file in /etc/audit/auditd.conf according to site policy"
                    ((FAILED_CHECKS++))
                fi
                ;;
            2)
                local max_log_file_action="$(auditd_conf_value max_log_file_action)"
                if [[ "${max_log_file_action,,}" == "keep_logs" ]]; then
                    log_success "[${control_id}] PASS: max_log_file_action=keep_logs is configured"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure audit logs are not automatically deleted" \
                        "Current max_log_file_action setting: ${max_log_file_action:-Not configured}" \
                        "Set max_log_file_action=keep_logs in /etc/audit/auditd.conf" \
                        "Audit logs should not be deleted automatically" \
                        "Update /etc/audit/auditd.conf and restart auditd"
                    ((FAILED_CHECKS++))
                fi
                ;;
            3)
                local space_left_action="$(auditd_conf_value space_left_action)"
                local admin_space_left_action="$(auditd_conf_value admin_space_left_action)"
                if [[ "${space_left_action,,}" == "email" && "${admin_space_left_action,,}" == "halt" ]]; then
                    log_success "[${control_id}] PASS: space_left_action=email and admin_space_left_action=halt are configured"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure system is disabled when audit logs are full" \
                        "Current settings: space_left_action=${space_left_action:-Not configured}, admin_space_left_action=${admin_space_left_action:-Not configured}" \
                        "Set space_left_action=email and admin_space_left_action=halt in /etc/audit/auditd.conf" \
                        "The system must halt when audit logs are full" \
                        "Update /etc/audit/auditd.conf and restart auditd"
                    ((FAILED_CHECKS++))
                fi
                ;;
            4)
                local space_left="$(auditd_conf_value space_left)"
                local action_mail_acct="$(auditd_conf_value action_mail_acct)"
                if [[ -n "${space_left}" && -n "${action_mail_acct}" ]]; then
                    log_success "[${control_id}] PASS: space_left and action_mail_acct are configured"
                    ((PASSED_CHECKS++))
                else
                    log_check_failed "${control_id}" \
                        "Ensure system warns when audit logs are low on space" \
                        "Current settings: space_left=${space_left:-Not configured}, action_mail_acct=${action_mail_acct:-Not configured}" \
                        "Set space_left and action_mail_acct in /etc/audit/auditd.conf" \
                        "Audit log space warnings must be configured" \
                        "Update /etc/audit/auditd.conf and restart auditd"
                    ((FAILED_CHECKS++))
                fi
                ;;
        esac
    done
    
    # Section 6.3.3: Configure auditd Rules (checks 1-21)
    # These rules are implemented but flagged for manual review
    
    # Detect system architecture
    local ARCH=""
    if [[ $(uname -m) == "x86_64" ]]; then
        ARCH="b64"
    fi
    
    # 6.3.3.1 - Ensure changes to system administration scope (sudoers) is collected
    control_id="6.3.3.1"
    log_info "[${control_id}] Ensure changes to system administration scope (sudoers) is collected"
    ((TOTAL_CHECKS++))

    if audit_rule_exists "-w /etc/sudoers -p wa -k scope" && audit_rule_exists "-w /etc/sudoers.d -p wa -k scope"; then
        log_success "[${control_id}] PASS: sudoers monitoring audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure changes to system administration scope (sudoers) is collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep -E '/etc/sudoers|/etc/sudoers.d' || echo 'No rules found')" \
            "Monitor changes to sudoers files" \
            "Verify audit rules are configured to monitor /etc/sudoers and /etc/sudoers.d/" \
            "Tracks changes to sudo configuration" \
            "Add audit watch rules for /etc/sudoers and /etc/sudoers.d/"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure sudoers monitoring audit rules?"; then
        backup_file "/etc/audit/rules.d/50-scope.rules"
        cat > /etc/audit/rules.d/50-scope.rules << 'EOF'
## CIS 6.3.3.1 - Monitor changes to system administration scope
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d -p wa -k scope
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Sudoers monitoring configured (verify with: auditctl -l)"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure changes to system administration scope (sudoers) is collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep -E '/etc/sudoers|/etc/sudoers.d' || echo 'No rules found')" \
            "Monitor changes to sudoers files" \
            "Verify audit rules are configured to monitor /etc/sudoers and /etc/sudoers.d/" \
            "Tracks changes to sudo configuration" \
            "Add audit watch rules for /etc/sudoers and /etc/sudoers.d/"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.2 - Ensure actions as another user are always logged
    control_id="6.3.3.2"
    log_info "[${control_id}] Ensure actions as another user are always logged"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex 'uid!=euid.*-k user_emulation'; then
        log_success "[${control_id}] PASS: user impersonation audit rule is loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure actions as another user are always logged" \
            "Current rules: $(auditctl -l 2>/dev/null | grep execve || echo 'No rules found')" \
            "Monitor execve syscalls where uid != euid" \
            "Verify audit rules track user impersonation attempts" \
            "Detects when users execute commands as another user" \
            "Add audit rules for execve with uid!=euid and euid=0"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure user impersonation monitoring?"; then
        backup_file "/etc/audit/rules.d/50-user_emulation.rules"
        cat > /etc/audit/rules.d/50-user_emulation.rules << EOF
## CIS 6.3.3.2 - Monitor actions as another user
-a always,exit -F arch=b32 -S execve -C uid!=euid -F euid=0 -k user_emulation
${ARCH:+-a always,exit -F arch=b64 -S execve -C uid!=euid -F euid=0 -k user_emulation}
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: User impersonation monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure actions as another user are always logged" \
            "Current rules: $(auditctl -l 2>/dev/null | grep execve || echo 'No rules found')" \
            "Monitor execve syscalls where uid != euid" \
            "Verify audit rules track user impersonation attempts" \
            "Detects when users execute commands as another user" \
            "Add audit rules for execve with uid!=euid and euid=0"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.3 - Ensure events that modify the sudo log file are collected
    control_id="6.3.3.3"
    log_info "[${control_id}] Ensure events that modify the sudo log file are collected"
    ((TOTAL_CHECKS++))
    
    local SUDO_LOG_FILE=$(grep -r logfile /etc/sudoers* 2>/dev/null | awk '{print $NF}' | tr -d '"' | head -1)
    SUDO_LOG_FILE=${SUDO_LOG_FILE:-/var/log/sudo.log}
    if audit_rule_exists "-w ${SUDO_LOG_FILE} -p wa -k sudo_log_file"; then
        log_success "[${control_id}] PASS: sudo log file audit rule is loaded for ${SUDO_LOG_FILE}"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure events that modify the sudo log file are collected" \
            "Sudo log location: ${SUDO_LOG_FILE}" \
            "Monitor sudo log file for modifications" \
            "Configure audit rules for the sudo log file location" \
            "Tracks modifications to sudo command logs" \
            "Add an audit watch for ${SUDO_LOG_FILE}"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure sudo log monitoring?"; then
        backup_file "/etc/audit/rules.d/50-sudo.rules"
        cat > /etc/audit/rules.d/50-sudo.rules << EOF
## CIS 6.3.3.3 - Monitor sudo log file
-w ${SUDO_LOG_FILE} -p wa -k sudo_log_file
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Sudo log monitoring configured for ${SUDO_LOG_FILE}"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure events that modify the sudo log file are collected" \
            "Sudo log location: ${SUDO_LOG_FILE}" \
            "Monitor sudo log file for modifications" \
            "Configure audit rules for the sudo log file location" \
            "Tracks modifications to sudo command logs" \
            "Add an audit watch for ${SUDO_LOG_FILE}"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.4 - Ensure events that modify date and time information are collected
    control_id="6.3.3.4"
    log_info "[${control_id}] Ensure events that modify date and time information are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex 'time-change'; then
        log_success "[${control_id}] PASS: time-change audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure events that modify date and time information are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep time-change || echo 'No rules found')" \
            "Monitor system time modifications" \
            "Verify audit rules for adjtimex, settimeofday, clock_settime syscalls" \
            "Tracks unauthorized time changes" \
            "Add audit rules for time-change syscalls and /etc/localtime"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure time modification monitoring?"; then
        backup_file "/etc/audit/rules.d/50-time-change.rules"
        cat > /etc/audit/rules.d/50-time-change.rules << EOF
## CIS 6.3.3.4 - Monitor date/time modifications
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
${ARCH:+-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change}
-w /etc/localtime -p wa -k time-change
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Time modification monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure events that modify date and time information are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep time-change || echo 'No rules found')" \
            "Monitor system time modifications" \
            "Verify audit rules for adjtimex, settimeofday, clock_settime syscalls" \
            "Tracks unauthorized time changes" \
            "Add audit rules for time-change syscalls and /etc/localtime"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.5 - Ensure events that modify the system's network environment are collected
    control_id="6.3.3.5"
    log_info "[${control_id}] Ensure events that modify the system's network environment are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex 'system-locale'; then
        log_success "[${control_id}] PASS: network environment audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure events that modify the system's network environment are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep system-locale || echo 'No rules found')" \
            "Monitor network configuration changes" \
            "Verify audit rules for hostname, domainname, network files" \
            "Tracks network environment modifications" \
            "Add audit rules for system-locale monitoring"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure network environment monitoring?"; then
        backup_file "/etc/audit/rules.d/50-system_local.rules"
        cat > /etc/audit/rules.d/50-system_local.rules << EOF
## CIS 6.3.3.5 - Monitor network environment changes
-a always,exit -F arch=b32 -S sethostname,setdomainname -k system-locale
${ARCH:+-a always,exit -F arch=b64 -S sethostname,setdomainname -k system-locale}
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/networks -p wa -k system-locale
-w /etc/network/ -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
-w /etc/sysconfig/network-scripts/ -p wa -k system-locale
-w /etc/NetworkManager/ -p wa -k system-locale
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Network environment monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure events that modify the system's network environment are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep system-locale || echo 'No rules found')" \
            "Monitor network configuration changes" \
            "Verify audit rules for hostname, domainname, network files" \
            "Tracks network environment modifications" \
            "Add audit rules for system-locale monitoring"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.6 - Ensure use of privileged commands are collected
    control_id="6.3.3.6"
    log_info "[${control_id}] Ensure use of privileged commands are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k privileged'; then
        log_success "[${control_id}] PASS: privileged command audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure use of privileged commands are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep -i privileged || echo 'No rules found')" \
            "Monitor execution of SUID/SGID programs" \
            "Run: find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print "-a always,exit -F path=" \$1 " -F perm=x -F auid>=1000 -F auid!=unset -k privileged"}' >> /etc/audit/rules.d/50-privileged.rules" \
            "Tracks privileged command execution" \
            "Add privileged command monitoring audit rules"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure privileged command monitoring? (This may take a moment)"; then
        backup_file "/etc/audit/rules.d/50-privileged.rules"
        echo "## CIS 6.3.3.6 - Monitor privileged commands" > /etc/audit/rules.d/50-privileged.rules
        find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
            awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=unset -k privileged"}' \
            >> /etc/audit/rules.d/50-privileged.rules
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Privileged command monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure use of privileged commands are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep -i privileged || echo 'No rules found')" \
            "Monitor execution of SUID/SGID programs" \
            "Run: find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print "-a always,exit -F path=" \$1 " -F perm=x -F auid>=1000 -F auid!=unset -k privileged"}' >> /etc/audit/rules.d/50-privileged.rules" \
            "Tracks privileged command execution" \
            "Add privileged command monitoring audit rules"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.7 - Ensure unsuccessful file access attempts are collected
    control_id="6.3.3.7"
    log_info "[${control_id}] Ensure unsuccessful file access attempts are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k access'; then
        log_success "[${control_id}] PASS: failed access audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure unsuccessful file access attempts are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep access || echo 'No rules found')" \
            "Monitor failed file access attempts" \
            "Verify audit rules for EACCES and EPERM errors" \
            "Tracks unauthorized access attempts" \
            "Add audit rules for EACCES and EPERM failures"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure failed access monitoring?"; then
        backup_file "/etc/audit/rules.d/50-access.rules"
        cat > /etc/audit/rules.d/50-access.rules << EOF
## CIS 6.3.3.7 - Monitor unsuccessful file access attempts
-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access
-a always,exit -F arch=b32 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access
${ARCH:+-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=unset -k access}
${ARCH:+-a always,exit -F arch=b64 -S creat,open,openat,truncate,ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=unset -k access}
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Failed access monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure unsuccessful file access attempts are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep access || echo 'No rules found')" \
            "Monitor failed file access attempts" \
            "Verify audit rules for EACCES and EPERM errors" \
            "Tracks unauthorized access attempts" \
            "Add audit rules for EACCES and EPERM failures"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.8 - Ensure events that modify user/group information are collected
    control_id="6.3.3.8"
    log_info "[${control_id}] Ensure events that modify user/group information are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure events that modify user/group information are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep identity || echo 'No rules found')" \
            "Monitor user/group file modifications" \
            "Verify audit rules for /etc/passwd, /etc/group, /etc/shadow, /etc/gshadow" \
            "Tracks account modifications"
        ((MANUAL_CHECKS++))
    elif confirm_action "[${control_id}] Configure user/group monitoring?"; then
        backup_file "/etc/audit/rules.d/50-identity.rules"
        cat > /etc/audit/rules.d/50-identity.rules << 'EOF'
## CIS 6.3.3.8 - Monitor user/group information changes
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: User/group monitoring configured"
        ((REMEDIATED_CHECKS++))
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.9 - Ensure discretionary access control permission modification events are collected
    control_id="6.3.3.9"
    log_info "[${control_id}] Ensure discretionary access control permission modification events are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k perm_mod'; then
        log_success "[${control_id}] PASS: permission modification audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure discretionary access control permission modification events are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep perm_mod || echo 'No rules found')" \
            "Monitor permission changes" \
            "Verify audit rules for chmod, fchmod, fchmodat, chown, fchown, etc." \
            "Tracks file permission modifications" \
            "Add audit rules for perm_mod"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure permission modification monitoring?"; then
        backup_file "/etc/audit/rules.d/50-perm_mod.rules"
        cat > /etc/audit/rules.d/50-perm_mod.rules << EOF
## CIS 6.3.3.9 - Monitor DAC permission modifications
-a always,exit -F arch=b32 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=unset -k perm_mod
-a always,exit -F arch=b32 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod
${ARCH:+-a always,exit -F arch=b64 -S chmod,fchmod,fchmodat -F auid>=1000 -F auid!=unset -k perm_mod}
${ARCH:+-a always,exit -F arch=b64 -S chown,fchown,fchownat,lchown -F auid>=1000 -F auid!=unset -k perm_mod}
${ARCH:+-a always,exit -F arch=b64 -S setxattr,lsetxattr,fsetxattr,removexattr,lremovexattr,fremovexattr -F auid>=1000 -F auid!=unset -k perm_mod}
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Permission modification monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure discretionary access control permission modification events are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep perm_mod || echo 'No rules found')" \
            "Monitor permission changes" \
            "Verify audit rules for chmod, fchmod, fchmodat, chown, fchown, etc." \
            "Tracks file permission modifications" \
            "Add audit rules for perm_mod"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.10 - Ensure successful file system mounts are collected
    control_id="6.3.3.10"
    log_info "[${control_id}] Ensure successful file system mounts are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k mounts'; then
        log_success "[${control_id}] PASS: mount audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure successful file system mounts are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep mounts || echo 'No rules found')" \
            "Monitor mount operations" \
            "Verify audit rules for mount syscall" \
            "Tracks filesystem mount operations" \
            "Add mount syscall audit rules"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure mount monitoring?"; then
        backup_file "/etc/audit/rules.d/50-mounts.rules"
        cat > /etc/audit/rules.d/50-mounts.rules << EOF
## CIS 6.3.3.10 - Monitor file system mounts
-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=unset -k mounts
${ARCH:+-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=unset -k mounts}
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Mount monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure successful file system mounts are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep mounts || echo 'No rules found')" \
            "Monitor mount operations" \
            "Verify audit rules for mount syscall" \
            "Tracks filesystem mount operations" \
            "Add mount syscall audit rules"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.11 - Ensure session initiation information is collected
    control_id="6.3.3.11"
    log_info "[${control_id}] Ensure session initiation information is collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k session'; then
        log_success "[${control_id}] PASS: session initiation audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure session initiation information is collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep session || echo 'No rules found')" \
            "Monitor session files" \
            "Verify audit rules for /var/run/utmp, /var/log/wtmp, /var/log/btmp" \
            "Tracks user login/logout sessions" \
            "Add audit watch rules for session files"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure session monitoring?"; then
        backup_file "/etc/audit/rules.d/50-session.rules"
        cat > /etc/audit/rules.d/50-session.rules << 'EOF'
## CIS 6.3.3.11 - Monitor session initiation
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Session monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure session initiation information is collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep session || echo 'No rules found')" \
            "Monitor session files" \
            "Verify audit rules for /var/run/utmp, /var/log/wtmp, /var/log/btmp" \
            "Tracks user login/logout sessions" \
            "Add audit watch rules for session files"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.12 - Ensure login and logout events are collected
    control_id="6.3.3.12"
    log_info "[${control_id}] Ensure login and logout events are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k logins'; then
        log_success "[${control_id}] PASS: login/logout audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure login and logout events are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep logins || echo 'No rules found')" \
            "Monitor login/logout events" \
            "Verify audit rules for /var/log/lastlog, /var/run/faillock" \
            "Tracks user authentication events" \
            "Add audit watch rules for login/logout files"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure login/logout monitoring?"; then
        backup_file "/etc/audit/rules.d/50-login.rules"
        cat > /etc/audit/rules.d/50-login.rules << 'EOF'
## CIS 6.3.3.12 - Monitor login/logout events
-w /var/log/lastlog -p wa -k logins
-w /var/run/faillock -p wa -k logins
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Login/logout monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure login and logout events are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep logins || echo 'No rules found')" \
            "Monitor login/logout events" \
            "Verify audit rules for /var/log/lastlog, /var/run/faillock" \
            "Tracks user authentication events" \
            "Add audit watch rules for login/logout files"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.13 - Ensure file deletion events by users are collected
    control_id="6.3.3.13"
    log_info "[${control_id}] Ensure file deletion events by users are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k delete'; then
        log_success "[${control_id}] PASS: file deletion audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure file deletion events by users are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep delete || echo 'No rules found')" \
            "Monitor file deletions" \
            "Verify audit rules for unlink, unlinkat, rename, renameat syscalls" \
            "Tracks file deletion operations" \
            "Add audit rules for file deletion syscalls"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure file deletion monitoring?"; then
        backup_file "/etc/audit/rules.d/50-delete.rules"
        cat > /etc/audit/rules.d/50-delete.rules << EOF
## CIS 6.3.3.13 - Monitor file deletions
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k delete
${ARCH:+-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F auid>=1000 -F auid!=unset -k delete}
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: File deletion monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure file deletion events by users are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep delete || echo 'No rules found')" \
            "Monitor file deletions" \
            "Verify audit rules for unlink, unlinkat, rename, renameat syscalls" \
            "Tracks file deletion operations" \
            "Add audit rules for file deletion syscalls"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.14 - Ensure events that modify the system's Mandatory Access Controls are collected
    control_id="6.3.3.14"
    log_info "[${control_id}] Ensure events that modify the system's Mandatory Access Controls are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex 'MAC-policy'; then
        log_success "[${control_id}] PASS: MAC policy audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure events that modify the system's Mandatory Access Controls are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep MAC-policy || echo 'No rules found')" \
            "Monitor SELinux policy changes" \
            "Verify audit rules for /etc/selinux/" \
            "Tracks MAC policy modifications" \
            "Add audit rules for MAC-policy monitoring"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure MAC monitoring?"; then
        backup_file "/etc/audit/rules.d/50-MAC-policy.rules"
        cat > /etc/audit/rules.d/50-MAC-policy.rules << 'EOF'
## CIS 6.3.3.14 - Monitor MAC policy changes
-w /etc/selinux/ -p wa -k MAC-policy
-w /usr/share/selinux/ -p wa -k MAC-policy
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: MAC monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure events that modify the system's Mandatory Access Controls are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep MAC-policy || echo 'No rules found')" \
            "Monitor SELinux policy changes" \
            "Verify audit rules for /etc/selinux/" \
            "Tracks MAC policy modifications" \
            "Add audit rules for MAC-policy monitoring"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.15 - Ensure successful and unsuccessful attempts to use the chcon command are collected
    control_id="6.3.3.15"
    log_info "[${control_id}] Ensure successful and unsuccessful attempts to use the chcon command are collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k perm_chng'; then
        log_success "[${control_id}] PASS: chcon audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure chcon command usage is collected" \
            "chcon location: $(which chcon 2>/dev/null || echo 'Not found')" \
            "Monitor chcon command execution" \
            "Verify audit rules for chcon command" \
            "Tracks SELinux context changes" \
            "Add audit rules for chcon command execution"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure chcon monitoring?"; then
        local CHCON_PATH=$(which chcon 2>/dev/null || echo "/usr/bin/chcon")
        backup_file "/etc/audit/rules.d/50-perm_chng.rules"
        cat > /etc/audit/rules.d/50-perm_chng.rules << EOF
## CIS 6.3.3.15 - Monitor chcon command
-a always,exit -F path=${CHCON_PATH} -F perm=x -F auid>=1000 -F auid!=unset -k perm_chng
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: chcon monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure chcon command usage is collected" \
            "chcon location: $(which chcon 2>/dev/null || echo 'Not found')" \
            "Monitor chcon command execution" \
            "Verify audit rules for chcon command" \
            "Tracks SELinux context changes" \
            "Add audit rules for chcon command execution"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.16 - Ensure successful and unsuccessful attempts to use the setfacl command are collected
    control_id="6.3.3.16"
    log_info "[${control_id}] Ensure setfacl command usage is collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k priv_cmd'; then
        log_success "[${control_id}] PASS: setfacl audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure setfacl command usage is collected" \
            "setfacl location: $(which setfacl 2>/dev/null || echo 'Not found')" \
            "Monitor setfacl command execution" \
            "Verify audit rules for setfacl command" \
            "Tracks ACL modifications" \
            "Add audit rules for setfacl command execution"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure setfacl monitoring?"; then
        local SETFACL_PATH=$(which setfacl 2>/dev/null || echo "/usr/bin/setfacl")
        cat >> /etc/audit/rules.d/50-perm_chng.rules << EOF
## CIS 6.3.3.16 - Monitor setfacl command
-a always,exit -F path=${SETFACL_PATH} -F perm=x -F auid>=1000 -F auid!=unset -k priv_cmd
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: setfacl monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure setfacl command usage is collected" \
            "setfacl location: $(which setfacl 2>/dev/null || echo 'Not found')" \
            "Monitor setfacl command execution" \
            "Verify audit rules for setfacl command" \
            "Tracks ACL modifications" \
            "Add audit rules for setfacl command execution"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.17 - Ensure successful and unsuccessful attempts to use the chacl command are collected
    control_id="6.3.3.17"
    log_info "[${control_id}] Ensure chacl command usage is collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k priv_cmd'; then
        log_success "[${control_id}] PASS: chacl audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure chacl command usage is collected" \
            "chacl location: $(which chacl 2>/dev/null || echo 'Not found')" \
            "Monitor chacl command execution" \
            "Verify audit rules for chacl command" \
            "Tracks ACL changes" \
            "Add audit rules for chacl command execution"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure chacl monitoring?"; then
        local CHACL_PATH=$(which chacl 2>/dev/null || echo "/usr/bin/chacl")
        cat >> /etc/audit/rules.d/50-perm_chng.rules << EOF
## CIS 6.3.3.17 - Monitor chacl command
-a always,exit -F path=${CHACL_PATH} -F perm=x -F auid>=1000 -F auid!=unset -k priv_cmd
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: chacl monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure chacl command usage is collected" \
            "chacl location: $(which chacl 2>/dev/null || echo 'Not found')" \
            "Monitor chacl command execution" \
            "Verify audit rules for chacl command" \
            "Tracks ACL changes" \
            "Add audit rules for chacl command execution"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.18 - Ensure successful and unsuccessful attempts to use the usermod command are collected
    control_id="6.3.3.18"
    log_info "[${control_id}] Ensure usermod command usage is collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k usermod'; then
        log_success "[${control_id}] PASS: usermod audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure usermod command usage is collected" \
            "usermod location: $(which usermod 2>/dev/null || echo 'Not found')" \
            "Monitor usermod command execution" \
            "Verify audit rules for usermod command" \
            "Tracks user account modifications" \
            "Add audit rules for usermod command execution"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure usermod monitoring?"; then
        local USERMOD_PATH=$(which usermod 2>/dev/null || echo "/usr/sbin/usermod")
        backup_file "/etc/audit/rules.d/50-usermod.rules"
        cat > /etc/audit/rules.d/50-usermod.rules << EOF
## CIS 6.3.3.18 - Monitor usermod command
-a always,exit -F path=${USERMOD_PATH} -F perm=x -F auid>=1000 -F auid!=unset -k usermod
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: usermod monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure usermod command usage is collected" \
            "usermod location: $(which usermod 2>/dev/null || echo 'Not found')" \
            "Monitor usermod command execution" \
            "Verify audit rules for usermod command" \
            "Tracks user account modifications" \
            "Add audit rules for usermod command execution"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.19 - Ensure kernel module loading unloading and modification is collected
    control_id="6.3.3.19"
    log_info "[${control_id}] Ensure kernel module loading unloading and modification is collected"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '-k kernel_modules'; then
        log_success "[${control_id}] PASS: kernel module audit rules are loaded"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure kernel module operations are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep modules || echo 'No rules found')" \
            "Monitor kernel module operations" \
            "Verify audit rules for init_module, delete_module, finit_module syscalls" \
            "Tracks kernel module changes" \
            "Add kernel module audit rules"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Configure kernel module monitoring?"; then
        backup_file "/etc/audit/rules.d/50-kernel_modules.rules"
        cat > /etc/audit/rules.d/50-kernel_modules.rules << EOF
## CIS 6.3.3.19 - Monitor kernel module operations
-a always,exit -F arch=b32 -S init_module,delete_module,finit_module -F auid>=1000 -F auid!=unset -k kernel_modules
${ARCH:+-a always,exit -F arch=b64 -S init_module,delete_module,finit_module -F auid>=1000 -F auid!=unset -k kernel_modules}
-a always,exit -F path=/usr/bin/kmod -F perm=x -F auid>=1000 -F auid!=unset -k kernel_modules
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Kernel module monitoring configured"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure kernel module operations are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep modules || echo 'No rules found')" \
            "Monitor kernel module operations" \
            "Verify audit rules for init_module, delete_module, finit_module syscalls" \
            "Tracks kernel module changes" \
            "Add kernel module audit rules"
        ((FAILED_CHECKS++))
    fi
    
    # 6.3.3.20 - Ensure the audit configuration is immutable
    control_id="6.3.3.20"
    log_info "[${control_id}] Ensure the audit configuration is immutable"
    ((TOTAL_CHECKS++))
    
    if audit_rule_exists_regex '^-e 2'; then
        log_success "[${control_id}] PASS: audit configuration is immutable"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_check_failed "${control_id}" \
            "Ensure the audit configuration is immutable" \
            "Current rules: $(auditctl -l 2>/dev/null | grep '^-e 2' || echo 'Not immutable')" \
            "Make audit configuration immutable" \
            "Add '-e 2' as the last line in /etc/audit/rules.d/99-finalize.rules" \
            "Prevents runtime modification of audit rules (requires reboot to change)" \
            "Add -e 2 to audit rule configuration and reload rules"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Make audit configuration immutable? (Requires reboot to modify)"; then
        backup_file "/etc/audit/rules.d/99-finalize.rules"
        cat > /etc/audit/rules.d/99-finalize.rules << 'EOF'
## CIS 6.3.3.20 - Make audit configuration immutable
## This MUST be the last rule
-e 2
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Audit configuration set to immutable"
        ((REMEDIATED_CHECKS++))
    else
        log_check_failed "${control_id}" \
            "Ensure the audit configuration is immutable" \
            "Current rules: $(auditctl -l 2>/dev/null | grep '^-e 2' || echo 'Not immutable')" \
            "Make audit configuration immutable" \
            "Add '-e 2' as the last line in /etc/audit/rules.d/99-finalize.rules" \
            "Prevents runtime modification of audit rules (requires reboot to change)" \
            "Add -e 2 to audit rule configuration and reload rules"
        ((FAILED_CHECKS++))
    fi

    # 6.3.3.21 - Ensure the running and on disk configuration is the same
    control_id="6.3.3.21"
    log_info "[${control_id}] Ensure the running and on disk configuration is the same"
    ((TOTAL_CHECKS++))
    
    log_check_manual "${control_id}" \
        "Ensure the running and on disk configuration is the same" \
        "Running rules: $(auditctl -l 2>/dev/null | wc -l) lines, On-disk rules: $(cat /etc/audit/rules.d/*.rules 2>/dev/null | grep -v '^#' | grep -v '^$' | wc -l) lines" \
        "Verify audit rules are loaded" \
        "1. Check running: auditctl -l
2. Check on-disk: cat /etc/audit/rules.d/*.rules
3. Load rules: augenrules --load
4. Restart auditd: service auditd restart" \
        "Ensures audit rules are active"
    ((MANUAL_CHECKS++))
    
    # Section 6.3.4: Configure auditd File Access (checks 1-10)
    for i in {1..10}; do
        control_id="6.3.4.${i}"
        ((TOTAL_CHECKS++))
        local failures=()
        local target_paths=()

        case ${i} in
            1)
                target_paths=("/var/log/audit")
                for path in "${target_paths[@]}"; do
                    if [[ ! -d "${path}" ]]; then
                        failures+=("${path}: directory missing")
                        continue
                    fi
                    local mode owner group
                    read -r mode owner group < <(stat -Lc '%a %U %G' "${path}" 2>/dev/null)
                    if (( 10#${mode} > 750 )); then
                        failures+=("${path}: mode ${mode} is more permissive than 750")
                    fi
                    if [[ "${owner}" != "root" ]]; then
                        failures+=("${path}: owner ${owner} is not root")
                    fi
                    if [[ "${group}" != "root" ]]; then
                        failures+=("${path}: group ${group} is not root")
                    fi
                done
                ;;
            2)
                while IFS= read -r -d '' logfile; do
                    target_paths+=("${logfile}")
                done < <(find /var/log/audit -maxdepth 1 -type f -name '*.log' -print0 2>/dev/null)
                if [[ ${#target_paths[@]} -eq 0 ]]; then
                    failures+=("No audit log files found in /var/log/audit")
                fi
                for path in "${target_paths[@]}"; do
                    local mode owner group
                    read -r mode owner group < <(stat -Lc '%a %U %G' "${path}" 2>/dev/null)
                    if (( 10#${mode} > 600 )); then
                        failures+=("${path}: mode ${mode} is more permissive than 600")
                    fi
                done
                ;;
            3)
                while IFS= read -r -d '' logfile; do
                    target_paths+=("${logfile}")
                done < <(find /var/log/audit -maxdepth 1 -type f -name '*.log' -print0 2>/dev/null)
                if [[ ${#target_paths[@]} -eq 0 ]]; then
                    failures+=("No audit log files found in /var/log/audit")
                fi
                for path in "${target_paths[@]}"; do
                    local owner
                    owner=$(stat -Lc '%U' "${path}" 2>/dev/null)
                    if [[ "${owner}" != "root" ]]; then
                        failures+=("${path}: owner ${owner} is not root")
                    fi
                done
                ;;
            4)
                while IFS= read -r -d '' logfile; do
                    target_paths+=("${logfile}")
                done < <(find /var/log/audit -maxdepth 1 -type f -name '*.log' -print0 2>/dev/null)
                if [[ ${#target_paths[@]} -eq 0 ]]; then
                    failures+=("No audit log files found in /var/log/audit")
                fi
                for path in "${target_paths[@]}"; do
                    local group
                    group=$(stat -Lc '%G' "${path}" 2>/dev/null)
                    if [[ "${group}" != "root" ]]; then
                        failures+=("${path}: group ${group} is not root")
                    fi
                done
                ;;
            5)
                while IFS= read -r -d '' cfgfile; do
                    target_paths+=("${cfgfile}")
                done < <(find /etc/audit -type f -print0 2>/dev/null)
                if [[ ${#target_paths[@]} -eq 0 ]]; then
                    failures+=("No audit configuration files found in /etc/audit")
                fi
                for path in "${target_paths[@]}"; do
                    local mode
                    mode=$(stat -Lc '%a' "${path}" 2>/dev/null)
                    if (( 10#${mode} > 640 )); then
                        failures+=("${path}: mode ${mode} is more permissive than 640")
                    fi
                done
                ;;
            6)
                while IFS= read -r -d '' cfgfile; do
                    target_paths+=("${cfgfile}")
                done < <(find /etc/audit -type f -print0 2>/dev/null)
                if [[ ${#target_paths[@]} -eq 0 ]]; then
                    failures+=("No audit configuration files found in /etc/audit")
                fi
                for path in "${target_paths[@]}"; do
                    local owner
                    owner=$(stat -Lc '%U' "${path}" 2>/dev/null)
                    if [[ "${owner}" != "root" ]]; then
                        failures+=("${path}: owner ${owner} is not root")
                    fi
                done
                ;;
            7)
                while IFS= read -r -d '' cfgfile; do
                    target_paths+=("${cfgfile}")
                done < <(find /etc/audit -type f -print0 2>/dev/null)
                if [[ ${#target_paths[@]} -eq 0 ]]; then
                    failures+=("No audit configuration files found in /etc/audit")
                fi
                for path in "${target_paths[@]}"; do
                    local group
                    group=$(stat -Lc '%G' "${path}" 2>/dev/null)
                    if [[ "${group}" != "root" ]]; then
                        failures+=("${path}: group ${group} is not root")
                    fi
                done
                ;;
            8)
                local tools=("$(command -v auditctl || true)" "$(command -v ausearch || true)" "$(command -v aureport || true)" "$(command -v augenrules || true)")
                for path in "${tools[@]}"; do
                    [[ -n "${path}" ]] || continue
                    target_paths+=("${path}")
                    local mode
                    mode=$(stat -Lc '%a' "${path}" 2>/dev/null)
                    if (( 10#${mode} > 755 )); then
                        failures+=("${path}: mode ${mode} is more permissive than 755")
                    fi
                done
                ;;
            9)
                local tools=("$(command -v auditctl || true)" "$(command -v ausearch || true)" "$(command -v aureport || true)" "$(command -v augenrules || true)")
                for path in "${tools[@]}"; do
                    [[ -n "${path}" ]] || continue
                    target_paths+=("${path}")
                    local owner
                    owner=$(stat -Lc '%U' "${path}" 2>/dev/null)
                    if [[ "${owner}" != "root" ]]; then
                        failures+=("${path}: owner ${owner} is not root")
                    fi
                done
                ;;
            10)
                local tools=("$(command -v auditctl || true)" "$(command -v ausearch || true)" "$(command -v aureport || true)" "$(command -v augenrules || true)")
                for path in "${tools[@]}"; do
                    [[ -n "${path}" ]] || continue
                    target_paths+=("${path}")
                    local group
                    group=$(stat -Lc '%G' "${path}" 2>/dev/null)
                    if [[ "${group}" != "root" ]]; then
                        failures+=("${path}: group ${group} is not root")
                    fi
                done
                ;;
        esac

        if [[ ${#failures[@]} -eq 0 ]]; then
            log_success "[${control_id}] PASS: audit file access settings are compliant"
            ((PASSED_CHECKS++))
        else
            log_check_failed "${control_id}" \
                "Ensure audit file access is configured" \
                "Non-compliant paths:\n$(printf '%s\n' "${failures[@]}" | head -20)" \
                "Fix ownership and permissions for audit files and tools" \
                "1. Review the identified paths and adjust permissions/ownership
2. Set proper modes and ownership for /var/log/audit, /etc/audit, and audit tools
3. Verify with stat or ls -l" \
                "Audit files and tools must be restricted to root ownership and secure permissions"
            ((FAILED_CHECKS++))
        fi
    done
}

run_section_6() {
    if ! should_run_section "6"; then
        log_info "Skipping Section 6: Logging and Auditing (not selected)"
        return 0
    fi
    
    log_info "=== Section 6: Logging and Auditing ==="
    
    # Section 6.1: Configure Integrity Checking (3 checks)
    remediate_aide
    
    # Section 6.2: System Logging (20 checks)
    remediate_system_logging
    
    # Section 6.3: System Auditing (77 checks)
    remediate_auditd
    
    log_info "Section 6 complete: 100 checks (3 + 20 + 77)"
}


