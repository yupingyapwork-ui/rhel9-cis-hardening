#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 3: Network
# Version: 2.0.0
# Description: Implementation of CIS Section 3 controls
################################################################################

################################################################################
# SECTION 3 HELPERS
################################################################################

section3_group_selected() {
    local group="$1"
    local selected

    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi

    for selected in "${SELECTED_SECTIONS[@]}"; do
        [[ "${selected}" == "3" ]] && return 0
        [[ "${selected}" == "${group}" ]] && return 0
        [[ "${selected}" == "${group}".* ]] && return 0
        [[ "${group}" == "${selected}".* ]] && return 0
    done

    return 1
}

section3_check_selected() {
    local control_id="$1"
    local selected

    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi

    for selected in "${SELECTED_SECTIONS[@]}"; do
        [[ "${selected}" == "3" ]] && return 0
        [[ "${control_id}" == "${selected}" ]] && return 0
        [[ "${control_id}" == "${selected}".* ]] && return 0
    done

    return 1
}

ipv6_disabled() {
    if [[ -r /sys/module/ipv6/parameters/disable ]] &&
       ! grep -Pqs '^\s*0\b' /sys/module/ipv6/parameters/disable; then
        return 0
    fi

    [[ "$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null)" == "1" ]] &&
        [[ "$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null)" == "1" ]]
}

