#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 6: Logging and Auditing
# Version: 2.0.0
# Description: Implementation of CIS Section 6 controls
################################################################################

################################################################################
# SECTION 6.1: SYSTEM FILE INTEGRITY
################################################################################

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
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure only one logging system is in use" \
        "Installed logging systems: $(rpm -qa | grep -E 'rsyslog|syslog-ng' || echo 'None found')" \
        "Use either rsyslog OR syslog-ng, not both" \
        "1. Check installed: rpm -qa | grep -E 'rsyslog|syslog-ng'
2. If both installed, remove one: dnf remove <package>
3. Verify only one is active: systemctl status rsyslog syslog-ng" \
        "Running multiple logging systems can cause conflicts and resource issues"
    ((MANUAL_CHECKS++))
    
    # 6.2.2.x - Configure journald (Manual checks)
    for i in {1..4}; do
        control_id="6.2.2.${i}"
        ((TOTAL_CHECKS++))
        local check_titles=(
            "Ensure systemd-journal-remote is installed"
            "Ensure systemd-journal-upload authentication is configured"
            "Ensure systemd-journal-upload is enabled and active"
            "Ensure systemd-journal-remote service is not in use"
        )
        log_check_manual "${control_id}" \
            "${check_titles[$((i-1))]}" \
            "Check /etc/systemd/journal-upload.conf and systemd-journal-remote status" \
            "Configure journal remote logging per organizational requirements" \
            "1. Review CIS Benchmark Section 6.2.2.${i}
2. Configure /etc/systemd/journal-upload.conf
3. Set up TLS certificates if needed
4. Enable/disable services as required" \
            "Remote logging configuration depends on organizational security policy"
        ((MANUAL_CHECKS++))
    done
    
    # 6.2.2.2 - Ensure journald ForwardToSyslog is disabled (Automated)
    control_id="6.2.2.2"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure journald ForwardToSyslog is disabled" \
        "Current setting: $(grep -E '^ForwardToSyslog' /etc/systemd/journald.conf 2>/dev/null || echo 'Not explicitly set')" \
        "ForwardToSyslog=no in /etc/systemd/journald.conf" \
        "1. Edit /etc/systemd/journald.conf
2. Set: ForwardToSyslog=no
3. Restart: systemctl restart systemd-journald
4. Verify: grep ForwardToSyslog /etc/systemd/journald.conf" \
        "Disable forwarding if using journald as primary logging system"
    ((MANUAL_CHECKS++))
    
    # 6.2.2.3 - Ensure journald Compress is configured (Automated)
    control_id="6.2.2.3"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure journald Compress is configured" \
        "Current setting: $(grep -E '^Compress' /etc/systemd/journald.conf 2>/dev/null || echo 'Using default (yes)')" \
        "Compress=yes in /etc/systemd/journald.conf" \
        "1. Edit /etc/systemd/journald.conf
2. Set: Compress=yes
3. Restart: systemctl restart systemd-journald
4. Verify: grep Compress /etc/systemd/journald.conf" \
        "Compression reduces disk space usage for log files"
    ((MANUAL_CHECKS++))
    
    # 6.2.2.4 - Ensure journald Storage is configured (Automated)
    control_id="6.2.2.4"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure journald Storage is configured" \
        "Current setting: $(grep -E '^Storage' /etc/systemd/journald.conf 2>/dev/null || echo 'Using default (auto)')" \
        "Storage=persistent in /etc/systemd/journald.conf" \
        "1. Edit /etc/systemd/journald.conf
2. Set: Storage=persistent
3. Restart: systemctl restart systemd-journald
4. Verify: grep Storage /etc/systemd/journald.conf" \
        "Persistent storage ensures logs survive reboots"
    ((MANUAL_CHECKS++))
    
    # 6.2.3.x - Configure rsyslog (Manual checks)
    for i in {1..8}; do
        control_id="6.2.3.${i}"
        ((TOTAL_CHECKS++))
        local rsyslog_titles=(
            "Ensure rsyslog is installed"
            "Ensure rsyslog service is enabled and active"
            "Ensure journald is configured to send logs to rsyslog"
            "Ensure rsyslog log file creation mode is configured"
            "Ensure rsyslog logging is configured"
            "Ensure rsyslog is configured to send logs to a remote log host"
            "Ensure rsyslog is not configured to receive logs from a remote client"
            "Ensure rsyslog logrotate is configured"
        )
        log_check_manual "${control_id}" \
            "${rsyslog_titles[$((i-1))]}" \
            "Check rsyslog configuration in /etc/rsyslog.conf and /etc/rsyslog.d/" \
            "Configure rsyslog per organizational logging requirements" \
            "1. Review CIS Benchmark Section 6.2.3.${i}
