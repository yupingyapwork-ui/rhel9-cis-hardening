#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 5: Access Control
# Version: 2.0.0
# Description: Implementation of CIS Section 5 controls
################################################################################

SECTION5_SSHD_CONFIG="/etc/ssh/sshd_config"
SECTION5_SSHD_DROPIN="/etc/ssh/sshd_config.d/00-cis-hardening.conf"
SECTION5_SUDOERS_DROPIN="/etc/sudoers.d/00-cis"
SECTION5_TMOUT_FILE="/etc/profile.d/50-tmout.sh"
SECTION5_UMASK_FILE="/etc/profile.d/50-systemwide_umask.sh"
SECTION5_PWQUALITY_DROPIN="/etc/security/pwquality.conf.d/50-cis.conf"

section5_start_check() {
    local control_id="$1"
    local description="$2"
    
    log_info "[${control_id}] ${description}"
    ((TOTAL_CHECKS++))
}

section5_pass() {
    local control_id="$1"
    local message="$2"
    
    log_success "[${control_id}] PASS: ${message}"
    ((PASSED_CHECKS++))
}

section5_fail() {
    local control_id="$1"
    local message="$2"
    
    log_warning "[${control_id}] FAIL: ${message}"
    ((FAILED_CHECKS++))
}

section5_manual() {
    local control_id="$1"
    local message="$2"
    local current_state="${3:-Manual review required - check current system configuration}"
    local verification_steps="${4:-1. Review the CIS Benchmark documentation for check ${control_id}
2. Assess current system configuration
3. Implement required changes per organizational policy
4. Document the configuration decisions made
5. Verify compliance with organizational security requirements}"
    local additional_info="${5:-This check requires manual review and configuration based on site-specific security policies}"
    
    log_check_manual "${control_id}" \
        "${message}" \
        "${current_state}" \
        "${message}" \
        "${verification_steps}" \
        "${additional_info}"
    ((FAILED_CHECKS++))
    ((MANUAL_CHECKS++))
}

section5_remediated() {
    local control_id="$1"
    local message="$2"
    
    log_success "[${control_id}] Remediated: ${message}"
    ((REMEDIATED_CHECKS++))
}

section5_backup_if_exists() {
    local file="$1"
    
    [[ -e "${file}" ]] && backup_file "${file}"
}

section5_write_kv() {
    local file="$1"
    local key="$2"
    local value="$3"
    local separator="${4:- }"
    
    section5_backup_if_exists "${file}"
    touch "${file}" 2>/dev/null || return 1
    sed -ri "s/^([[:space:]]*${key}([[:space:]]+|[[:space:]]*=[[:space:]]*)[^#]*)/# &/" "${file}"
    printf '%s%s%s\n' "${key}" "${separator}" "${value}" >> "${file}"
}

section5_write_flag() {
    local file="$1"
    local key="$2"
    
    section5_backup_if_exists "${file}"
    touch "${file}" 2>/dev/null || return 1
    sed -ri "s/^([[:space:]]*${key}([[:space:]#].*)?)$/# &/" "${file}"
    printf '%s\n' "${key}" >> "${file}"
}

section5_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

section5_selected() {
    local selected
    
    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi
    
    for selected in "${SELECTED_SECTIONS[@]}"; do
        [[ "${selected}" == "5" || "${selected}" == 5.* ]] && return 0
    done
    
    return 1
}