section3_run_check() {
    local control_id="$1"
    local description="$2"
    local audit_fn="$3"
    local remediate_fn="$4"

    section3_check_selected "${control_id}" || return 0

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

module_disabled_or_unavailable() {
    local module="$1"
    local modprobe_output

    if lsmod | awk '{print $1}' | grep -Fxq "${module}"; then
        return 1
    fi

    modprobe_output="$(modprobe -n -v "${module}" 2>&1 || true)"
    if grep -Eiq "FATAL: Module ${module} not found|Module ${module} not found" <<< "${modprobe_output}"; then
        return 0
    fi

    grep -Eq "install[[:space:]]+/bin/(true|false)" <<< "${modprobe_output}" &&
        modprobe --showconfig 2>/dev/null | grep -Eq "^[[:space:]]*blacklist[[:space:]]+${module//-/_}\\b"
}

module_disabled() {
    local module="$1"
    local modprobe_output

    if lsmod | awk '{print $1}' | grep -Fxq "${module}"; then
        return 1
    fi

    modprobe_output="$(modprobe -n -v "${module}" 2>&1 || true)"
    grep -Eq "install[[:space:]]+/bin/(true|false)" <<< "${modprobe_output}" &&
        modprobe --showconfig 2>/dev/null | grep -Eq "^[[:space:]]*blacklist[[:space:]]+${module//-/_}\\b"
}

escape_ere() {
    printf '%s' "$1" | sed 's/[][(){}.^$*+?|\\]/\\&/g'
}

escape_sed_replacement() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

set_or_append_sysctl_parameter() {
    local file="$1"
    local parameter="$2"
    local value="$3"
    local parameter_regex
    local replacement

    parameter_regex="$(escape_ere "${parameter}")"
    replacement="$(escape_sed_replacement "${parameter} = ${value}")"

    if grep -qE "^[[:space:]]*${parameter_regex}[[:space:]]*=" "${file}" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${parameter_regex}[[:space:]]*=.*|${replacement}|" "${file}"
    else
        printf '%s = %s\n' "${parameter}" "${value}" >> "${file}"
    fi
}

disable_kernel_module() {
    local module="$1"
    local config="/etc/modprobe.d/${module}.conf"

    backup_file "${config}"
    cat > "${config}" << EOF
# CIS Benchmark - Disable ${module}
install ${module} /bin/false
blacklist ${module}
EOF
    modprobe -r "${module}" 2>/dev/null || true
    rmmod "${module}" 2>/dev/null || true
}

audit_sysctl_parameters() {
    local expected parameter expected_value current_value

    for expected in "$@"; do
        parameter="${expected%%=*}"
        expected_value="${expected#*=}"

        if [[ "${parameter}" == net.ipv6.* ]] && ipv6_disabled; then
            log_info "IPv6 is disabled; ${parameter} is not applicable"
            continue
        fi

        current_value="$(sysctl -n "${parameter}" 2>/dev/null || true)"
        if [[ "${current_value}" != "${expected_value}" ]]; then
            log_warning "${parameter} = ${current_value:-unavailable} (expected ${expected_value})"
            return 1
        fi
    done

    return 0
}

set_sysctl_parameters() {
    local expected parameter expected_value

    backup_file "/etc/sysctl.conf"
    backup_file "/etc/sysctl.d/99-cis.conf"
    mkdir -p /etc/sysctl.d

    for expected in "$@"; do
        parameter="${expected%%=*}"
        expected_value="${expected#*=}"

        if [[ "${parameter}" == net.ipv6.* ]] && ipv6_disabled; then
            log_info "IPv6 is disabled; skipping ${parameter}"
            continue
        fi

        sysctl -w "${parameter}=${expected_value}" &>/dev/null || true
        set_or_append_sysctl_parameter "/etc/sysctl.d/99-cis.conf" "${parameter}" "${expected_value}"
    done

    sysctl -w net.ipv4.route.flush=1 &>/dev/null || true
    if ! ipv6_disabled; then
        sysctl -w net.ipv6.route.flush=1 &>/dev/null || true
    fi
}

wireless_modules() {
    local wireless_dir

    find /sys/class/net/*/ -type d -name wireless 2>/dev/null | while IFS= read -r wireless_dir; do
        readlink -f "${wireless_dir}/../device/driver/module" 2>/dev/null | xargs -r basename
    done | sort -u
}

audit_wireless_disabled() {
    local module
    local found_module=false

    while IFS= read -r module; do
        [[ -n "${module}" ]] || continue
        found_module=true
        module_disabled "${module}" || return 1
    done < <(wireless_modules)

    [[ "${found_module}" == true ]] || return 0
}

remediate_wireless_disabled() {
    local module

    while IFS= read -r module; do
        [[ -n "${module}" ]] || continue
        disable_kernel_module "${module}"
    done < <(wireless_modules)
}

audit_bluetooth_not_in_use() {
    rpm -q bluez &>/dev/null || return 0

    ! systemctl is-enabled bluetooth.service 2>/dev/null | grep -q '^enabled' &&
        ! systemctl is-active bluetooth.service 2>/dev/null | grep -q '^active'
}

remediate_bluetooth_not_in_use() {
    systemctl stop bluetooth.service 2>/dev/null || true
    systemctl mask bluetooth.service 2>/dev/null || true

    if rpm -q bluez &>/dev/null; then
        dnf remove -y bluez &>/dev/null || log_warning "bluez package could not be removed; bluetooth.service has been masked"
    fi
}

################################################################################
# SECTION 3.1: CONFIGURE NETWORK DEVICES
################################################################################

remediate_network_devices() {
    if ! section3_group_selected "3.1"; then
        log_info "Skipping Section 3.1: Configure Network Devices (not selected)"
        return 0
    fi

    log_info "=== Section 3.1: Configure Network Devices ==="

    local control_id="3.1.1"
    if section3_check_selected "${control_id}"; then
        log_info "[${control_id}] Ensure IPv6 status is identified"
        ((TOTAL_CHECKS++))
        log_check_manual "${control_id}" \
            "Ensure IPv6 status is identified" \
            "IPv6 module disable flag: $(cat /sys/module/ipv6/parameters/disable 2>/dev/null || echo 'unavailable')
net.ipv6.conf.all.disable_ipv6 = $(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 'unavailable')
net.ipv6.conf.default.disable_ipv6 = $(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null || echo 'unavailable')" \
            "Document whether IPv6 is enabled or disabled for this system" \
            "1. Review the current IPv6 status above
2. Document the approved IPv6 state in system security records
3. If IPv6 is disabled, treat IPv6-specific kernel parameters as not applicable
4. If IPv6 is enabled, verify the IPv6 controls in Section 3.3" \
            "CIS marks this control as manual because IPv6 enablement is a site-policy decision"
        ((MANUAL_CHECKS++))
    fi

    section3_run_check "3.1.2" "Ensure wireless interfaces are disabled" audit_wireless_disabled remediate_wireless_disabled
    section3_run_check "3.1.3" "Ensure bluetooth services are not in use" audit_bluetooth_not_in_use remediate_bluetooth_not_in_use
}

################################################################################
# SECTION 3.2: CONFIGURE NETWORK KERNEL MODULES
################################################################################

remediate_network_kernel_modules() {
    if ! section3_group_selected "3.2"; then
        log_info "Skipping Section 3.2: Configure Network Kernel Modules (not selected)"
        return 0
    fi

    log_info "=== Section 3.2: Configure Network Kernel Modules ==="

    local modules=("dccp" "tipc" "rds" "sctp")
    local descriptions=(
        "Ensure dccp kernel module is not available"
        "Ensure tipc kernel module is not available"
        "Ensure rds kernel module is not available"
        "Ensure sctp kernel module is not available"
    )
    local i control_id module description

    for i in "${!modules[@]}"; do
        control_id="3.2.$((i + 1))"
        module="${modules[$i]}"
        description="${descriptions[$i]}"

        section3_run_check "${control_id}" "${description}" \
            "audit_kernel_module_${module}" \
            "remediate_kernel_module_${module}"
    done
}

audit_kernel_module_dccp() { module_disabled_or_unavailable dccp; }
remediate_kernel_module_dccp() { disable_kernel_module dccp; }
audit_kernel_module_tipc() { module_disabled_or_unavailable tipc; }
remediate_kernel_module_tipc() { disable_kernel_module tipc; }
audit_kernel_module_rds() { module_disabled_or_unavailable rds; }
remediate_kernel_module_rds() { disable_kernel_module rds; }
audit_kernel_module_sctp() { module_disabled_or_unavailable sctp; }
remediate_kernel_module_sctp() { disable_kernel_module sctp; }

################################################################################
# SECTION 3.3: CONFIGURE NETWORK KERNEL PARAMETERS
################################################################################

audit_3_3_1() { audit_sysctl_parameters "net.ipv4.ip_forward=0" "net.ipv6.conf.all.forwarding=0"; }
remediate_3_3_1() { set_sysctl_parameters "net.ipv4.ip_forward=0" "net.ipv6.conf.all.forwarding=0"; }

audit_3_3_2() { audit_sysctl_parameters "net.ipv4.conf.all.send_redirects=0" "net.ipv4.conf.default.send_redirects=0"; }
remediate_3_3_2() { set_sysctl_parameters "net.ipv4.conf.all.send_redirects=0" "net.ipv4.conf.default.send_redirects=0"; }

audit_3_3_3() { audit_sysctl_parameters "net.ipv4.icmp_ignore_bogus_error_responses=1"; }
remediate_3_3_3() { set_sysctl_parameters "net.ipv4.icmp_ignore_bogus_error_responses=1"; }

audit_3_3_4() { audit_sysctl_parameters "net.ipv4.icmp_echo_ignore_broadcasts=1"; }
remediate_3_3_4() { set_sysctl_parameters "net.ipv4.icmp_echo_ignore_broadcasts=1"; }

audit_3_3_5() { audit_sysctl_parameters "net.ipv4.conf.all.accept_redirects=0" "net.ipv4.conf.default.accept_redirects=0" "net.ipv6.conf.all.accept_redirects=0" "net.ipv6.conf.default.accept_redirects=0"; }
remediate_3_3_5() { set_sysctl_parameters "net.ipv4.conf.all.accept_redirects=0" "net.ipv4.conf.default.accept_redirects=0" "net.ipv6.conf.all.accept_redirects=0" "net.ipv6.conf.default.accept_redirects=0"; }

audit_3_3_6() { audit_sysctl_parameters "net.ipv4.conf.all.secure_redirects=0" "net.ipv4.conf.default.secure_redirects=0"; }
remediate_3_3_6() { set_sysctl_parameters "net.ipv4.conf.all.secure_redirects=0" "net.ipv4.conf.default.secure_redirects=0"; }

audit_3_3_7() { audit_sysctl_parameters "net.ipv4.conf.all.rp_filter=1" "net.ipv4.conf.default.rp_filter=1"; }
remediate_3_3_7() { set_sysctl_parameters "net.ipv4.conf.all.rp_filter=1" "net.ipv4.conf.default.rp_filter=1"; }

audit_3_3_8() { audit_sysctl_parameters "net.ipv4.conf.all.accept_source_route=0" "net.ipv4.conf.default.accept_source_route=0" "net.ipv6.conf.all.accept_source_route=0" "net.ipv6.conf.default.accept_source_route=0"; }
remediate_3_3_8() { set_sysctl_parameters "net.ipv4.conf.all.accept_source_route=0" "net.ipv4.conf.default.accept_source_route=0" "net.ipv6.conf.all.accept_source_route=0" "net.ipv6.conf.default.accept_source_route=0"; }

audit_3_3_9() { audit_sysctl_parameters "net.ipv4.conf.all.log_martians=1" "net.ipv4.conf.default.log_martians=1"; }
remediate_3_3_9() { set_sysctl_parameters "net.ipv4.conf.all.log_martians=1" "net.ipv4.conf.default.log_martians=1"; }

audit_3_3_10() { audit_sysctl_parameters "net.ipv4.tcp_syncookies=1"; }
remediate_3_3_10() { set_sysctl_parameters "net.ipv4.tcp_syncookies=1"; }

audit_3_3_11() { audit_sysctl_parameters "net.ipv6.conf.all.accept_ra=0" "net.ipv6.conf.default.accept_ra=0"; }
remediate_3_3_11() { set_sysctl_parameters "net.ipv6.conf.all.accept_ra=0" "net.ipv6.conf.default.accept_ra=0"; }

remediate_network_kernel_parameters() {
    if ! section3_group_selected "3.3"; then
        log_info "Skipping Section 3.3: Configure Network Kernel Parameters (not selected)"
        return 0
    fi

    log_info "=== Section 3.3: Configure Network Kernel Parameters ==="

    section3_run_check "3.3.1" "Ensure ip forwarding is disabled" audit_3_3_1 remediate_3_3_1
    section3_run_check "3.3.2" "Ensure packet redirect sending is disabled" audit_3_3_2 remediate_3_3_2
    section3_run_check "3.3.3" "Ensure bogus icmp responses are ignored" audit_3_3_3 remediate_3_3_3
    section3_run_check "3.3.4" "Ensure broadcast icmp requests are ignored" audit_3_3_4 remediate_3_3_4
    section3_run_check "3.3.5" "Ensure icmp redirects are not accepted" audit_3_3_5 remediate_3_3_5
    section3_run_check "3.3.6" "Ensure secure icmp redirects are not accepted" audit_3_3_6 remediate_3_3_6
    section3_run_check "3.3.7" "Ensure reverse path filtering is enabled" audit_3_3_7 remediate_3_3_7
    section3_run_check "3.3.8" "Ensure source routed packets are not accepted" audit_3_3_8 remediate_3_3_8
    section3_run_check "3.3.9" "Ensure suspicious packets are logged" audit_3_3_9 remediate_3_3_9
    section3_run_check "3.3.10" "Ensure tcp syn cookies is enabled" audit_3_3_10 remediate_3_3_10
    section3_run_check "3.3.11" "Ensure ipv6 router advertisements are not accepted" audit_3_3_11 remediate_3_3_11
}

################################################################################
# SECTION 3 MAIN RUNNER
################################################################################

run_section_3() {
    remediate_network_devices
    remediate_network_kernel_modules
    remediate_network_kernel_parameters
}
