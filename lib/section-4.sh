#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 4: Firewall Configuration
# Version: 2.0.0
# Description: Implementation of CIS Section 4 controls
################################################################################

################################################################################
# SECTION 4.1: CONFIGURE FIREWALL SOFTWARE
################################################################################

remediate_firewall_software() {
    if ! should_run_section "4.1"; then
        log_info "Skipping Section 4.1: Configure Firewall Software (not selected)"
        return 0
    fi
    
    log_info "=== Section 4.1: Configure Firewall Software ==="
    
    # 4.1.1 - Ensure a single firewall configuration utility is in use
    local control_id="4.1.1"
    log_info "[${control_id}] Ensure a single firewall configuration utility is in use"
    ((TOTAL_CHECKS++))
    
    local firewalld_status=$(systemctl is-enabled firewalld 2>/dev/null || echo "disabled")
    local nftables_status=$(systemctl is-enabled nftables 2>/dev/null || echo "disabled")
    local iptables_status=$(systemctl is-enabled iptables 2>/dev/null || echo "disabled")
    
    local enabled_count=0
    [[ "${firewalld_status}" == "enabled" ]] && ((enabled_count++))
    [[ "${nftables_status}" == "enabled" ]] && ((enabled_count++))
    [[ "${iptables_status}" == "enabled" ]] && ((enabled_count++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if [[ ${enabled_count} -eq 1 ]]; then
            log_success "[${control_id}] PASS: Single firewall utility is in use"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Multiple or no firewall utilities enabled (count: ${enabled_count})"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    local current_state="Firewall utility status:
- firewalld: ${firewalld_status}
- nftables: ${nftables_status}
- iptables: ${iptables_status}
Enabled count: ${enabled_count}"
    
    log_check_manual "${control_id}" \
        "Ensure only one firewall utility (firewalld, nftables, or iptables) is enabled" \
        "${current_state}" \
        "Enable exactly one firewall utility and disable the others" \
        "1. Choose one firewall utility (firewalld, nftables, or iptables)
2. Enable the chosen utility: systemctl enable <utility>
3. Disable other utilities: systemctl disable <other-utilities>
4. Start the chosen utility: systemctl start <utility>
5. Verify only one is enabled: systemctl is-enabled firewalld nftables iptables" \
        "Running multiple firewall utilities simultaneously can cause conflicts and security gaps"
    ((MANUAL_CHECKS++))
}

################################################################################
# SECTION 4.2: CONFIGURE FIREWALLD
################################################################################

remediate_firewalld() {
    if ! should_run_section "4.2"; then
        log_info "Skipping Section 4.2: Configure firewalld (not selected)"
        return 0
    fi
    
    log_info "=== Section 4.2: Configure firewalld ==="
    
    # Check if firewalld is the chosen firewall
    if ! systemctl is-enabled firewalld &>/dev/null; then
        log_info "firewalld is not enabled, skipping Section 4.2"
        return 0
    fi
    
    # 4.2.1 - Ensure firewalld is installed
    local control_id="4.2.1"
    log_info "[${control_id}] Ensure firewalld is installed"
    ((TOTAL_CHECKS++))
    
    if rpm -q firewalld &>/dev/null; then
        log_success "[${control_id}] PASS: firewalld is installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: firewalld is not installed"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Install firewalld?"; then
        dnf install -y firewalld &>/dev/null
        log_success "[${control_id}] Remediated: firewalld installed"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 4.2.2 - Ensure firewalld service is enabled and running
    control_id="4.2.2"
    log_info "[${control_id}] Ensure firewalld service is enabled and running"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if systemctl is-enabled firewalld &>/dev/null && systemctl is-active firewalld &>/dev/null; then
            log_success "[${control_id}] PASS: firewalld is enabled and running"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: firewalld is not enabled or not running"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Enable and start firewalld?"; then
        systemctl unmask firewalld 2>/dev/null
        systemctl enable firewalld 2>/dev/null
        systemctl start firewalld 2>/dev/null
        log_success "[${control_id}] Remediated: firewalld enabled and started"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 4.2.3 - Ensure firewalld default zone is set
    control_id="4.2.3"
    log_info "[${control_id}] Ensure firewalld default zone is set"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local default_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
        if [[ -n "${default_zone}" ]]; then
            log_success "[${control_id}] PASS: Default zone is set to ${default_zone}"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: No default zone set"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Set default zone to 'public'?"; then
        firewall-cmd --set-default-zone=public 2>/dev/null
        log_success "[${control_id}] Remediated: Default zone set to public"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 4.2.4 - Ensure network interfaces are assigned to appropriate zone
    control_id="4.2.4"
    log_info "[${control_id}] Ensure network interfaces are assigned to appropriate zone"
    ((TOTAL_CHECKS++))
    
    local interface_zones=$(firewall-cmd --get-active-zones 2>/dev/null || echo "Unable to retrieve zone information")
    local default_zone=$(firewall-cmd --get-default-zone 2>/dev/null || echo "unknown")
    log_check_manual "${control_id}" \
        "Verify network interfaces are assigned to appropriate zones" \
        "Default zone: ${default_zone}
Active zones and interfaces:
${interface_zones}" \
        "Assign each network interface to an appropriate firewalld zone" \
        "1. List active zones: firewall-cmd --get-active-zones
2. List available zones: firewall-cmd --get-zones
3. Assign interface to zone: firewall-cmd --zone=<zone> --change-interface=<interface> --permanent
4. Reload firewalld: firewall-cmd --reload
5. Verify assignments: firewall-cmd --get-active-zones" \
        "Network interfaces should be assigned to zones that match their security requirements (e.g., public, internal, dmz)"
    ((MANUAL_CHECKS++))
    
    # 4.2.5 - Ensure firewalld drops unnecessary services and ports
    control_id="4.2.5"
    log_info "[${control_id}] Ensure firewalld drops unnecessary services and ports"
    ((TOTAL_CHECKS++))
    
    local active_services=$(firewall-cmd --list-services 2>/dev/null || echo "Unable to list services")
    local active_ports=$(firewall-cmd --list-ports 2>/dev/null || echo "Unable to list ports")
    log_check_manual "${control_id}" \
        "Review and remove unnecessary services and ports" \
        "Active services in default zone:
${active_services}

Active ports in default zone:
${active_ports}" \
        "Remove all unnecessary services and ports from firewalld" \
        "1. List services: firewall-cmd --list-services
2. List ports: firewall-cmd --list-ports
3. Remove service: firewall-cmd --remove-service=<service> --permanent
4. Remove port: firewall-cmd --remove-port=<port/protocol> --permanent
5. Reload firewalld: firewall-cmd --reload
6. Verify changes: firewall-cmd --list-all" \
        "Only services and ports required for business operations should be allowed through the firewall"
    ((MANUAL_CHECKS++))
}

################################################################################
# SECTION 4.3: CONFIGURE NFTABLES
################################################################################

remediate_nftables() {
    if ! should_run_section "4.3"; then
        log_info "Skipping Section 4.3: Configure nftables (not selected)"
        return 0
    fi
    
    log_info "=== Section 4.3: Configure nftables ==="
    
    # Check if nftables is the chosen firewall
    if ! systemctl is-enabled nftables &>/dev/null; then
        log_info "nftables is not enabled, skipping Section 4.3"
        return 0
    fi
    
    # 4.3.1 - Ensure nftables is installed
    local control_id="4.3.1"
    log_info "[${control_id}] Ensure nftables is installed"
    ((TOTAL_CHECKS++))
    
    if rpm -q nftables &>/dev/null; then
        log_success "[${control_id}] PASS: nftables is installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: nftables is not installed"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Install nftables?"; then
        dnf install -y nftables &>/dev/null
        log_success "[${control_id}] Remediated: nftables installed"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 4.3.2 - Ensure nftables service is enabled
    control_id="4.3.2"
    log_info "[${control_id}] Ensure nftables service is enabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if systemctl is-enabled nftables &>/dev/null; then
            log_success "[${control_id}] PASS: nftables is enabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: nftables is not enabled"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Enable nftables?"; then
        systemctl enable nftables 2>/dev/null
        log_success "[${control_id}] Remediated: nftables enabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 4.3.3 - Ensure nftables base chains exist
    control_id="4.3.3"
    log_info "[${control_id}] Ensure nftables base chains exist"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if nft list ruleset 2>/dev/null | grep -q "type filter hook"; then
            log_success "[${control_id}] PASS: nftables base chains exist"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: nftables base chains do not exist"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    local nft_tables=$(nft list tables 2>/dev/null || echo "No nftables configuration found")
    local nft_chains=$(nft list chains 2>/dev/null || echo "No chains configured")
    log_check_manual "${control_id}" \
        "Configure nftables base chains (input, forward, output)" \
        "Current nftables configuration:
Tables: ${nft_tables}
Chains: ${nft_chains}" \
        "Create and configure base chains for input, forward, and output traffic" \
        "1. Create a table: nft create table inet filter
2. Create base chains:
   nft create chain inet filter input { type filter hook input priority 0 \\; }
   nft create chain inet filter forward { type filter hook forward priority 0 \\; }
   nft create chain inet filter output { type filter hook output priority 0 \\; }
3. Save configuration: nft list ruleset > /etc/nftables/nftables.rules
4. Enable nftables: systemctl enable nftables" \
        "Base chains are required for nftables to filter network traffic"
    ((MANUAL_CHECKS++))
    
    # 4.3.4 - Ensure nftables loopback traffic is configured
    control_id="4.3.4"
    log_info "[${control_id}] Ensure nftables loopback traffic is configured"
    ((TOTAL_CHECKS++))
    
    local loopback_rules=$(nft list ruleset 2>/dev/null | grep -E "iif.*lo|oif.*lo" || echo "No loopback rules found")
    log_check_manual "${control_id}" \
        "Configure nftables to allow loopback traffic" \
        "Current loopback rules:
${loopback_rules}" \
        "Add rules to allow loopback traffic in nftables" \
        "1. Add input loopback rule: nft add rule inet filter input iif lo accept
2. Add output loopback rule: nft add rule inet filter output oif lo accept
3. Add rule to drop non-loopback traffic from 127.0.0.0/8:
   nft add rule inet filter input ip saddr 127.0.0.0/8 counter drop
4. Save configuration: nft list ruleset > /etc/nftables/nftables.rules" \
        "Loopback traffic must be allowed for proper system operation"
    ((MANUAL_CHECKS++))
    
    # 4.3.5 - Ensure nftables default deny firewall policy
    control_id="4.3.5"
    log_info "[${control_id}] Ensure nftables default deny firewall policy"
    ((TOTAL_CHECKS++))
    
    local chain_policies=$(nft list chains 2>/dev/null | grep -E "policy (accept|drop)" || echo "No chain policies found")
    log_check_manual "${control_id}" \
        "Set nftables default policy to drop" \
        "Current chain policies:
${chain_policies}" \
        "Set default policy to drop for all base chains" \
        "1. Set input chain policy: nft chain inet filter input { policy drop \\; }
2. Set forward chain policy: nft chain inet filter forward { policy drop \\; }
3. Set output chain policy: nft chain inet filter output { policy drop \\; }
4. Add rules to allow required traffic before setting drop policy
5. Save configuration: nft list ruleset > /etc/nftables/nftables.rules" \
        "Default deny policy ensures only explicitly allowed traffic is permitted"
    ((MANUAL_CHECKS++))
}

################################################################################
# SECTION 4 MAIN RUNNER
################################################################################

run_section_4() {
    remediate_firewall_software
    remediate_firewalld
    remediate_nftables
}

# Made with Bob
