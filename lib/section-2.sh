#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 2: Services
# Version: 2.0.0
# Description: Implementation of CIS Section 2 controls
#
# This module is sourced by rhel9-cis-compliance-modular.sh after lib/common.sh.
# It uses common.sh for logging, backups, interactive confirmation, selection,
# counters, and execution mode globals.
################################################################################

################################################################################
# SECTION 2 HELPERS
################################################################################

section_2_is_selected() {
    local selected

    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi

    for selected in "${SELECTED_SECTIONS[@]}"; do
        [[ "${selected}" == "2" || "${selected}" == 2.* ]] && return 0
    done

    return 1
}

should_run_section_2_check() {
    local check_id="$1"
    local selected

    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi

    for selected in "${SELECTED_SECTIONS[@]}"; do
        [[ "${selected}" == "2" ]] && return 0
        [[ "${check_id}" == "${selected}" ]] && return 0
        [[ "${check_id}" == "${selected}".* ]] && return 0
    done

    return 1
}

run_section_2_check() {
    local control_id="$1"
    local description="$2"
    local audit_fn="$3"
    local remediate_fn="$4"

    should_run_section_2_check "${control_id}" || return 0

    log_info "[${control_id}] ${description}"
    ((TOTAL_CHECKS++))

    if "${audit_fn}"; then
        log_success "[${control_id}] PASS: ${description}"
        ((PASSED_CHECKS++))
        return 0
    fi

    if [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: ${description}"
        ((FAILED_CHECKS++))
        return 0
    fi

    if confirm_action "[${control_id}] Remediate: ${description}?"; then
        if "${remediate_fn}" && "${audit_fn}"; then
            log_success "[${control_id}] Remediated: ${description}"
            ((REMEDIATED_CHECKS++))
        else
            log_warning "[${control_id}] Remediation attempted; verify manually"
            ((FAILED_CHECKS++))
        fi
    else
        log_warning "[${control_id}] SKIPPED: ${description}"
        ((FAILED_CHECKS++))
    fi
}

run_section_2_manual_check() {
    local control_id="$1"
    local description="$2"
    local audit_fn="$3"

    should_run_section_2_check "${control_id}" || return 0

    log_info "[${control_id}] ${description}"
    ((TOTAL_CHECKS++))

    if "${audit_fn}"; then
        log_success "[${control_id}] PASS: ${description}"
        ((PASSED_CHECKS++))
    else
        # Capture current state based on the specific check
        local current_state=""
        local required_action="${description}"
        local verification_steps=""
        local additional_info=""
        
        case "${control_id}" in
            "2.1.22")
                local listeners=$(ss -plntu 2>/dev/null | awk 'NR > 1' | grep -Ev '127\.0\.0\.1|::1|^[[:space:]]*$' || echo "No listeners found")
                local listener_count=$(echo "${listeners}" | grep -c "." || echo "0")
                current_state="Found ${listener_count} non-loopback network listener(s):
${listeners}"
                required_action="Review and approve all network listeners"
                verification_steps="1. Review the list of network listeners above
2. Identify each service and its purpose
3. Verify each listener is required for business operations
4. Disable or remove unauthorized services
5. Document approved services in your security policy"
                additional_info="Only services required for business operations should be listening on network interfaces. Unnecessary services increase the attack surface"
                ;;
            *)
                current_state="Manual review required - check current system configuration"
                verification_steps="1. Review the CIS Benchmark documentation for check ${control_id}
2. Assess current system configuration
3. Implement required changes per organizational policy
4. Document the configuration decisions made
5. Verify compliance with organizational security requirements"
                additional_info="This check requires manual review and configuration based on site-specific security policies"
                ;;
        esac
        
        log_check_manual "${control_id}" \
            "${description}" \
            "${current_state}" \
            "${required_action}" \
            "${verification_steps}" \
            "${additional_info}"
        ((MANUAL_CHECKS++))
    fi
}

package_not_installed() {
    local package="$1"
    ! rpm -q "${package}" &>/dev/null
}

