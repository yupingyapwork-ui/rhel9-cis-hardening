#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 3: Network Configuration
# Version: 2.0.0
# Description: Implementation of CIS Section 3 controls
################################################################################

################################################################################
# SECTION 3.1: DISABLE UNUSED NETWORK PROTOCOLS
################################################################################

remediate_unused_protocols() {
    if ! should_run_section "3.1"; then
        log_info "Skipping Section 3.1: Disable Unused Network Protocols (not selected)"
        return 0
    fi
    
    log_info "=== Section 3.1: Disable Unused Network Protocols ==="
    
    # 3.1.1 - Ensure DCCP is disabled
    local control_id="3.1.1"
    log_info "[${control_id}] Ensure DCCP is disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if lsmod | grep -q "^dccp"; then
            log_warning "[${control_id}] FAIL: DCCP module is loaded"
            ((FAILED_CHECKS++))
        else
            log_success "[${control_id}] PASS: DCCP module is not loaded"
            ((PASSED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Disable DCCP protocol?"; then
        backup_file "/etc/modprobe.d/dccp.conf"
        cat > /etc/modprobe.d/dccp.conf << 'EOF'
# CIS Benchmark - Disable DCCP
install dccp /bin/true
blacklist dccp
EOF
        rmmod dccp 2>/dev/null || true
        log_success "[${control_id}] Remediated: DCCP disabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 3.1.2 - Ensure SCTP is disabled
    control_id="3.1.2"
    log_info "[${control_id}] Ensure SCTP is disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if lsmod | grep -q "^sctp"; then
            log_warning "[${control_id}] FAIL: SCTP module is loaded"
            ((FAILED_CHECKS++))
        else
            log_success "[${control_id}] PASS: SCTP module is not loaded"
            ((PASSED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Disable SCTP protocol?"; then
        backup_file "/etc/modprobe.d/sctp.conf"
        cat > /etc/modprobe.d/sctp.conf << 'EOF'
# CIS Benchmark - Disable SCTP
install sctp /bin/true
blacklist sctp
EOF
        rmmod sctp 2>/dev/null || true
        log_success "[${control_id}] Remediated: SCTP disabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 3.1.3 - Ensure RDS is disabled
    control_id="3.1.3"
    log_info "[${control_id}] Ensure RDS is disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if lsmod | grep -q "^rds"; then
            log_warning "[${control_id}] FAIL: RDS module is loaded"
            ((FAILED_CHECKS++))
        else
            log_success "[${control_id}] PASS: RDS module is not loaded"
            ((PASSED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Disable RDS protocol?"; then
        backup_file "/etc/modprobe.d/rds.conf"
        cat > /etc/modprobe.d/rds.conf << 'EOF'
# CIS Benchmark - Disable RDS
install rds /bin/true
blacklist rds
EOF
        rmmod rds 2>/dev/null || true
        log_success "[${control_id}] Remediated: RDS disabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 3.1.4 - Ensure TIPC is disabled
    control_id="3.1.4"
    log_info "[${control_id}] Ensure TIPC is disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if lsmod | grep -q "^tipc"; then
            log_warning "[${control_id}] FAIL: TIPC module is loaded"
            ((FAILED_CHECKS++))
        else
            log_success "[${control_id}] PASS: TIPC module is not loaded"
            ((PASSED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Disable TIPC protocol?"; then
        backup_file "/etc/modprobe.d/tipc.conf"
        cat > /etc/modprobe.d/tipc.conf << 'EOF'
# CIS Benchmark - Disable TIPC
install tipc /bin/true
blacklist tipc
EOF
        rmmod tipc 2>/dev/null || true
        log_success "[${control_id}] Remediated: TIPC disabled"
        ((REMEDIATED_CHECKS++))
    fi
}

################################################################################
# SECTION 3.2: NETWORK PARAMETERS (HOST ONLY)
################################################################################

set_sysctl_parameter() {
    local param="$1"
    local value="$2"
    local control_id="$3"
    
    if [[ "${DRY_RUN}" == true ]]; then
        local current_value=$(sysctl -n "${param}" 2>/dev/null)
        if [[ "${current_value}" == "${value}" ]]; then
            log_success "[${control_id}] PASS: ${param} = ${value}"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${param} = ${current_value} (expected ${value})"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Set ${param} = ${value}?"; then
        backup_file "/etc/sysctl.conf"
        backup_file "/etc/sysctl.d/99-cis.conf"
        
        # Set runtime value
        sysctl -w "${param}=${value}" &>/dev/null
        
        # Set persistent value
        mkdir -p /etc/sysctl.d
        if grep -q "^${param}" /etc/sysctl.d/99-cis.conf 2>/dev/null; then
            sed -i "s|^${param}.*|${param} = ${value}|" /etc/sysctl.d/99-cis.conf
        else
            echo "${param} = ${value}" >> /etc/sysctl.d/99-cis.conf
        fi
        
        log_success "[${control_id}] Remediated: ${param} = ${value}"
        ((REMEDIATED_CHECKS++))
    fi
}

remediate_network_parameters() {
    if ! should_run_section "3.2"; then
        log_info "Skipping Section 3.2: Network Parameters (not selected)"
        return 0
    fi
    
    log_info "=== Section 3.2: Network Parameters (Host Only) ==="
    
    # 3.2.1 - Ensure IP forwarding is disabled
    local control_id="3.2.1"
    log_info "[${control_id}] Ensure IP forwarding is disabled"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.ip_forward" "0" "${control_id}"
    
    # 3.2.2 - Ensure packet redirect sending is disabled
    control_id="3.2.2"
    log_info "[${control_id}] Ensure packet redirect sending is disabled"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.all.send_redirects" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.default.send_redirects" "0" "${control_id}"
}

################################################################################
# SECTION 3.3: NETWORK PARAMETERS (HOST AND ROUTER)
################################################################################

remediate_network_parameters_host_router() {
    if ! should_run_section "3.3"; then
        log_info "Skipping Section 3.3: Network Parameters (Host and Router) (not selected)"
        return 0
    fi
    
    log_info "=== Section 3.3: Network Parameters (Host and Router) ==="
    
    # 3.3.1 - Ensure source routed packets are not accepted
    local control_id="3.3.1"
    log_info "[${control_id}] Ensure source routed packets are not accepted"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.all.accept_source_route" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.default.accept_source_route" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv6.conf.all.accept_source_route" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv6.conf.default.accept_source_route" "0" "${control_id}"
    
    # 3.3.2 - Ensure ICMP redirects are not accepted
    control_id="3.3.2"
    log_info "[${control_id}] Ensure ICMP redirects are not accepted"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.all.accept_redirects" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.default.accept_redirects" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv6.conf.all.accept_redirects" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv6.conf.default.accept_redirects" "0" "${control_id}"
    
    # 3.3.3 - Ensure secure ICMP redirects are not accepted
    control_id="3.3.3"
    log_info "[${control_id}] Ensure secure ICMP redirects are not accepted"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.all.secure_redirects" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.default.secure_redirects" "0" "${control_id}"
    
    # 3.3.4 - Ensure suspicious packets are logged
    control_id="3.3.4"
    log_info "[${control_id}] Ensure suspicious packets are logged"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.all.log_martians" "1" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.default.log_martians" "1" "${control_id}"
    
    # 3.3.5 - Ensure broadcast ICMP requests are ignored
    control_id="3.3.5"
    log_info "[${control_id}] Ensure broadcast ICMP requests are ignored"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.icmp_echo_ignore_broadcasts" "1" "${control_id}"
    
    # 3.3.6 - Ensure bogus ICMP responses are ignored
    control_id="3.3.6"
    log_info "[${control_id}] Ensure bogus ICMP responses are ignored"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.icmp_ignore_bogus_error_responses" "1" "${control_id}"
    
    # 3.3.7 - Ensure Reverse Path Filtering is enabled
    control_id="3.3.7"
    log_info "[${control_id}] Ensure Reverse Path Filtering is enabled"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.all.rp_filter" "1" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.conf.default.rp_filter" "1" "${control_id}"
    
    # 3.3.8 - Ensure TCP SYN Cookies is enabled
    control_id="3.3.8"
    log_info "[${control_id}] Ensure TCP SYN Cookies is enabled"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv4.tcp_syncookies" "1" "${control_id}"
    
    # 3.3.9 - Ensure IPv6 router advertisements are not accepted
    control_id="3.3.9"
    log_info "[${control_id}] Ensure IPv6 router advertisements are not accepted"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv6.conf.all.accept_ra" "0" "${control_id}"
    ((TOTAL_CHECKS++))
    set_sysctl_parameter "net.ipv6.conf.default.accept_ra" "0" "${control_id}"
}

################################################################################
# SECTION 3 MAIN RUNNER
################################################################################

run_section_3() {
    remediate_unused_protocols
    remediate_network_parameters
    remediate_network_parameters_host_router
}