section5_should_run() {
    local section="$1"
    local selected
    
    if [[ ${#SELECTED_SECTIONS[@]} -eq 0 ]] || [[ "${SELECTED_SECTIONS[*]}" == "all" ]]; then
        return 0
    fi
    
    for selected in "${SELECTED_SECTIONS[@]}"; do
        [[ "${selected}" == "${section}" ]] && return 0
        [[ "${selected}" == ${section}.* ]] && return 0
        [[ "${section}" == ${selected}.* ]] && return 0
    done
    
    return 1
}

section5_install_package() {
    local control_id="$1"
    local package="$2"
    
    if rpm -q "${package}" &>/dev/null; then
        section5_pass "${control_id}" "${package} is installed"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "${package} is not installed"
        return 1
    fi
    
    if confirm_action "[${control_id}] Install ${package}?"; then
        if dnf install -y "${package}" &>/dev/null; then
            section5_remediated "${control_id}" "${package} installed"
            return 0
        fi
        log_error "[${control_id}] Failed to install ${package}"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    section5_manual "${control_id}" "${package} installation skipped"
    return 1
}

section5_upgrade_package() {
    local control_id="$1"
    local package="$2"
    
    if ! rpm -q "${package}" &>/dev/null; then
        section5_install_package "${control_id}" "${package}"
        return
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_pass "${control_id}" "${package} is installed; latest version requires repository comparison"
        return 0
    fi
    
    if confirm_action "[${control_id}] Upgrade ${package} to latest available version?"; then
        if dnf upgrade -y "${package}" &>/dev/null; then
            section5_remediated "${control_id}" "${package} upgraded or already current"
            return 0
        fi
        log_error "[${control_id}] Failed to upgrade ${package}"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    section5_pass "${control_id}" "${package} is installed"
}

section5_sshd_available() {
    section5_command_exists sshd && sshd -T >/dev/null 2>&1
}

section5_sshd_value() {
    local key="$1"
    
    sshd -T 2>/dev/null | awk -v key="$(printf '%s' "${key}" | tr '[:upper:]' '[:lower:]')" '
        tolower($1) == key {
            $1 = ""
            sub(/^[[:space:]]+/, "")
            print
            exit
        }
    '
}

section5_set_sshd_option() {
    local key="$1"
    local value="$2"
    local temp_file
    
    mkdir -p "$(dirname "${SECTION5_SSHD_CONFIG}")" "$(dirname "${SECTION5_SSHD_DROPIN}")" 2>/dev/null || return 1
    touch "${SECTION5_SSHD_CONFIG}" 2>/dev/null || return 1
    section5_backup_if_exists "${SECTION5_SSHD_CONFIG}"
    
    temp_file="$(mktemp)" || return 1
    awk -v key="${key}" -v setting="${key} ${value}" '
        BEGIN { inserted = 0 }
        {
            first = $1
            lower_first = tolower(first)
            lower_key = tolower(key)
            if (lower_first == lower_key) {
                print "# " $0 " # CIS remediated"
                next
            }
            if (!inserted && lower_first ~ /^(include|match)$/) {
                print setting
                inserted = 1
            }
            print
        }
        END {
            if (!inserted) {
                print setting
            }
        }
    ' "${SECTION5_SSHD_CONFIG}" > "${temp_file}" && cp "${temp_file}" "${SECTION5_SSHD_CONFIG}"
    local rc=$?
    rm -f "${temp_file}"
    return "${rc}"
}

section5_reload_sshd() {
    if section5_command_exists systemctl; then
        systemctl reload-or-restart sshd >/dev/null 2>&1 || true
    fi
}

section5_sshd_equals() {
    local control_id="$1"
    local description="$2"
    local key="$3"
    local expected="$4"
    local actual
    
    section5_start_check "${control_id}" "${description}"
    
    if ! section5_sshd_available; then
        section5_manual "${control_id}" "sshd -T is unavailable; verify ${key} manually"
        return 1
    fi
    
    actual="$(section5_sshd_value "${key}" | tr '[:upper:]' '[:lower:]')"
    if [[ "${actual}" == "$(printf '%s' "${expected}" | tr '[:upper:]' '[:lower:]')" ]]; then
        section5_pass "${control_id}" "${key} is ${expected}"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "${key} is ${actual:-unset}, expected ${expected}"
        return 1
    fi
    
    # Use critical confirmation for PermitRootLogin to prevent lockout
    local confirm_func="confirm_action"
    if [[ "${key}" == "PermitRootLogin" ]]; then
        confirm_func="confirm_critical_action"
        if ${confirm_func} "[${control_id}] Set ${key} ${expected}?" \
            "WARNING: Disabling root login via SSH may lock you out if you don't have another way to access the system!
- Ensure you have a non-root user with sudo privileges
- Ensure you can access the system via console or other means
- Current setting: ${key} = ${actual:-unset}
- Proposed setting: ${key} = ${expected}"; then
            if section5_set_sshd_option "${key}" "${expected}"; then
                section5_reload_sshd
                section5_remediated "${control_id}" "${key} set to ${expected}"
                return 0
            fi
        fi
    elif confirm_action "[${control_id}] Set ${key} ${expected}?"; then
        if section5_set_sshd_option "${key}" "${expected}"; then
            section5_reload_sshd
            section5_remediated "${control_id}" "${key} set to ${expected}"
            return 0
        fi
    fi
    
    if [[ "${key}" != "PermitRootLogin" ]]; then
        log_error "[${control_id}] Failed to update ${SECTION5_SSHD_CONFIG}"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    section5_manual "${control_id}" "${key} remediation skipped"
}

section5_sshd_numeric_max() {
    local control_id="$1"
    local description="$2"
    local key="$3"
    local max_value="$4"
    local set_value="$5"
    local actual
    
    section5_start_check "${control_id}" "${description}"
    
    if ! section5_sshd_available; then
        section5_manual "${control_id}" "sshd -T is unavailable; verify ${key} manually"
        return 1
    fi
    
    actual="$(section5_sshd_value "${key}")"
    if [[ "${actual}" =~ ^[0-9]+$ ]] && [[ "${actual}" -gt 0 ]] && [[ "${actual}" -le "${max_value}" ]]; then
        section5_pass "${control_id}" "${key} is ${actual}"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "${key} is ${actual:-unset}, expected 1-${max_value}"
        return 1
    fi
    
    if confirm_action "[${control_id}] Set ${key} ${set_value}?"; then
        if section5_set_sshd_option "${key}" "${set_value}"; then
            section5_reload_sshd
            section5_remediated "${control_id}" "${key} set to ${set_value}"
            return 0
        fi
        log_error "[${control_id}] Failed to update ${SECTION5_SSHD_CONFIG}"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    section5_manual "${control_id}" "${key} remediation skipped"
}

section5_sshd_algorithms() {
    local control_id="$1"
    local description="$2"
    local key="$3"
    local weak_pattern="$4"
    local remediation_value="$5"
    local actual
    
    section5_start_check "${control_id}" "${description}"
    
    if ! section5_sshd_available; then
        section5_manual "${control_id}" "sshd -T is unavailable; verify ${key} manually"
        return 1
    fi
    
    actual="$(section5_sshd_value "${key}")"
    if ! printf '%s\n' "${actual}" | grep -Eiq "${weak_pattern}"; then
        section5_pass "${control_id}" "no weak ${key} algorithms are active"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "weak ${key} algorithms are active: ${actual}"
        return 1
    fi
    
    if confirm_action "[${control_id}] Exclude weak ${key} algorithms?"; then
        if section5_set_sshd_option "${key}" "${remediation_value}"; then
            section5_reload_sshd
            section5_remediated "${control_id}" "weak ${key} algorithms excluded"
            return 0
        fi
        log_error "[${control_id}] Failed to update ${SECTION5_SSHD_CONFIG}"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    section5_manual "${control_id}" "${key} remediation skipped"
}

section5_sudoers_files() {
    find /etc/sudoers /etc/sudoers.d -type f ! -name '*~' ! -name '*.*' 2>/dev/null
}

section5_append_sudoers() {
    local line="$1"
    
    mkdir -p /etc/sudoers.d 2>/dev/null || return 1
    section5_backup_if_exists "${SECTION5_SUDOERS_DROPIN}"
    grep -Fxq "${line}" "${SECTION5_SUDOERS_DROPIN}" 2>/dev/null || printf '%s\n' "${line}" >> "${SECTION5_SUDOERS_DROPIN}"
    chmod 0440 "${SECTION5_SUDOERS_DROPIN}" 2>/dev/null || true
    if section5_command_exists visudo; then
        visudo -cf "${SECTION5_SUDOERS_DROPIN}" >/dev/null 2>&1
    fi
}

section5_comment_sudoers_pattern() {
    local pattern="$1"
    local file
    
    while IFS= read -r file; do
        section5_backup_if_exists "${file}"
        sed -ri "/^[[:space:]]*[^#].*${pattern}/ s/^/# CIS remediated: /" "${file}"
    done < <(section5_sudoers_files)
}

section5_authselect_profile_path() {
    local profile
    
    [[ -r /etc/authselect/authselect.conf ]] || return 1
    profile="$(head -1 /etc/authselect/authselect.conf)"
    if [[ "${profile}" == custom/* ]]; then
        printf '/etc/authselect/%s\n' "${profile}"
    else
        printf '/usr/share/authselect/default/%s\n' "${profile}"
    fi
}

section5_apply_authselect() {
    section5_command_exists authselect && authselect apply-changes >/dev/null 2>&1
}

section5_enable_authselect_feature() {
    local feature="$1"
    
    if section5_command_exists authselect; then
        authselect enable-feature "${feature}" >/dev/null 2>&1 || true
        authselect apply-changes >/dev/null 2>&1 || true
    fi
}

section5_pam_has_module() {
    local module="$1"
    
    grep -Prq -- "\\bpam_${module}\\.so\\b" /etc/pam.d/password-auth /etc/pam.d/system-auth 2>/dev/null
}

section5_check_pam_module() {
    local control_id="$1"
    local description="$2"
    local module="$3"
    local feature="$4"
    
    section5_start_check "${control_id}" "${description}"
    
    if section5_pam_has_module "${module}"; then
        section5_pass "${control_id}" "pam_${module}.so is enabled"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pam_${module}.so is not enabled"
        return 1
    fi
    
    if confirm_action "[${control_id}] Enable authselect feature ${feature}?"; then
        section5_enable_authselect_feature "${feature}"
        if section5_pam_has_module "${module}"; then
            section5_remediated "${control_id}" "pam_${module}.so enabled"
            return 0
        fi
    fi
    
    section5_manual "${control_id}" "enable pam_${module}.so in the active authselect profile"
}

section5_remove_pam_arg() {
    local module="$1"
    local argument_regex="$2"
    local file
    local profile_path
    
    for file in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
        [[ -f "${file}" ]] || continue
        section5_backup_if_exists "${file}"
        sed -ri "/pam_${module}\.so/ s/[[:space:]]+${argument_regex}//g" "${file}"
    done
    
    profile_path="$(section5_authselect_profile_path 2>/dev/null || true)"
    if [[ -n "${profile_path}" && -d "${profile_path}" && -w "${profile_path}" ]]; then
        for file in "${profile_path}/system-auth" "${profile_path}/password-auth"; do
            [[ -f "${file}" ]] || continue
            section5_backup_if_exists "${file}"
            sed -ri "/pam_${module}\.so/ s/[[:space:]]+${argument_regex}//g" "${file}"
        done
        section5_apply_authselect
    fi
}

section5_write_security_conf() {
    local file="$1"
    local key="$2"
    local value="$3"
    
    section5_backup_if_exists "${file}"
    touch "${file}" 2>/dev/null || return 1
    sed -ri "s/^([[:space:]]*${key}[[:space:]]*=.*)$/# &/" "${file}"
    printf '%s = %s\n' "${key}" "${value}" >> "${file}"
}

section5_write_security_flag() {
    local file="$1"
    local key="$2"
    
    section5_write_flag "${file}" "${key}"
}

section5_pwquality_set() {
    local key="$1"
    local value="$2"
    local file
    
    mkdir -p "$(dirname "${SECTION5_PWQUALITY_DROPIN}")" 2>/dev/null || return 1
    for file in /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf; do
        [[ -f "${file}" && "${file}" != "${SECTION5_PWQUALITY_DROPIN}" ]] || continue
        section5_backup_if_exists "${file}"
        sed -ri "s/^([[:space:]]*${key}[[:space:]]*=.*)$/# &/" "${file}"
    done
    section5_write_security_conf "${SECTION5_PWQUALITY_DROPIN}" "${key}" "${value}"
}

section5_pwquality_flag() {
    local key="$1"
    local file
    
    mkdir -p "$(dirname "${SECTION5_PWQUALITY_DROPIN}")" 2>/dev/null || return 1
    for file in /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf; do
        [[ -f "${file}" && "${file}" != "${SECTION5_PWQUALITY_DROPIN}" ]] || continue
        section5_backup_if_exists "${file}"
        sed -ri "s/^([[:space:]]*${key}([[:space:]#].*)?)$/# &/" "${file}"
    done
    section5_write_security_flag "${SECTION5_PWQUALITY_DROPIN}" "${key}"
}

section5_check_pwquality_min() {
    local control_id="$1"
    local description="$2"
    local key="$3"
    local min_value="$4"
    local set_value="$5"
    local good_value bad_module_value
    
    section5_start_check "${control_id}" "${description}"
    
    good_value="$(awk -v key="${key}" -v min="${min_value}" '
        $0 !~ /^[[:space:]]*#/ && $1 == key {
            for (i = 2; i <= NF; i++) {
                if ($i ~ /^[0-9]+$/ && $i >= min) {
                    found = 1
                }
            }
        }
        END { print found ? "yes" : "no" }
    ' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null)"
    bad_module_value="$(awk -v key="${key}" -v min="${min_value}" '
        $0 !~ /^[[:space:]]*#/ && $0 ~ /pam_pwquality\.so/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ "^" key "[[:space:]]*=") {
                    split($i, a, "=")
                    if (a[2] < min) {
                        found = 1
                    }
                }
            }
        }
        END { print found ? "yes" : "no" }
    ' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null)"
    
    if [[ "${good_value}" == "yes" && "${bad_module_value}" != "yes" ]]; then
        section5_pass "${control_id}" "${key} meets minimum value ${min_value}"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "${key} is not configured to at least ${min_value}"
        return 1
    fi
    
    if confirm_action "[${control_id}] Set ${key} = ${set_value}?"; then
        section5_pwquality_set "${key}" "${set_value}"
        section5_remove_pam_arg "pwquality" "${key}[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "${key} set to ${set_value}"
        return 0
    fi
    
    section5_manual "${control_id}" "${key} remediation skipped"
}

section5_check_pwquality_range_1_3() {
    local control_id="$1"
    local description="$2"
    local key="$3"
    
    section5_start_check "${control_id}" "${description}"
    
    if grep -Psiq -- "^[[:space:]]*${key}[[:space:]]*=[[:space:]]*[1-3]\\b" /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null &&
       ! grep -Psiq -- "pam_pwquality\\.so.*[[:space:]]${key}[[:space:]]*=[[:space:]]*(0|[4-9]|[1-9][0-9]+)\\b" /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "${key} is 1-3"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "${key} is not configured to 1-3"
        return 1
    fi
    
    if confirm_action "[${control_id}] Set ${key} = 3?"; then
        section5_pwquality_set "${key}" "3"
        section5_remove_pam_arg "pwquality" "${key}[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "${key} set to 3"
        return 0
    fi
    
    section5_manual "${control_id}" "${key} remediation skipped"
}

section5_check_pam_password_arg() {
    local control_id="$1"
    local description="$2"
    local module="$3"
    local arg="$4"
    
    section5_start_check "${control_id}" "${description}"
    
    if grep -Psiq -- "^[[:space:]]*password[[:space:]]+[^#[:space:]]+[[:space:]]+pam_${module}\\.so.*[[:space:]]${arg}\\b" /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "pam_${module}.so includes ${arg}"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pam_${module}.so does not include ${arg}"
        return 1
    fi
    
    section5_manual "${control_id}" "add ${arg} to pam_${module}.so in the active authselect profile"
}

section5_uid_min() {
    awk '/^[[:space:]]*UID_MIN[[:space:]]+/ { print $2; found=1 } END { if (!found) print 1000 }' /etc/login.defs 2>/dev/null
}

section5_valid_shell_regex() {
    awk -F/ '$NF != "nologin" && $0 ~ /^\// { gsub(/\//, "\\/"); print }' /etc/shells 2>/dev/null | paste -sd '|' -
}

remediate_ssh_server() {
    if ! section5_should_run "5.1"; then
        return 0
    fi
    
    log_info "=== Section 5.1: Configure SSH Server ==="
    
    local control_id
    control_id="5.1.1"
    section5_start_check "${control_id}" "Ensure permissions on /etc/ssh/sshd_config are configured"
    if [[ -f "${SECTION5_SSHD_CONFIG}" ]]; then
        local sshd_perms sshd_owner sshd_group
        sshd_perms="$(stat -Lc '%a' "${SECTION5_SSHD_CONFIG}" 2>/dev/null)"
        sshd_owner="$(stat -Lc '%U' "${SECTION5_SSHD_CONFIG}" 2>/dev/null)"
        sshd_group="$(stat -Lc '%G' "${SECTION5_SSHD_CONFIG}" 2>/dev/null)"
        if [[ "${sshd_perms}" -le 600 && "${sshd_owner}" == "root" && "${sshd_group}" == "root" ]]; then
            section5_pass "${control_id}" "/etc/ssh/sshd_config permissions are ${sshd_perms} root:root"
        elif [[ "${DRY_RUN}" == true ]]; then
            section5_fail "${control_id}" "/etc/ssh/sshd_config permissions are ${sshd_perms} ${sshd_owner}:${sshd_group}"
        elif confirm_action "[${control_id}] Set /etc/ssh/sshd_config permissions to 600 root:root?"; then
            section5_backup_if_exists "${SECTION5_SSHD_CONFIG}"
            chown root:root "${SECTION5_SSHD_CONFIG}" && chmod 600 "${SECTION5_SSHD_CONFIG}"
            section5_remediated "${control_id}" "/etc/ssh/sshd_config permissions set"
        fi
    else
        section5_fail "${control_id}" "/etc/ssh/sshd_config not found"
    fi
    
    control_id="5.1.2"
    section5_start_check "${control_id}" "Ensure permissions on SSH private host key files are configured"
    local bad_private_keys
    bad_private_keys="$(find /etc/ssh -xdev -type f -name 'ssh_host_*_key' ! -name '*.pub' \( ! -user root -o ! -perm 0600 \) -print 2>/dev/null)"
    if [[ -z "${bad_private_keys}" ]]; then
        section5_pass "${control_id}" "SSH private host keys are mode 600 and owned by root"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "SSH private host keys need permission updates"
    elif confirm_action "[${control_id}] Restrict SSH private host key permissions?"; then
        while IFS= read -r key_file; do
            [[ -n "${key_file}" ]] || continue
            section5_backup_if_exists "${key_file}"
            chown root:root "${key_file}" 2>/dev/null || true
            chmod 600 "${key_file}" 2>/dev/null || true
        done <<< "${bad_private_keys}"
        section5_remediated "${control_id}" "SSH private host key permissions set"
    fi
    
    control_id="5.1.3"
    section5_start_check "${control_id}" "Ensure permissions on SSH public host key files are configured"
    local bad_public_keys
    bad_public_keys="$(find /etc/ssh -xdev -type f -name 'ssh_host_*_key.pub' \( ! -user root -o ! -group root -o ! -perm 0644 \) -print 2>/dev/null)"
    if [[ -z "${bad_public_keys}" ]]; then
        section5_pass "${control_id}" "SSH public host keys are mode 644 and owned by root:root"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "SSH public host keys need permission updates"
    elif confirm_action "[${control_id}] Set SSH public host key permissions?"; then
        while IFS= read -r key_file; do
            [[ -n "${key_file}" ]] || continue
            section5_backup_if_exists "${key_file}"
            chown root:root "${key_file}" 2>/dev/null || true
            chmod 644 "${key_file}" 2>/dev/null || true
        done <<< "${bad_public_keys}"
        section5_remediated "${control_id}" "SSH public host key permissions set"
    fi
    
    section5_sshd_algorithms "5.1.4" "Ensure sshd Ciphers are configured" "ciphers" "(3des|blowfish|cast128|aes(128|192|256))-cbc|arcfour(128|256)?|rijndael-cbc@lysator\\.liu\\.se|chacha20-?poly1305@openssh\\.com" "-3des-cbc,aes128-cbc,aes192-cbc,aes256-cbc,chacha20-poly1305@openssh.com"
    section5_sshd_algorithms "5.1.5" "Ensure sshd KexAlgorithms is configured" "kexalgorithms" "diffie-hellman-group1-sha1|diffie-hellman-group14-sha1|diffie-hellman-group-exchange-sha1" "-diffie-hellman-group1-sha1,diffie-hellman-group14-sha1,diffie-hellman-group-exchange-sha1"
    section5_sshd_algorithms "5.1.6" "Ensure sshd MACs are configured" "macs" "hmac-md5|hmac-md5-96|hmac-ripemd160|hmac-sha1-96|umac-64@openssh\\.com|hmac-md5-etm@openssh\\.com|hmac-md5-96-etm@openssh\\.com|hmac-ripemd160-etm@openssh\\.com|hmac-sha1-96-etm@openssh\\.com|umac-64-etm@openssh\\.com|umac-128-etm@openssh\\.com" "-hmac-md5,hmac-md5-96,hmac-ripemd160,hmac-sha1-96,umac-64@openssh.com,hmac-md5-etm@openssh.com,hmac-md5-96-etm@openssh.com,hmac-ripemd160-etm@openssh.com,hmac-sha1-96-etm@openssh.com,umac-64-etm@openssh.com,umac-128-etm@openssh.com"
    
    control_id="5.1.7"
    section5_start_check "${control_id}" "Ensure sshd access is configured"
    if section5_sshd_available && sshd -T 2>/dev/null | grep -Piq '^(allow|deny)(users|groups)[[:space:]]+[^[:space:]]+'; then
        section5_pass "${control_id}" "SSH allow/deny users or groups are configured"
    else
        section5_manual "${control_id}" "configure AllowUsers, AllowGroups, DenyUsers, or DenyGroups according to site policy"
    fi
    
    control_id="5.1.8"
    section5_start_check "${control_id}" "Ensure sshd Banner is configured"
    if section5_sshd_available && [[ "$(section5_sshd_value Banner)" =~ ^/ ]] && [[ -r "$(section5_sshd_value Banner)" ]]; then
        section5_pass "${control_id}" "Banner is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "Banner is not configured"
    elif confirm_action "[${control_id}] Configure SSH banner /etc/issue.net?"; then
        section5_set_sshd_option "Banner" "/etc/issue.net"
        section5_backup_if_exists "/etc/issue.net"
        printf '%s\n' "Authorized users only. All activity may be monitored and reported." > /etc/issue.net
        section5_reload_sshd
        section5_remediated "${control_id}" "SSH banner configured"
    fi
    
    control_id="5.1.9"
    section5_start_check "${control_id}" "Ensure sshd ClientAliveInterval and ClientAliveCountMax are configured"
    local client_alive_interval client_alive_count
    client_alive_interval="$(section5_sshd_value ClientAliveInterval)"
    client_alive_count="$(section5_sshd_value ClientAliveCountMax)"
    if [[ "${client_alive_interval}" =~ ^[0-9]+$ && "${client_alive_interval}" -gt 0 && "${client_alive_count}" =~ ^[0-9]+$ && "${client_alive_count}" -gt 0 ]]; then
        section5_pass "${control_id}" "ClientAliveInterval=${client_alive_interval}, ClientAliveCountMax=${client_alive_count}"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "ClientAliveInterval and ClientAliveCountMax must be greater than zero"
    elif confirm_action "[${control_id}] Set ClientAliveInterval 15 and ClientAliveCountMax 3?"; then
        section5_set_sshd_option "ClientAliveInterval" "15"
        section5_set_sshd_option "ClientAliveCountMax" "3"
        section5_reload_sshd
        section5_remediated "${control_id}" "client alive settings configured"
    fi
    
    section5_sshd_equals "5.1.10" "Ensure sshd DisableForwarding is enabled" "DisableForwarding" "yes"
    section5_sshd_equals "5.1.11" "Ensure sshd GSSAPIAuthentication is disabled" "GSSAPIAuthentication" "no"
    section5_sshd_equals "5.1.12" "Ensure sshd HostbasedAuthentication is disabled" "HostbasedAuthentication" "no"
    section5_sshd_equals "5.1.13" "Ensure sshd IgnoreRhosts is enabled" "IgnoreRhosts" "yes"
    section5_sshd_numeric_max "5.1.14" "Ensure sshd LoginGraceTime is configured" "LoginGraceTime" "60" "60"
    
    control_id="5.1.15"
    section5_start_check "${control_id}" "Ensure sshd LogLevel is configured"
    local log_level
    log_level="$(section5_sshd_value LogLevel | tr '[:lower:]' '[:upper:]')"
    if [[ "${log_level}" == "INFO" || "${log_level}" == "VERBOSE" ]]; then
        section5_pass "${control_id}" "LogLevel is ${log_level}"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "LogLevel is ${log_level:-unset}, expected INFO or VERBOSE"
    elif confirm_action "[${control_id}] Set LogLevel VERBOSE?"; then
        section5_set_sshd_option "LogLevel" "VERBOSE"
        section5_reload_sshd
        section5_remediated "${control_id}" "LogLevel set to VERBOSE"
    fi
    
    section5_sshd_numeric_max "5.1.16" "Ensure sshd MaxAuthTries is configured" "MaxAuthTries" "4" "4"
    
    control_id="5.1.17"
    section5_start_check "${control_id}" "Ensure sshd MaxStartups is configured"
    local max_startups first second third
    max_startups="$(section5_sshd_value MaxStartups)"
    IFS=':' read -r first second third <<< "${max_startups}"
    if [[ "${first}" =~ ^[0-9]+$ && "${second}" =~ ^[0-9]+$ && "${third}" =~ ^[0-9]+$ && "${first}" -le 10 && "${second}" -le 30 && "${third}" -le 60 ]]; then
        section5_pass "${control_id}" "MaxStartups is ${max_startups}"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "MaxStartups is ${max_startups:-unset}, expected 10:30:60 or more restrictive"
    elif confirm_action "[${control_id}] Set MaxStartups 10:30:60?"; then
        section5_set_sshd_option "MaxStartups" "10:30:60"
        section5_reload_sshd
        section5_remediated "${control_id}" "MaxStartups set to 10:30:60"
    fi
    
    section5_sshd_numeric_max "5.1.18" "Ensure sshd MaxSessions is configured" "MaxSessions" "10" "10"
    section5_sshd_equals "5.1.19" "Ensure sshd PermitEmptyPasswords is disabled" "PermitEmptyPasswords" "no"
    section5_sshd_equals "5.1.20" "Ensure sshd PermitRootLogin is disabled" "PermitRootLogin" "no"
    section5_sshd_equals "5.1.21" "Ensure sshd PermitUserEnvironment is disabled" "PermitUserEnvironment" "no"
    section5_sshd_equals "5.1.22" "Ensure sshd UsePAM is enabled" "UsePAM" "yes"
}

remediate_privilege_escalation() {
    if ! section5_should_run "5.2"; then
        return 0
    fi
    
    log_info "=== Section 5.2: Configure Privilege Escalation ==="
    
    section5_start_check "5.2.1" "Ensure sudo is installed"
    section5_install_package "5.2.1" "sudo"
    
    local control_id
    control_id="5.2.2"
    section5_start_check "${control_id}" "Ensure sudo commands use pty"
    if grep -rPiq -- '^[[:space:]]*Defaults[[:space:]]+([^#]*,[[:space:]]*)?use_pty\b' /etc/sudoers /etc/sudoers.d 2>/dev/null &&
       ! grep -rPiq -- '^[[:space:]]*Defaults[[:space:]]+([^#]*,[[:space:]]*)?!use_pty\b' /etc/sudoers /etc/sudoers.d 2>/dev/null; then
        section5_pass "${control_id}" "Defaults use_pty is set"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "Defaults use_pty is not correctly set"
    elif confirm_critical_action "[${control_id}] Configure sudo use_pty?" \
        "WARNING: Modifying sudoers configuration can affect system administration access!
- This change adds 'Defaults use_pty' to sudoers
- Requires sudo commands to run in a pseudo-terminal
- Generally safe but test after applying"; then
        section5_comment_sudoers_pattern "!use_pty"
        section5_append_sudoers "Defaults use_pty"
        section5_remediated "${control_id}" "sudo use_pty configured"
    fi
    
    control_id="5.2.3"
    section5_start_check "${control_id}" "Ensure sudo log file exists"
    if grep -rPiq -- '^[[:space:]]*Defaults[[:space:]]+([^#]+,[[:space:]]*)?logfile[[:space:]]*=[[:space:]]*"?/[^",[:space:]]+' /etc/sudoers /etc/sudoers.d 2>/dev/null; then
        section5_pass "${control_id}" "sudo logfile is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "sudo logfile is not configured"
    elif confirm_critical_action "[${control_id}] Configure sudo logfile /var/log/sudo.log?" \
        "WARNING: Modifying sudoers configuration can affect system administration access!
- This change adds sudo logging to /var/log/sudo.log
- Generally safe but test after applying"; then
        section5_append_sudoers 'Defaults logfile="/var/log/sudo.log"'
        touch /var/log/sudo.log 2>/dev/null || true
        chmod 0600 /var/log/sudo.log 2>/dev/null || true
        section5_remediated "${control_id}" "sudo logfile configured"
    fi
    
    control_id="5.2.4"
    section5_start_check "${control_id}" "Ensure users must provide password for escalation"
    if ! grep -rPiq -- '^[[:space:]]*[^#].*NOPASSWD' /etc/sudoers /etc/sudoers.d 2>/dev/null; then
        section5_pass "${control_id}" "NOPASSWD tags are not configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "NOPASSWD tags found"
    elif confirm_critical_action "[${control_id}] Comment sudoers entries containing NOPASSWD?" \
        "WARNING: This will DISABLE passwordless sudo access!
- All NOPASSWD entries in sudoers will be commented out
- Users will be required to enter passwords for sudo
- This may break automation scripts or services
- Review /etc/sudoers and /etc/sudoers.d/* before proceeding"; then
        section5_comment_sudoers_pattern "NOPASSWD"
        section5_remediated "${control_id}" "NOPASSWD entries commented"
    fi
    
    control_id="5.2.5"
    section5_start_check "${control_id}" "Ensure re-authentication for privilege escalation is not disabled globally"
    if ! grep -rPiq -- '^[[:space:]]*[^#].*!authenticate' /etc/sudoers /etc/sudoers.d 2>/dev/null; then
        section5_pass "${control_id}" "!authenticate tags are not configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "!authenticate tags found"
    elif confirm_critical_action "[${control_id}] Comment sudoers entries containing !authenticate?" \
        "WARNING: Modifying sudoers authentication settings!
- All !authenticate entries will be commented out
- Users will be required to re-authenticate for privilege escalation
- This may affect existing workflows"; then
        section5_comment_sudoers_pattern "!authenticate"
        section5_remediated "${control_id}" "!authenticate entries commented"
    fi
    
    control_id="5.2.6"
    section5_start_check "${control_id}" "Ensure sudo authentication timeout is configured correctly"
    local timeout_values
    timeout_values="$(grep -rhoP 'timestamp_timeout=\K-?[0-9]+' /etc/sudoers /etc/sudoers.d 2>/dev/null || true)"
    if [[ -z "${timeout_values}" ]] || ! awk '($1 < 0 || $1 > 15) { bad=1 } END { exit bad ? 0 : 1 }' <<< "${timeout_values}"; then
        section5_pass "${control_id}" "sudo timestamp timeout is 15 minutes or less"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "sudo timestamp timeout is greater than 15 or disabled"
    elif confirm_critical_action "[${control_id}] Configure sudo timestamp_timeout=15?" \
        "WARNING: Modifying sudoers timeout settings!
- This sets sudo password cache timeout to 15 minutes
- Users will need to re-enter password after 15 minutes
- Generally safe but may affect user experience"; then
        section5_append_sudoers "Defaults timestamp_timeout=15"
        section5_remediated "${control_id}" "sudo timestamp timeout configured"
    fi
    
    control_id="5.2.7"
    section5_start_check "${control_id}" "Ensure access to the su command is restricted"
    local su_group
    su_group="$(awk '/^[[:space:]]*auth[[:space:]]+(required|requisite)[[:space:]]+pam_wheel\.so/ {
        for (i = 1; i <= NF; i++) {
            if ($i ~ /^group=/) {
                sub(/^group=/, "", $i)
                print $i
                exit
            }
        }
    }' /etc/pam.d/su 2>/dev/null)"
    if [[ -n "${su_group}" ]] && getent group "${su_group}" | awk -F: '{ exit ($4 == "") ? 0 : 1 }'; then
        section5_pass "${control_id}" "su is restricted to empty group ${su_group}"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "su is not restricted to an empty group"
    elif confirm_action "[${control_id}] Restrict su to empty group sugroup?"; then
        getent group sugroup >/dev/null || groupadd sugroup
        section5_backup_if_exists "/etc/pam.d/su"
        sed -ri 's/^[[:space:]]*auth[[:space:]]+(required|requisite)[[:space:]]+pam_wheel\.so.*$/# &/' /etc/pam.d/su
        printf '%s\n' "auth required pam_wheel.so use_uid group=sugroup" >> /etc/pam.d/su
        section5_remediated "${control_id}" "su restricted to sugroup"
    fi
}

remediate_pam() {
    if ! section5_should_run "5.3"; then
        return 0
    fi
    
    log_info "=== Section 5.3: Pluggable Authentication Modules ==="
    
    section5_start_check "5.3.1.1" "Ensure latest version of pam is installed"
    section5_upgrade_package "5.3.1.1" "pam"
    section5_start_check "5.3.1.2" "Ensure latest version of authselect is installed"
    section5_upgrade_package "5.3.1.2" "authselect"
    section5_start_check "5.3.1.3" "Ensure latest version of libpwquality is installed"
    section5_upgrade_package "5.3.1.3" "libpwquality"
    
    local control_id profile_path
    control_id="5.3.2.1"
    section5_start_check "${control_id}" "Ensure active authselect profile includes pam modules"
    profile_path="$(section5_authselect_profile_path 2>/dev/null || true)"
    if [[ -n "${profile_path}" && -r "${profile_path}/system-auth" && -r "${profile_path}/password-auth" ]] &&
       grep -Prq 'pam_(faillock|pwquality|pwhistory|unix)\.so' "${profile_path}/system-auth" "${profile_path}/password-auth" 2>/dev/null; then
        section5_pass "${control_id}" "active authselect profile includes PAM module templates"
    else
        section5_manual "${control_id}" "create/select a custom authselect profile that includes faillock, pwquality, pwhistory, and unix modules"
    fi
    
    section5_check_pam_module "5.3.2.2" "Ensure pam_faillock module is enabled" "faillock" "with-faillock"
    section5_check_pam_module "5.3.2.3" "Ensure pam_pwquality module is enabled" "pwquality" "with-pwquality"
    section5_check_pam_module "5.3.2.4" "Ensure pam_pwhistory module is enabled" "pwhistory" "with-pwhistory"
    section5_check_pam_module "5.3.2.5" "Ensure pam_unix module is enabled" "unix" "with-unix"
    
    control_id="5.3.3.1.1"
    section5_start_check "${control_id}" "Ensure password failed attempts lockout is configured"
    if grep -Piq '^[[:space:]]*deny[[:space:]]*=[[:space:]]*[1-5]\b' /etc/security/faillock.conf 2>/dev/null &&
       ! grep -Piq 'pam_faillock\.so.*[[:space:]]deny[[:space:]]*=[[:space:]]*(0|[6-9]|[1-9][0-9]+)\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "faillock deny is 1-5"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "faillock deny is not configured to 1-5"
    elif confirm_action "[${control_id}] Set deny = 5?"; then
        section5_write_security_conf "/etc/security/faillock.conf" "deny" "5"
        section5_remove_pam_arg "faillock" "deny[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "faillock deny configured"
    fi
    
    control_id="5.3.3.1.2"
    section5_start_check "${control_id}" "Ensure password unlock time is configured"
    if grep -Piq '^[[:space:]]*unlock_time[[:space:]]*=[[:space:]]*(0|9[0-9][0-9]|[1-9][0-9]{3,})\b' /etc/security/faillock.conf 2>/dev/null &&
       ! grep -Piq 'pam_faillock\.so.*[[:space:]]unlock_time[[:space:]]*=[[:space:]]*([1-9]|[1-9][0-9]|[1-8][0-9][0-9])\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "faillock unlock_time is 0 or at least 900"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "faillock unlock_time is not configured"
    elif confirm_action "[${control_id}] Set unlock_time = 900?"; then
        section5_write_security_conf "/etc/security/faillock.conf" "unlock_time" "900"
        section5_remove_pam_arg "faillock" "unlock_time[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "faillock unlock_time configured"
    fi
    
    control_id="5.3.3.1.3"
    section5_start_check "${control_id}" "Ensure password failed attempts lockout includes root account"
    if grep -Piq '^[[:space:]]*(even_deny_root|root_unlock_time[[:space:]]*=[[:space:]]*(6[0-9]|[7-9][0-9]|[1-9][0-9]{2,}))\b' /etc/security/faillock.conf 2>/dev/null &&
       ! grep -Piq 'pam_faillock\.so.*[[:space:]]root_unlock_time[[:space:]]*=[[:space:]]*([1-9]|[1-5][0-9])\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "root lockout is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "root lockout is not configured"
    elif confirm_action "[${control_id}] Set even_deny_root?"; then
        section5_write_security_flag "/etc/security/faillock.conf" "even_deny_root"
        section5_remove_pam_arg "faillock" "even_deny_root"
        section5_remove_pam_arg "faillock" "root_unlock_time[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "root lockout configured"
    fi
    
    section5_check_pwquality_min "5.3.3.2.1" "Ensure password number of changed characters is configured" "difok" "2" "2"
    section5_check_pwquality_min "5.3.3.2.2" "Ensure password length is configured" "minlen" "14" "14"
    
    control_id="5.3.3.2.3"
    section5_start_check "${control_id}" "Ensure password complexity is configured"
    if grep -Psiq '^[[:space:]]*(minclass|[dulo]credit)[[:space:]]*=' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null; then
        local complexity_settings=$(grep -Psi '^[[:space:]]*(minclass|[dulo]credit)[[:space:]]*=' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null || echo "No settings found")
        log_check_manual "${control_id}" \
            "Password complexity settings found; verify values match site policy" \
            "Current password complexity settings:
${complexity_settings}" \
            "Review and adjust password complexity settings according to organizational policy" \
            "1. Review current settings in /etc/security/pwquality.conf
2. Configure minclass (minimum character classes) or individual credit values:
   - dcredit: digit credit
   - ucredit: uppercase credit
   - lcredit: lowercase credit
   - ocredit: other character credit
3. Negative values require that many characters, positive values give credit
4. Example: dcredit=-1 requires at least 1 digit
5. Test with: pwscore <<< 'testpassword'" \
            "Password complexity requirements should align with organizational security policy"
        ((MANUAL_CHECKS++))
    else
        section5_manual "${control_id}" "configure minclass or d/u/l/o credit values according to site policy" \
            "No password complexity settings found in /etc/security/pwquality.conf" \
            "1. Edit /etc/security/pwquality.conf
2. Add complexity requirements (choose one approach):
   Option A - Use minclass: minclass = 3 (requires 3 character classes)
   Option B - Use individual credits:
     dcredit = -1 (require 1 digit)
     ucredit = -1 (require 1 uppercase)
     lcredit = -1 (require 1 lowercase)
     ocredit = -1 (require 1 special character)
3. Test with: pwscore <<< 'testpassword'" \
            "Password complexity helps prevent weak passwords"
    fi
    
    section5_check_pwquality_range_1_3 "5.3.3.2.4" "Ensure password same consecutive characters is configured" "maxrepeat"
    section5_check_pwquality_range_1_3 "5.3.3.2.5" "Ensure password maximum sequential characters is configured" "maxsequence"
    
    control_id="5.3.3.2.6"
    section5_start_check "${control_id}" "Ensure password dictionary check is enabled"
    if ! grep -Psiq '^[[:space:]]*dictcheck[[:space:]]*=[[:space:]]*0\b' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null &&
       ! grep -Piq 'pam_pwquality\.so.*[[:space:]]dictcheck[[:space:]]*=[[:space:]]*0\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "dictcheck is not disabled"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "dictcheck is disabled"
    elif confirm_action "[${control_id}] Remove dictcheck=0?"; then
        section5_pwquality_set "dictcheck" "1"
        section5_remove_pam_arg "pwquality" "dictcheck[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "dictcheck enabled"
    fi
    
    control_id="5.3.3.2.7"
    section5_start_check "${control_id}" "Ensure password quality is enforced for the root user"
    if grep -Psiq '^[[:space:]]*enforce_for_root\b' /etc/security/pwquality.conf /etc/security/pwquality.conf.d/*.conf 2>/dev/null; then
        section5_pass "${control_id}" "pwquality enforce_for_root is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pwquality enforce_for_root is not configured"
    elif confirm_action "[${control_id}] Set pwquality enforce_for_root?"; then
        section5_pwquality_flag "enforce_for_root"
        section5_remediated "${control_id}" "pwquality enforce_for_root configured"
    fi
    
    control_id="5.3.3.3.1"
    section5_start_check "${control_id}" "Ensure password history remember is configured"
    if grep -Piq '^[[:space:]]*remember[[:space:]]*=[[:space:]]*(2[4-9]|[3-9][0-9]|[1-9][0-9]{2,})\b' /etc/security/pwhistory.conf 2>/dev/null &&
       ! grep -Piq 'pam_pwhistory\.so.*[[:space:]]remember[[:space:]]*=[[:space:]]*(2[0-3]|1[0-9]|[0-9])\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "pwhistory remember is at least 24"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pwhistory remember is not configured to at least 24"
    elif confirm_action "[${control_id}] Set pwhistory remember = 24?"; then
        section5_write_security_conf "/etc/security/pwhistory.conf" "remember" "24"
        section5_remove_pam_arg "pwhistory" "remember[[:space:]]*=[[:space:]]*[^[:space:]]+"
        section5_remediated "${control_id}" "pwhistory remember configured"
    fi
    
    control_id="5.3.3.3.2"
    section5_start_check "${control_id}" "Ensure password history is enforced for the root user"
    if grep -Piq '^[[:space:]]*enforce_for_root\b' /etc/security/pwhistory.conf 2>/dev/null; then
        section5_pass "${control_id}" "pwhistory enforce_for_root is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pwhistory enforce_for_root is not configured"
    elif confirm_action "[${control_id}] Set pwhistory enforce_for_root?"; then
        section5_write_security_flag "/etc/security/pwhistory.conf" "enforce_for_root"
        section5_remediated "${control_id}" "pwhistory enforce_for_root configured"
    fi
    
    section5_check_pam_password_arg "5.3.3.3.3" "Ensure pam_pwhistory includes use_authtok" "pwhistory" "use_authtok"
    
    control_id="5.3.3.4.1"
    section5_start_check "${control_id}" "Ensure pam_unix does not include nullok"
    if ! grep -Piq 'pam_unix\.so.*[[:space:]]nullok\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "pam_unix nullok is not configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pam_unix nullok is configured"
    elif confirm_action "[${control_id}] Remove pam_unix nullok?"; then
        section5_enable_authselect_feature "without-nullok"
        section5_remove_pam_arg "unix" "nullok"
        section5_remediated "${control_id}" "pam_unix nullok removed"
    fi
    
    control_id="5.3.3.4.2"
    section5_start_check "${control_id}" "Ensure pam_unix does not include remember"
    if ! grep -Piq 'pam_unix\.so.*[[:space:]]remember=[0-9]+' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "pam_unix remember is not configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pam_unix remember is configured"
    elif confirm_action "[${control_id}] Remove pam_unix remember?"; then
        section5_remove_pam_arg "unix" "remember=[0-9]+"
        section5_remediated "${control_id}" "pam_unix remember removed"
    fi
    
    control_id="5.3.3.4.3"
    section5_start_check "${control_id}" "Ensure pam_unix includes a strong password hashing algorithm"
    if grep -Piq '^[[:space:]]*password[[:space:]]+[^#[:space:]]+[[:space:]]+pam_unix\.so.*[[:space:]](sha512|yescrypt)\b' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
        section5_pass "${control_id}" "pam_unix uses sha512 or yescrypt"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "pam_unix does not include sha512 or yescrypt"
    else
        section5_manual "${control_id}" "set sha512 or yescrypt in active authselect pam_unix password lines"
    fi
    
    section5_check_pam_password_arg "5.3.3.4.4" "Ensure pam_unix includes use_authtok" "unix" "use_authtok"
}

remediate_user_accounts_environment() {
    if ! section5_should_run "5.4"; then
        return 0
    fi
    
    log_info "=== Section 5.4: User Accounts and Environment ==="
    
    local control_id uid_min
    uid_min="$(section5_uid_min)"
    
    control_id="5.4.1.1"
    section5_start_check "${control_id}" "Ensure password expiration is configured"
    if grep -Piq '^[[:space:]]*PASS_MAX_DAYS[[:space:]]+([1-9]|[1-9][0-9]|[1-2][0-9]{2}|3[0-5][0-9]|36[0-5])\b' /etc/login.defs 2>/dev/null &&
       ! awk -F: '($2 ~ /^\$.+\$/ && ($5 > 365 || $5 < 1)) { bad=1 } END { exit bad ? 0 : 1 }' /etc/shadow 2>/dev/null; then
        section5_pass "${control_id}" "PASS_MAX_DAYS is 1-365"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "PASS_MAX_DAYS or user max days are not compliant"
    elif confirm_action "[${control_id}] Set PASS_MAX_DAYS 365 and update users?"; then
        section5_write_kv "/etc/login.defs" "PASS_MAX_DAYS" "365"
        awk -F: '($2 ~ /^\$.+\$/ && ($5 > 365 || $5 < 1)) { print $1 }' /etc/shadow | while read -r user; do chage --maxdays 365 "${user}" 2>/dev/null || true; done
        section5_remediated "${control_id}" "password expiration configured"
    fi
    
    control_id="5.4.1.2"
    section5_start_check "${control_id}" "Ensure minimum password days is configured"
    if grep -Piq '^[[:space:]]*PASS_MIN_DAYS[[:space:]]+[1-9][0-9]*\b' /etc/login.defs 2>/dev/null &&
       ! awk -F: '($2 ~ /^\$.+\$/ && $4 < 1) { bad=1 } END { exit bad ? 0 : 1 }' /etc/shadow 2>/dev/null; then
        local pass_min_days=$(grep -Pi '^[[:space:]]*PASS_MIN_DAYS' /etc/login.defs 2>/dev/null || echo "Not found")
        local users_below_min=$(awk -F: '($2 ~ /^\$.+\$/ && $4 < 1) { print $1 " (min days: " $4 ")" }' /etc/shadow 2>/dev/null || echo "None")
        log_check_manual "${control_id}" \
            "PASS_MIN_DAYS is configured; verify value matches site policy" \
            "Current configuration:
${pass_min_days}

Users with min days < 1:
${users_below_min}" \
            "Verify PASS_MIN_DAYS value meets organizational policy" \
            "1. Check current setting: grep PASS_MIN_DAYS /etc/login.defs
2. Verify value meets policy (typically 1-7 days)
3. Check user settings: awk -F: '\$4 < 1 {print \$1, \$4}' /etc/shadow
4. Update users if needed: chage --mindays <days> <username>
5. Document approved value in security policy" \
            "Minimum password age prevents users from rapidly changing passwords to circumvent password history"
        ((MANUAL_CHECKS++))
    else
        local pass_min_days=$(grep -Pi '^[[:space:]]*PASS_MIN_DAYS' /etc/login.defs 2>/dev/null || echo "PASS_MIN_DAYS not configured or set to 0")
        section5_manual "${control_id}" "set PASS_MIN_DAYS greater than 0 and update users according to site policy" \
            "Current setting: ${pass_min_days}" \
            "1. Edit /etc/login.defs
2. Set PASS_MIN_DAYS to a value > 0 (typically 1-7)
3. Update existing users: awk -F: '\$4 < 1 {print \$1}' /etc/shadow | while read user; do chage --mindays <days> \$user; done
4. Verify: chage -l <username>" \
            "Minimum password age prevents rapid password changes"
    fi
    
    control_id="5.4.1.3"
    section5_start_check "${control_id}" "Ensure password expiration warning days is configured"
    if grep -Piq '^[[:space:]]*PASS_WARN_AGE[[:space:]]+([7-9]|[1-9][0-9]+)\b' /etc/login.defs 2>/dev/null &&
       ! awk -F: '($2 ~ /^\$.+\$/ && $6 < 7) { bad=1 } END { exit bad ? 0 : 1 }' /etc/shadow 2>/dev/null; then
        section5_pass "${control_id}" "PASS_WARN_AGE is at least 7"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "PASS_WARN_AGE or user warning days are not compliant"
    elif confirm_action "[${control_id}] Set PASS_WARN_AGE 7 and update users?"; then
        section5_write_kv "/etc/login.defs" "PASS_WARN_AGE" "7"
        awk -F: '($2 ~ /^\$.+\$/ && $6 < 7) { print $1 }' /etc/shadow | while read -r user; do chage --warndays 7 "${user}" 2>/dev/null || true; done
        section5_remediated "${control_id}" "password warning days configured"
    fi
    
    control_id="5.4.1.4"
    section5_start_check "${control_id}" "Ensure strong password hashing algorithm is configured"
    if grep -Piq '^[[:space:]]*ENCRYPT_METHOD[[:space:]]+(SHA512|YESCRYPT|yescrypt)\b' /etc/login.defs 2>/dev/null; then
        section5_pass "${control_id}" "ENCRYPT_METHOD is strong"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "ENCRYPT_METHOD is not SHA512 or YESCRYPT"
    elif confirm_action "[${control_id}] Set ENCRYPT_METHOD YESCRYPT?"; then
        section5_write_kv "/etc/login.defs" "ENCRYPT_METHOD" "YESCRYPT"
        section5_remediated "${control_id}" "ENCRYPT_METHOD configured"
    fi
    
    control_id="5.4.1.5"
    section5_start_check "${control_id}" "Ensure inactive password lock is configured"
    local inactive_default
    inactive_default="$(useradd -D 2>/dev/null | awk -F= '$1 == "INACTIVE" { print $2 }')"
    if [[ "${inactive_default}" =~ ^[0-9]+$ && "${inactive_default}" -le 45 ]] &&
       ! awk -F: '($2 ~ /^\$.+\$/ && ($7 > 45 || $7 < 0)) { bad=1 } END { exit bad ? 0 : 1 }' /etc/shadow 2>/dev/null; then
        section5_pass "${control_id}" "inactive password lock is 45 days or less"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "inactive password lock is not compliant"
    elif confirm_action "[${control_id}] Set inactive password lock to 45 days?"; then
        useradd -D -f 45 >/dev/null 2>&1 || true
        awk -F: '($2 ~ /^\$.+\$/ && ($7 > 45 || $7 < 0)) { print $1 }' /etc/shadow | while read -r user; do chage --inactive 45 "${user}" 2>/dev/null || true; done
        section5_remediated "${control_id}" "inactive password lock configured"
    fi
    
    control_id="5.4.1.6"
    section5_start_check "${control_id}" "Ensure all users last password change date is in the past"
    local future_users
    future_users="$(while IFS= read -r user; do
        local_date="$(chage --list "${user}" 2>/dev/null | awk -F: '/^Last password change/ { gsub(/^[[:space:]]+/, "", $2); print $2 }')"
        [[ -n "${local_date}" && "${local_date}" != "never" ]] || continue
        change_epoch="$(date -d "${local_date}" +%s 2>/dev/null || echo 0)"
        [[ "${change_epoch}" -gt "$(date +%s)" ]] && printf '%s\n' "${user}"
    done < <(awk -F: '$2 ~ /^\$.+\$/ { print $1 }' /etc/shadow 2>/dev/null))"
    if [[ -z "${future_users}" ]]; then
        section5_pass "${control_id}" "no users have future password change dates"
    else
        section5_manual "${control_id}" "users with future password change dates: ${future_users//$'\n'/ }"
    fi
    
    control_id="5.4.2.1"
    section5_start_check "${control_id}" "Ensure root is the only UID 0 account"
    local uid0_users
    uid0_users="$(awk -F: '$3 == 0 { print $1 }' /etc/passwd 2>/dev/null)"
    if [[ "${uid0_users}" == "root" ]]; then
        section5_pass "${control_id}" "root is the only UID 0 account"
    else
        section5_manual "${control_id}" "UID 0 accounts found: ${uid0_users//$'\n'/ }"
    fi
    
    control_id="5.4.2.2"
    section5_start_check "${control_id}" "Ensure root is the only GID 0 account"
    local gid0_users
    gid0_users="$(awk -F: '($1 !~ /^(sync|shutdown|halt|operator)$/ && $4 == 0) { print $1 ":" $4 }' /etc/passwd 2>/dev/null)"
    if [[ "${gid0_users}" == "root:0" ]]; then
        section5_pass "${control_id}" "root is the only non-exempt primary GID 0 account"
    else
        section5_manual "${control_id}" "non-exempt GID 0 accounts found: ${gid0_users//$'\n'/ }"
    fi
    
    control_id="5.4.2.3"
    section5_start_check "${control_id}" "Ensure group root is the only GID 0 group"
    local gid0_groups
    gid0_groups="$(awk -F: '$3 == 0 { print $1 ":" $3 }' /etc/group 2>/dev/null)"
    if [[ "${gid0_groups}" == "root:0" ]]; then
        section5_pass "${control_id}" "root is the only GID 0 group"
    else
        section5_manual "${control_id}" "GID 0 groups found: ${gid0_groups//$'\n'/ }"
    fi
    
    control_id="5.4.2.4"
    section5_start_check "${control_id}" "Ensure root account access is controlled"
    local root_status
    root_status="$(passwd -S root 2>/dev/null | awk '{ print $2 }')"
    if [[ "${root_status}" =~ ^(P|PS|L|LK)$ ]]; then
        section5_pass "${control_id}" "root password is set or account is locked"
    else
        section5_manual "${control_id}" "set a root password or lock the root account"
    fi
    
    control_id="5.4.2.5"
    section5_start_check "${control_id}" "Ensure root path integrity"
    local path_fail=""
    IFS=':' read -ra root_path_parts <<< "${PATH}"
    for dir in "${root_path_parts[@]}"; do
        if [[ -z "${dir}" || "${dir}" == "." ]]; then
            path_fail="${path_fail} empty-or-dot"
            continue
        fi
        if [[ ! -d "${dir}" ]]; then
            path_fail="${path_fail} missing:${dir}"
            continue
        fi
        owner="$(stat -Lc '%U' "${dir}" 2>/dev/null)"
        mode="$(stat -Lc '%a' "${dir}" 2>/dev/null)"
        if [[ "${owner}" != "root" || $(( 8#${mode} & 022 )) -ne 0 ]]; then
            path_fail="${path_fail} ${dir}(${owner}:${mode})"
        fi
    done
    if [[ -z "${path_fail}" ]]; then
        section5_pass "${control_id}" "root PATH integrity checks passed"
    else
        section5_manual "${control_id}" "root PATH issues:${path_fail}"
    fi
    
    control_id="5.4.2.6"
    section5_start_check "${control_id}" "Ensure root user umask is configured"
    if grep -Psiq '^[[:space:]]*umask[[:space:]]+0?([27]7|077)\b' /root/.bashrc /root/.bash_profile /root/.profile 2>/dev/null; then
        section5_pass "${control_id}" "root umask is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "root umask is not configured"
    elif confirm_action "[${control_id}] Configure root umask 027?"; then
        section5_backup_if_exists "/root/.bashrc"
        printf '\n%s\n' "umask 027" >> /root/.bashrc
        section5_remediated "${control_id}" "root umask configured"
    fi
    
    control_id="5.4.2.7"
    section5_start_check "${control_id}" "Ensure system accounts do not have a valid login shell"
    local valid_shells bad_system_accounts nologin_path
    valid_shells="$(section5_valid_shell_regex)"
    nologin_path="$(command -v nologin 2>/dev/null || printf '/sbin/nologin')"
    bad_system_accounts="$(awk -v uid_min="${uid_min}" -v pat="^(${valid_shells})$" -F: '($1 !~ /^(root|halt|sync|shutdown|nfsnobody)$/ && ($3 < uid_min || $3 == 65534) && $NF ~ pat) { print $1 }' /etc/passwd 2>/dev/null)"
    if [[ -z "${bad_system_accounts}" ]]; then
        section5_pass "${control_id}" "system accounts do not have valid login shells"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "system accounts with valid shells: ${bad_system_accounts//$'\n'/ }"
    elif confirm_action "[${control_id}] Set system account shells to nologin?"; then
        while read -r user; do [[ -n "${user}" ]] && usermod -s "${nologin_path}" "${user}" 2>/dev/null || true; done <<< "${bad_system_accounts}"
        section5_remediated "${control_id}" "system account shells set to nologin"
    fi
    
    control_id="5.4.2.8"
    section5_start_check "${control_id}" "Ensure accounts without a valid login shell are locked"
    local unlocked_no_shell
    unlocked_no_shell="$(awk -v pat="^(${valid_shells})$" -F: '($1 != "root" && $NF !~ pat) { print $1 }' /etc/passwd 2>/dev/null | while read -r user; do passwd -S "${user}" 2>/dev/null | awk '$2 !~ /^(L|LK)$/ { print $1 }'; done)"
    if [[ -z "${unlocked_no_shell}" ]]; then
        section5_pass "${control_id}" "accounts without valid login shells are locked"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "accounts without valid shell are unlocked: ${unlocked_no_shell//$'\n'/ }"
    elif confirm_action "[${control_id}] Lock accounts without valid login shells?"; then
        while read -r user; do [[ -n "${user}" ]] && usermod -L "${user}" 2>/dev/null || true; done <<< "${unlocked_no_shell}"
        section5_remediated "${control_id}" "accounts without valid shells locked"
    fi
    
    control_id="5.4.3.1"
    section5_start_check "${control_id}" "Ensure nologin is not listed in /etc/shells"
    if ! grep -Psiq '^[[:space:]]*[^#].*/nologin\b' /etc/shells 2>/dev/null; then
        section5_pass "${control_id}" "nologin is not listed in /etc/shells"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "nologin is listed in /etc/shells"
    elif confirm_action "[${control_id}] Remove nologin from /etc/shells?"; then
        section5_backup_if_exists "/etc/shells"
        sed -ri '/^[[:space:]]*[^#].*\/nologin\b/d' /etc/shells
        section5_remediated "${control_id}" "nologin removed from /etc/shells"
    fi
    
    control_id="5.4.3.2"
    section5_start_check "${control_id}" "Ensure default user shell timeout is configured"
    if grep -Psiq '^[[:space:]]*(typeset[[:space:]]+-xr[[:space:]]+TMOUT=|TMOUT=)([1-9][0-9]{0,2}|900)\b' /etc/profile /etc/bashrc /etc/profile.d/*.sh 2>/dev/null &&
       grep -Psiq '^[[:space:]]*(readonly[[:space:]]+TMOUT|typeset[[:space:]]+-xr[[:space:]]+TMOUT=)' /etc/profile /etc/bashrc /etc/profile.d/*.sh 2>/dev/null &&
       grep -Psiq '^[[:space:]]*(export[[:space:]].*TMOUT|typeset[[:space:]]+-xr[[:space:]]+TMOUT=)' /etc/profile /etc/bashrc /etc/profile.d/*.sh 2>/dev/null; then
        section5_pass "${control_id}" "TMOUT is configured"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "TMOUT is not correctly configured"
    elif confirm_action "[${control_id}] Configure TMOUT 900?"; then
        section5_backup_if_exists "${SECTION5_TMOUT_FILE}"
        printf '%s\n' "# CIS 5.4.3.2" "typeset -xr TMOUT=900" > "${SECTION5_TMOUT_FILE}"
        chmod 0644 "${SECTION5_TMOUT_FILE}" 2>/dev/null || true
        section5_remediated "${control_id}" "TMOUT configured"
    fi
    
    control_id="5.4.3.3"
    section5_start_check "${control_id}" "Ensure default user umask is configured"
    if grep -Psiq '^[[:space:]]*umask[[:space:]]+(0?27|0?77|u=rwx,g=rx,o=)\b' /etc/profile /etc/bashrc /etc/profile.d/*.sh /etc/login.defs 2>/dev/null; then
        section5_pass "${control_id}" "default user umask is restrictive"
    elif [[ "${DRY_RUN}" == true ]]; then
        section5_fail "${control_id}" "default user umask is not configured"
    elif confirm_action "[${control_id}] Configure default umask 027?"; then
        section5_backup_if_exists "${SECTION5_UMASK_FILE}"
        printf '%s\n' "# CIS 5.4.3.3" "umask 027" > "${SECTION5_UMASK_FILE}"
        chmod 0644 "${SECTION5_UMASK_FILE}" 2>/dev/null || true
        section5_write_kv "/etc/login.defs" "UMASK" "027"
        section5_remediated "${control_id}" "default user umask configured"
    fi
}

run_section_5() {
    if ! section5_selected; then
        log_info "Skipping Section 5: Access Control (not selected)"
        return 0
    fi
    
    log_info "=== Section 5: Access Control ==="
    remediate_ssh_server
    remediate_privilege_escalation
    remediate_pam
    remediate_user_accounts_environment
}