service_not_active_or_enabled() {
    local unit="$1"
    ! systemctl is-active "${unit}" &>/dev/null && ! systemctl is-enabled "${unit}" &>/dev/null
}

remove_package() {
    local package="$1"

    if rpm -q "${package}" &>/dev/null; then
        dnf remove -y "${package}" &>/dev/null && \
            log_success "Removed package: ${package}" || \
            { log_error "Failed to remove package: ${package}"; return 1; }
    else
        log_info "Package not installed: ${package}"
    fi
}

disable_service() {
    local unit="$1"
    local mask="${2:-true}"

    if systemctl list-unit-files "${unit}" &>/dev/null || systemctl status "${unit}" &>/dev/null; then
        systemctl stop "${unit}" 2>/dev/null || true
        systemctl disable "${unit}" 2>/dev/null || true
        [[ "${mask}" == true ]] && systemctl mask "${unit}" 2>/dev/null || true
        log_success "Stopped and disabled service: ${unit}"
    else
        log_info "Service not present: ${unit}"
    fi
}

ensure_package_installed() {
    local package="$1"

    if rpm -q "${package}" &>/dev/null; then
        log_info "Package already installed: ${package}"
        return 0
    fi

    dnf install -y "${package}" &>/dev/null && \
        log_success "Installed package: ${package}" || \
        { log_error "Failed to install package: ${package}"; return 1; }
}

ensure_service_enabled_now() {
    local unit="$1"

    systemctl unmask "${unit}" 2>/dev/null || true
    systemctl enable --now "${unit}" &>/dev/null && \
        log_success "Enabled and started service: ${unit}" || \
        { log_error "Failed to enable and start service: ${unit}"; return 1; }
}

set_or_append_key_value() {
    local file="$1"
    local key="$2"
    local value="$3"

    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "${file}" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key} = ${value}|" "${file}"
    else
        printf '%s = %s\n' "${key}" "${value}" >> "${file}"
    fi
}