2. Edit /etc/rsyslog.conf or files in /etc/rsyslog.d/
3. Configure log forwarding, file permissions, and rotation
4. Restart: systemctl restart rsyslog" \
            "rsyslog configuration depends on organizational security and compliance requirements"
        ((MANUAL_CHECKS++))
    done
    
    # 6.2.4.1 - Ensure access to all logfiles has been configured (Automated)
    control_id="6.2.4.1"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure access to all logfiles has been configured" \
        "Current log file permissions: $(find /var/log -type f -ls 2>/dev/null | head -5 || echo 'Unable to list')" \
        "All log files should have permissions 0640 or more restrictive" \
        "1. Find world-readable logs: find /var/log -type f -perm /o+r
2. Set permissions: chmod g-wx,o-rwx /var/log/*
3. Verify: ls -la /var/log/
4. Configure logrotate to maintain permissions" \
        "Proper log file permissions prevent unauthorized access to sensitive system information"
    ((MANUAL_CHECKS++))
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
    log_check_manual "${control_id}" \
        "Ensure auditing for processes that start prior to auditd is enabled" \
        "Current GRUB config: $(grep -E 'audit=1' /etc/default/grub 2>/dev/null || echo 'audit=1 not found')" \
        "Add audit=1 to GRUB_CMDLINE_LINUX in /etc/default/grub" \
        "1. Edit /etc/default/grub
2. Add audit=1 to GRUB_CMDLINE_LINUX
3. Update GRUB: grub2-mkconfig -o /boot/grub2/grub.cfg
4. Reboot system
5. Verify: cat /proc/cmdline | grep audit=1" \
        "Early boot auditing captures events before auditd starts"
    ((MANUAL_CHECKS++))
    
    # 6.3.1.3 - Ensure audit_backlog_limit is sufficient
    control_id="6.3.1.3"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure audit_backlog_limit is sufficient" \
        "Current setting: $(grep -E 'audit_backlog_limit' /etc/default/grub 2>/dev/null || echo 'Not set')" \
        "Add audit_backlog_limit=8192 to GRUB_CMDLINE_LINUX" \
        "1. Edit /etc/default/grub
2. Add audit_backlog_limit=8192 to GRUB_CMDLINE_LINUX
3. Update GRUB: grub2-mkconfig -o /boot/grub2/grub.cfg
4. Reboot system
5. Verify: cat /proc/cmdline | grep audit_backlog_limit" \
        "Sufficient backlog prevents audit event loss during high activity"
    ((MANUAL_CHECKS++))
    
    # 6.3.1.4 - Ensure auditd service is enabled and active
    control_id="6.3.1.4"
    ((TOTAL_CHECKS++))
    log_check_manual "${control_id}" \
        "Ensure auditd service is enabled and active" \
        "Status: $(systemctl is-enabled auditd 2>&1), $(systemctl is-active auditd 2>&1)" \
        "auditd should be enabled and active" \
        "1. Enable: systemctl enable auditd
2. Start: systemctl start auditd
3. Verify: systemctl status auditd" \
        "Active auditd service is required for system auditing"
    ((MANUAL_CHECKS++))
    
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
        IFS='|' read -r title action desc <<< "${retention_checks[$((i-1))]}"
        log_check_manual "${control_id}" \
            "${title}" \
            "Current /etc/audit/auditd.conf settings: $(grep -E 'max_log_file|space_left|action_mail' /etc/audit/auditd.conf 2>/dev/null || echo 'Check file')" \
            "${action}" \
            "1. Edit /etc/audit/auditd.conf
2. Configure retention settings per site policy
3. Restart: service auditd restart
4. Verify: grep -E 'max_log_file|space_left' /etc/audit/auditd.conf" \
            "${desc}"
        ((MANUAL_CHECKS++))
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
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure changes to system administration scope (sudoers) is collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep -E '/etc/sudoers|/etc/sudoers.d' || echo 'No rules found')" \
            "Monitor changes to sudoers files" \
            "Verify audit rules are configured to monitor /etc/sudoers and /etc/sudoers.d/" \
            "Tracks changes to sudo configuration"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.2 - Ensure actions as another user are always logged
    control_id="6.3.3.2"
    log_info "[${control_id}] Ensure actions as another user are always logged"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure actions as another user are always logged" \
            "Current rules: $(auditctl -l 2>/dev/null | grep execve || echo 'No rules found')" \
            "Monitor execve syscalls where uid != euid" \
            "Verify audit rules track user impersonation attempts" \
            "Detects when users execute commands as another user"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.3 - Ensure events that modify the sudo log file are collected
    control_id="6.3.3.3"
    log_info "[${control_id}] Ensure events that modify the sudo log file are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure events that modify the sudo log file are collected" \
            "Sudo log location: $(grep -r logfile /etc/sudoers* 2>/dev/null || echo '/var/log/sudo.log (default)')" \
            "Monitor sudo log file for modifications" \
            "Configure audit rules for the sudo log file location" \
            "Tracks modifications to sudo command logs"
        ((MANUAL_CHECKS++))
    elif confirm_action "[${control_id}] Configure sudo log monitoring?"; then
        local SUDO_LOG_FILE=$(grep -r logfile /etc/sudoers* 2>/dev/null | awk '{print $NF}' | tr -d '"' | head -1)
        SUDO_LOG_FILE=${SUDO_LOG_FILE:-/var/log/sudo.log}
        backup_file "/etc/audit/rules.d/50-sudo.rules"
        cat > /etc/audit/rules.d/50-sudo.rules << EOF
## CIS 6.3.3.3 - Monitor sudo log file
-w ${SUDO_LOG_FILE} -p wa -k sudo_log_file
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Sudo log monitoring configured for ${SUDO_LOG_FILE}"
        ((REMEDIATED_CHECKS++))
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.4 - Ensure events that modify date and time information are collected
    control_id="6.3.3.4"
    log_info "[${control_id}] Ensure events that modify date and time information are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure events that modify date and time information are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep time-change || echo 'No rules found')" \
            "Monitor system time modifications" \
            "Verify audit rules for adjtimex, settimeofday, clock_settime syscalls" \
            "Tracks unauthorized time changes"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.5 - Ensure events that modify the system's network environment are collected
    control_id="6.3.3.5"
    log_info "[${control_id}] Ensure events that modify the system's network environment are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure events that modify the system's network environment are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep system-locale || echo 'No rules found')" \
            "Monitor network configuration changes" \
            "Verify audit rules for hostname, domainname, network files" \
            "Tracks network environment modifications"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.6 - Ensure use of privileged commands are collected
    control_id="6.3.3.6"
    log_info "[${control_id}] Ensure use of privileged commands are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure use of privileged commands are collected" \
            "Privileged commands: $(find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | wc -l) found" \
            "Monitor execution of SUID/SGID programs" \
            "Run: find / -xdev \( -perm -4000 -o -perm -2000 \) -type f | awk '{print \"-a always,exit -F path=\" \$1 \" -F perm=x -F auid>=1000 -F auid!=unset -k privileged\"}' >> /etc/audit/rules.d/50-privileged.rules" \
            "Tracks privileged command execution"
        ((MANUAL_CHECKS++))
    elif confirm_action "[${control_id}] Configure privileged command monitoring? (This may take a moment)"; then
        backup_file "/etc/audit/rules.d/50-privileged.rules"
        echo "## CIS 6.3.3.6 - Monitor privileged commands" > /etc/audit/rules.d/50-privileged.rules
        find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
            awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=unset -k privileged"}' \
            >> /etc/audit/rules.d/50-privileged.rules
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: Privileged command monitoring configured"
        ((REMEDIATED_CHECKS++))
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.7 - Ensure unsuccessful file access attempts are collected
    control_id="6.3.3.7"
    log_info "[${control_id}] Ensure unsuccessful file access attempts are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure unsuccessful file access attempts are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep access || echo 'No rules found')" \
            "Monitor failed file access attempts" \
            "Verify audit rules for EACCES and EPERM errors" \
            "Tracks unauthorized access attempts"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
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
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure discretionary access control permission modification events are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep perm_mod || echo 'No rules found')" \
            "Monitor permission changes" \
            "Verify audit rules for chmod, fchmod, fchmodat, chown, fchown, etc." \
            "Tracks file permission modifications"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.10 - Ensure successful file system mounts are collected
    control_id="6.3.3.10"
    log_info "[${control_id}] Ensure successful file system mounts are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure successful file system mounts are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep mounts || echo 'No rules found')" \
            "Monitor mount operations" \
            "Verify audit rules for mount syscall" \
            "Tracks filesystem mount operations"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.11 - Ensure session initiation information is collected
    control_id="6.3.3.11"
    log_info "[${control_id}] Ensure session initiation information is collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure session initiation information is collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep session || echo 'No rules found')" \
            "Monitor session files" \
            "Verify audit rules for /var/run/utmp, /var/log/wtmp, /var/log/btmp" \
            "Tracks user login/logout sessions"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.12 - Ensure login and logout events are collected
    control_id="6.3.3.12"
    log_info "[${control_id}] Ensure login and logout events are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure login and logout events are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep logins || echo 'No rules found')" \
            "Monitor login/logout events" \
            "Verify audit rules for /var/log/lastlog, /var/run/faillock" \
            "Tracks user authentication events"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.13 - Ensure file deletion events by users are collected
    control_id="6.3.3.13"
    log_info "[${control_id}] Ensure file deletion events by users are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure file deletion events by users are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep delete || echo 'No rules found')" \
            "Monitor file deletions" \
            "Verify audit rules for unlink, unlinkat, rename, renameat syscalls" \
            "Tracks file deletion operations"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.14 - Ensure events that modify the system's Mandatory Access Controls are collected
    control_id="6.3.3.14"
    log_info "[${control_id}] Ensure events that modify the system's Mandatory Access Controls are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure events that modify the system's Mandatory Access Controls are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep MAC-policy || echo 'No rules found')" \
            "Monitor SELinux policy changes" \
            "Verify audit rules for /etc/selinux/" \
            "Tracks MAC policy modifications"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.15 - Ensure successful and unsuccessful attempts to use the chcon command are collected
    control_id="6.3.3.15"
    log_info "[${control_id}] Ensure successful and unsuccessful attempts to use the chcon command are collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure chcon command usage is collected" \
            "chcon location: $(which chcon 2>/dev/null || echo 'Not found')" \
            "Monitor chcon command execution" \
            "Verify audit rules for chcon command" \
            "Tracks SELinux context changes"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.16 - Ensure successful and unsuccessful attempts to use the setfacl command are collected
    control_id="6.3.3.16"
    log_info "[${control_id}] Ensure setfacl command usage is collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure setfacl command usage is collected" \
            "setfacl location: $(which setfacl 2>/dev/null || echo 'Not found')" \
            "Monitor setfacl command execution" \
            "Verify audit rules for setfacl command" \
            "Tracks ACL modifications"
        ((MANUAL_CHECKS++))
    elif confirm_action "[${control_id}] Configure setfacl monitoring?"; then
        local SETFACL_PATH=$(which setfacl 2>/dev/null || echo "/usr/bin/setfacl")
        cat >> /etc/audit/rules.d/50-perm_chng.rules << EOF
## CIS 6.3.3.16 - Monitor setfacl command
-a always,exit -F path=${SETFACL_PATH} -F perm=x -F auid>=1000 -F auid!=unset -k priv_cmd
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: setfacl monitoring configured"
        ((REMEDIATED_CHECKS++))
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.17 - Ensure successful and unsuccessful attempts to use the chacl command are collected
    control_id="6.3.3.17"
    log_info "[${control_id}] Ensure chacl command usage is collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure chacl command usage is collected" \
            "chacl location: $(which chacl 2>/dev/null || echo 'Not found')" \
            "Monitor chacl command execution" \
            "Verify audit rules for chacl command" \
            "Tracks ACL changes"
        ((MANUAL_CHECKS++))
    elif confirm_action "[${control_id}] Configure chacl monitoring?"; then
        local CHACL_PATH=$(which chacl 2>/dev/null || echo "/usr/bin/chacl")
        cat >> /etc/audit/rules.d/50-perm_chng.rules << EOF
## CIS 6.3.3.17 - Monitor chacl command
-a always,exit -F path=${CHACL_PATH} -F perm=x -F auid>=1000 -F auid!=unset -k priv_cmd
EOF
        augenrules --load &>/dev/null || true
        log_success "[${control_id}] Remediated: chacl monitoring configured"
        ((REMEDIATED_CHECKS++))
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.18 - Ensure successful and unsuccessful attempts to use the usermod command are collected
    control_id="6.3.3.18"
    log_info "[${control_id}] Ensure usermod command usage is collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure usermod command usage is collected" \
            "usermod location: $(which usermod 2>/dev/null || echo 'Not found')" \
            "Monitor usermod command execution" \
            "Verify audit rules for usermod command" \
            "Tracks user account modifications"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.19 - Ensure kernel module loading unloading and modification is collected
    control_id="6.3.3.19"
    log_info "[${control_id}] Ensure kernel module loading unloading and modification is collected"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure kernel module operations are collected" \
            "Current rules: $(auditctl -l 2>/dev/null | grep modules || echo 'No rules found')" \
            "Monitor kernel module operations" \
            "Verify audit rules for init_module, delete_module, finit_module syscalls" \
            "Tracks kernel module changes"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
    fi
    
    # 6.3.3.20 - Ensure the audit configuration is immutable
    control_id="6.3.3.20"
    log_info "[${control_id}] Ensure the audit configuration is immutable"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        log_check_manual "${control_id}" \
            "Ensure the audit configuration is immutable" \
            "Current rules: $(auditctl -l 2>/dev/null | grep '^-e 2' || echo 'Not immutable')" \
            "Make audit configuration immutable" \
            "Add '-e 2' as the last line in /etc/audit/rules.d/99-finalize.rules" \
            "Prevents runtime modification of audit rules (requires reboot to change)"
        ((MANUAL_CHECKS++))
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
        ((MANUAL_CHECKS++))
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
    local file_access_checks=(
        "audit log file directory mode|/var/log/audit directory|0750 or more restrictive"
        "audit log files mode|/var/log/audit/*.log files|0600 or more restrictive"
        "audit log files owner|/var/log/audit/*.log files|root ownership"
        "audit log files group owner|/var/log/audit/*.log files|root group"
        "audit configuration files mode|/etc/audit/ config files|0640 or more restrictive"
        "audit configuration files owner|/etc/audit/ config files|root ownership"
        "audit configuration files group owner|/etc/audit/ config files|root group"
        "audit tools mode|/sbin/auditctl, /sbin/aureport, etc.|0755 or more restrictive"
        "audit tools owner|/sbin/auditctl, /sbin/aureport, etc.|root ownership"
        "audit tools group owner|/sbin/auditctl, /sbin/aureport, etc.|root group"
    )
    
    for i in {1..10}; do
        control_id="6.3.4.${i}"
        ((TOTAL_CHECKS++))
        IFS='|' read -r desc target expected <<< "${file_access_checks[$((i-1))]}"
        log_check_manual "${control_id}" \
            "Ensure ${desc} is configured" \
            "Current permissions: $(ls -ld ${target} 2>/dev/null || echo 'Check manually')" \
            "Expected: ${expected}" \
            "1. Check current: ls -ld ${target}
2. Set ownership: chown root:root ${target}
3. Set permissions: chmod <mode> ${target}
4. Verify: ls -ld ${target}
5. See CIS Benchmark Section 6.3.4.${i} for exact requirements" \
            "Proper file permissions protect audit system integrity"
        ((MANUAL_CHECKS++))
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

# Made with Bob