check_path_owner_mode() {
    local path="$1"
    local owner="$2"
    local group="$3"
    local max_mode="$4"
    local actual_owner actual_group actual_mode

    [[ -e "${path}" ]] || return 1

    actual_owner="$(stat -c '%U' "${path}")"
    actual_group="$(stat -c '%G' "${path}")"
    actual_mode="$(stat -c '%a' "${path}")"

    [[ "${actual_owner}" == "${owner}" ]] && \
        [[ "${actual_group}" == "${group}" ]] && \
        (( 8#${actual_mode} <= 8#${max_mode} ))
}

fix_path_owner_mode() {
    local path="$1"
    local owner="$2"
    local group="$3"
    local mode="$4"

    [[ -e "${path}" ]] || return 0
    backup_file "${path}" 2>/dev/null || true
    chown "${owner}:${group}" "${path}"
    chmod "${mode}" "${path}"
    log_success "Configured ${path}: ${owner}:${group} ${mode}"
}

################################################################################
# 2.1 CONFIGURE SERVER SERVICES
################################################################################

audit_2_1_1() { package_not_installed autofs || service_not_active_or_enabled autofs; }
remediate_2_1_1() { disable_service autofs true; remove_package autofs; }

audit_2_1_2() { ( package_not_installed avahi && package_not_installed avahi-autoipd ) || ( service_not_active_or_enabled avahi-daemon.service && service_not_active_or_enabled avahi-daemon.socket ); }
remediate_2_1_2() { disable_service avahi-daemon.service true; disable_service avahi-daemon.socket true; remove_package avahi; remove_package avahi-autoipd; }

audit_2_1_3() { package_not_installed dhcp-server || ( service_not_active_or_enabled dhcpd && service_not_active_or_enabled dhcpd6 ); }
remediate_2_1_3() { disable_service dhcpd true; disable_service dhcpd6 true; remove_package dhcp-server; }

audit_2_1_4() { package_not_installed bind || service_not_active_or_enabled named; }
remediate_2_1_4() { disable_service named true; remove_package bind; }

audit_2_1_5() { package_not_installed dnsmasq || service_not_active_or_enabled dnsmasq; }
remediate_2_1_5() { disable_service dnsmasq true; remove_package dnsmasq; }

audit_2_1_6() { package_not_installed samba || ( service_not_active_or_enabled smb && service_not_active_or_enabled nmb ); }
remediate_2_1_6() { disable_service smb true; disable_service nmb true; remove_package samba; }

audit_2_1_7() { package_not_installed vsftpd || service_not_active_or_enabled vsftpd; }
remediate_2_1_7() { disable_service vsftpd true; remove_package vsftpd; }

audit_2_1_8() { ( package_not_installed dovecot && package_not_installed cyrus-imapd ) || ( service_not_active_or_enabled dovecot && service_not_active_or_enabled cyrus-imapd ); }
remediate_2_1_8() { disable_service dovecot true; disable_service cyrus-imapd true; remove_package dovecot; remove_package cyrus-imapd; }

audit_2_1_9() { package_not_installed nfs-utils || service_not_active_or_enabled nfs-server; }
remediate_2_1_9() { disable_service nfs-server true; remove_package nfs-utils; }

audit_2_1_10() { package_not_installed ypserv || service_not_active_or_enabled ypserv; }
remediate_2_1_10() { disable_service ypserv true; remove_package ypserv; }

audit_2_1_11() { package_not_installed cups || service_not_active_or_enabled cups; }
remediate_2_1_11() { disable_service cups true; remove_package cups; }

audit_2_1_12() { package_not_installed rpcbind || ( service_not_active_or_enabled rpcbind.service && service_not_active_or_enabled rpcbind.socket ); }
remediate_2_1_12() { disable_service rpcbind.service true; disable_service rpcbind.socket true; remove_package rpcbind; }

audit_2_1_13() { package_not_installed rsync-daemon || service_not_active_or_enabled rsyncd; }
remediate_2_1_13() { disable_service rsyncd true; remove_package rsync-daemon; }

audit_2_1_14() { package_not_installed net-snmp || service_not_active_or_enabled snmpd; }
remediate_2_1_14() { disable_service snmpd true; remove_package net-snmp; }

audit_2_1_15() { package_not_installed telnet-server || service_not_active_or_enabled telnet.socket; }
remediate_2_1_15() { disable_service telnet.socket true; remove_package telnet-server; }

audit_2_1_16() { package_not_installed tftp-server || ( service_not_active_or_enabled tftp.socket && service_not_active_or_enabled tftp.service ); }
remediate_2_1_16() { disable_service tftp.socket true; disable_service tftp.service true; remove_package tftp-server; }

audit_2_1_17() { package_not_installed squid || service_not_active_or_enabled squid; }
remediate_2_1_17() { disable_service squid true; remove_package squid; }

audit_2_1_18() { ( package_not_installed httpd || service_not_active_or_enabled httpd ) && ( package_not_installed nginx || service_not_active_or_enabled nginx ); }
remediate_2_1_18() { disable_service httpd true; disable_service nginx true; remove_package httpd; remove_package nginx; }

audit_2_1_19() { package_not_installed xinetd || service_not_active_or_enabled xinetd; }
remediate_2_1_19() { disable_service xinetd true; remove_package xinetd; }

audit_2_1_20() {
    package_not_installed xorg-x11-server-common || [[ "$(systemctl get-default 2>/dev/null)" != "graphical.target" ]]
}
remediate_2_1_20() {
    remove_package xorg-x11-server-common
    if [[ "$(systemctl get-default 2>/dev/null)" == "graphical.target" ]]; then
        systemctl set-default multi-user.target
        log_success "Default target set to multi-user.target"
    fi
}

audit_2_1_21() {
    package_not_installed postfix || grep -qE '^[[:space:]]*inet_interfaces[[:space:]]*=[[:space:]]*loopback-only' /etc/postfix/main.cf 2>/dev/null
}
remediate_2_1_21() {
    local config="/etc/postfix/main.cf"

    if package_not_installed postfix; then
        log_info "Postfix is not installed"
        return 0
    fi

    [[ -f "${config}" ]] || { log_error "${config} not found"; return 1; }
    backup_file "${config}"
    set_or_append_key_value "${config}" inet_interfaces loopback-only
    set_or_append_key_value "${config}" inet_protocols all
    systemctl restart postfix 2>/dev/null || true
}

audit_2_1_22() {
    local listeners

    listeners="$(ss -plntu 2>/dev/null | awk 'NR > 1' | grep -Ev '127\.0\.0\.1|::1|^[[:space:]]*$' || true)"
    if [[ -n "${listeners}" ]]; then
        log_info "Active non-loopback listeners:"
        while IFS= read -r line; do
            [[ -n "${line}" ]] && log_info "  ${line}"
        done <<< "${listeners}"
        log_warning "Verify every listed listener is approved for this server"
        return 1
    fi

    return 0
}

################################################################################
# 2.2 CONFIGURE CLIENT SERVICES
################################################################################

audit_2_2_1() { package_not_installed ftp; }
remediate_2_2_1() { remove_package ftp; }

audit_2_2_2() { package_not_installed openldap-clients; }
remediate_2_2_2() { remove_package openldap-clients; }

audit_2_2_3() { package_not_installed ypbind; }
remediate_2_2_3() { remove_package ypbind; }

audit_2_2_4() { package_not_installed telnet; }
remediate_2_2_4() { remove_package telnet; }

audit_2_2_5() { package_not_installed tftp; }
remediate_2_2_5() { remove_package tftp; }

################################################################################
# 2.3 CONFIGURE TIME SYNCHRONIZATION
################################################################################

audit_2_3_1() {
    rpm -q chrony &>/dev/null && \
        systemctl is-enabled chronyd &>/dev/null && \
        systemctl is-active chronyd &>/dev/null && \
        package_not_installed ntp
}
remediate_2_3_1() {
    if rpm -q ntp &>/dev/null; then
        disable_service ntpd true
        remove_package ntp
    fi

    ensure_package_installed chrony
    ensure_service_enabled_now chronyd
}

audit_2_3_2() {
    grep -qE '^[[:space:]]*(pool|server)[[:space:]]+' /etc/chrony.conf 2>/dev/null
}
remediate_2_3_2() {
    local config="/etc/chrony.conf"

    [[ -f "${config}" ]] || { log_error "${config} not found"; return 1; }
    backup_file "${config}"
    sed -i '/^[[:space:]]*\(pool\|server\)[[:space:]]/d' "${config}"
    printf '%s\n' '# CIS 2.3.2 - Replace with approved organizational NTP sources' >> "${config}"
    printf '%s\n' 'pool 2.rhel.pool.ntp.org iburst' >> "${config}"
    systemctl restart chronyd 2>/dev/null || true
    log_warning "Replace the chrony pool with your organization-approved NTP source"
}

audit_2_3_3() {
    grep -qE '^[[:space:]]*OPTIONS=.*-u[[:space:]]+chrony' /etc/sysconfig/chronyd 2>/dev/null
}
remediate_2_3_3() {
    local config="/etc/sysconfig/chronyd"

    [[ -f "${config}" ]] && backup_file "${config}"

    if [[ -f "${config}" ]] && grep -qE '^[[:space:]]*OPTIONS=' "${config}"; then
        if ! grep -qE '^[[:space:]]*OPTIONS=.*-u[[:space:]]+chrony' "${config}"; then
            sed -i 's/^\([[:space:]]*OPTIONS="[^"]*\)"/\1 -u chrony"/' "${config}"
        fi
    else
        printf '%s\n' 'OPTIONS="-u chrony"' >> "${config}"
    fi

    systemctl restart chronyd 2>/dev/null || true
}

################################################################################
# 2.4 CONFIGURE JOB SCHEDULERS
################################################################################

audit_2_4_1() {
    rpm -q cronie &>/dev/null && \
        systemctl is-enabled crond &>/dev/null && \
        systemctl is-active crond &>/dev/null
}
remediate_2_4_1() {
    ensure_package_installed cronie
    ensure_service_enabled_now crond
}

audit_2_4_2() { check_path_owner_mode /etc/crontab root root 600; }
remediate_2_4_2() { fix_path_owner_mode /etc/crontab root root 600; }

audit_2_4_3() { check_path_owner_mode /etc/cron.hourly root root 700; }
remediate_2_4_3() { fix_path_owner_mode /etc/cron.hourly root root 700; }

audit_2_4_4() { check_path_owner_mode /etc/cron.daily root root 700; }
remediate_2_4_4() { fix_path_owner_mode /etc/cron.daily root root 700; }

audit_2_4_5() { check_path_owner_mode /etc/cron.weekly root root 700; }
remediate_2_4_5() { fix_path_owner_mode /etc/cron.weekly root root 700; }

audit_2_4_6() { check_path_owner_mode /etc/cron.monthly root root 700; }
remediate_2_4_6() { fix_path_owner_mode /etc/cron.monthly root root 700; }

audit_2_4_7() { check_path_owner_mode /etc/cron.d root root 700; }
remediate_2_4_7() { fix_path_owner_mode /etc/cron.d root root 700; }

audit_2_4_8() {
    [[ ! -f /etc/cron.deny ]] && [[ -f /etc/cron.allow ]] && check_path_owner_mode /etc/cron.allow root root 640
}
remediate_2_4_8() {
    backup_file /etc/cron.deny 2>/dev/null || true
    rm -f /etc/cron.deny
    [[ -f /etc/cron.allow ]] || touch /etc/cron.allow
    fix_path_owner_mode /etc/cron.allow root root 640
    log_warning "Populate /etc/cron.allow with authorized users"
}

audit_2_4_9() {
    package_not_installed at && return 0
    [[ ! -f /etc/at.deny ]] && [[ -f /etc/at.allow ]] && check_path_owner_mode /etc/at.allow root root 640
}
remediate_2_4_9() {
    if package_not_installed at; then
        log_info "at is not installed; skipping at access restriction"
        return 0
    fi

    backup_file /etc/at.deny 2>/dev/null || true
    rm -f /etc/at.deny
    [[ -f /etc/at.allow ]] || touch /etc/at.allow
    fix_path_owner_mode /etc/at.allow root root 640
    log_warning "Populate /etc/at.allow with authorized users"
}

################################################################################
# SECTION 2 MAIN RUNNER
################################################################################

run_section_2() {
    if ! section_2_is_selected; then
        log_info "Skipping Section 2: Services (not selected)"
        return 0
    fi

    log_info "=== Section 2: Services ==="

    log_info "--- 2.1 Configure Server Services ---"
    run_section_2_check "2.1.1" "Ensure autofs services are not in use" audit_2_1_1 remediate_2_1_1
    run_section_2_check "2.1.2" "Ensure avahi daemon services are not in use" audit_2_1_2 remediate_2_1_2
    run_section_2_check "2.1.3" "Ensure dhcp server services are not in use" audit_2_1_3 remediate_2_1_3
    run_section_2_check "2.1.4" "Ensure dns server services are not in use" audit_2_1_4 remediate_2_1_4
    run_section_2_check "2.1.5" "Ensure dnsmasq services are not in use" audit_2_1_5 remediate_2_1_5
    run_section_2_check "2.1.6" "Ensure samba file server services are not in use" audit_2_1_6 remediate_2_1_6
    run_section_2_check "2.1.7" "Ensure ftp server services are not in use" audit_2_1_7 remediate_2_1_7
    run_section_2_check "2.1.8" "Ensure message access server services are not in use" audit_2_1_8 remediate_2_1_8
    run_section_2_check "2.1.9" "Ensure network file system services are not in use" audit_2_1_9 remediate_2_1_9
    run_section_2_check "2.1.10" "Ensure nis server services are not in use" audit_2_1_10 remediate_2_1_10
    run_section_2_check "2.1.11" "Ensure print server services are not in use" audit_2_1_11 remediate_2_1_11
    run_section_2_check "2.1.12" "Ensure rpcbind services are not in use" audit_2_1_12 remediate_2_1_12
    run_section_2_check "2.1.13" "Ensure rsync services are not in use" audit_2_1_13 remediate_2_1_13
    run_section_2_check "2.1.14" "Ensure snmp services are not in use" audit_2_1_14 remediate_2_1_14
    run_section_2_check "2.1.15" "Ensure telnet server services are not in use" audit_2_1_15 remediate_2_1_15
    run_section_2_check "2.1.16" "Ensure tftp server services are not in use" audit_2_1_16 remediate_2_1_16
    run_section_2_check "2.1.17" "Ensure web proxy server services are not in use" audit_2_1_17 remediate_2_1_17
    run_section_2_check "2.1.18" "Ensure web server services are not in use" audit_2_1_18 remediate_2_1_18
    run_section_2_check "2.1.19" "Ensure xinetd services are not in use" audit_2_1_19 remediate_2_1_19
    run_section_2_check "2.1.20" "Ensure X window server services are not in use" audit_2_1_20 remediate_2_1_20
    run_section_2_check "2.1.21" "Ensure mail transfer agent is configured for local-only mode" audit_2_1_21 remediate_2_1_21
    run_section_2_manual_check "2.1.22" "Ensure only approved services are listening on a network interface" audit_2_1_22

    log_info "--- 2.2 Configure Client Services ---"
    run_section_2_check "2.2.1" "Ensure ftp client is not installed" audit_2_2_1 remediate_2_2_1
    run_section_2_check "2.2.2" "Ensure ldap client is not installed" audit_2_2_2 remediate_2_2_2
    run_section_2_check "2.2.3" "Ensure nis client is not installed" audit_2_2_3 remediate_2_2_3
    run_section_2_check "2.2.4" "Ensure telnet client is not installed" audit_2_2_4 remediate_2_2_4
    run_section_2_check "2.2.5" "Ensure tftp client is not installed" audit_2_2_5 remediate_2_2_5

    log_info "--- 2.3 Configure Time Synchronization ---"
    run_section_2_check "2.3.1" "Ensure a single time synchronization daemon is in use" audit_2_3_1 remediate_2_3_1
    run_section_2_check "2.3.2" "Ensure chrony is configured with authorized timeservers" audit_2_3_2 remediate_2_3_2
    run_section_2_check "2.3.3" "Ensure chrony is not run as the root user" audit_2_3_3 remediate_2_3_3

    log_info "--- 2.4 Configure Job Schedulers ---"
    run_section_2_check "2.4.1.1" "Ensure cron daemon is enabled and active" audit_2_4_1 remediate_2_4_1
    run_section_2_check "2.4.1.2" "Ensure permissions on /etc/crontab are configured" audit_2_4_2 remediate_2_4_2
    run_section_2_check "2.4.1.3" "Ensure permissions on /etc/cron.hourly are configured" audit_2_4_3 remediate_2_4_3
    run_section_2_check "2.4.1.4" "Ensure permissions on /etc/cron.daily are configured" audit_2_4_4 remediate_2_4_4
    run_section_2_check "2.4.1.5" "Ensure permissions on /etc/cron.weekly are configured" audit_2_4_5 remediate_2_4_5
    run_section_2_check "2.4.1.6" "Ensure permissions on /etc/cron.monthly are configured" audit_2_4_6 remediate_2_4_6
    run_section_2_check "2.4.1.7" "Ensure permissions on /etc/cron.d are configured" audit_2_4_7 remediate_2_4_7
    run_section_2_check "2.4.1.8" "Ensure crontab is restricted to authorized users" audit_2_4_8 remediate_2_4_8
    run_section_2_check "2.4.2.1" "Ensure at is restricted to authorized users" audit_2_4_9 remediate_2_4_9

    log_info "=== Section 2: Services complete ==="
}
