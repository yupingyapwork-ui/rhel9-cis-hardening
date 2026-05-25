#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 1: Initial Setup
# Version: 2.0.0
# Description: Implementation of CIS Section 1 controls
################################################################################

################################################################################
# SECTION 1.1: FILESYSTEM CONFIGURATION
################################################################################

disable_filesystem_module() {
    local module_name="$1"
    local control_id="$2"
    
    if [[ "${DRY_RUN}" == true ]]; then
        if lsmod | grep -q "^${module_name}"; then
            log_warning "[${control_id}] FAIL: ${module_name} module is loaded"
            ((FAILED_CHECKS++))
            return 1
        else
            log_success "[${control_id}] PASS: ${module_name} module is not loaded"
            ((PASSED_CHECKS++))
            return 0
        fi
    fi
    
    if ! confirm_action "[${control_id}] Disable ${module_name} kernel module?"; then
        return 0
    fi
    
    backup_file "/etc/modprobe.d/${module_name}.conf"
    
    cat > "/etc/modprobe.d/${module_name}.conf" << EOF
# CIS Benchmark - Disable ${module_name}
install ${module_name} /bin/true
blacklist ${module_name}
EOF
    
    if lsmod | grep -q "^${module_name}"; then
        rmmod "${module_name}" 2>/dev/null || true
    fi
    
    log_success "[${control_id}] Remediated: ${module_name} disabled"
    ((REMEDIATED_CHECKS++))
    return 0
}

remediate_filesystem_modules() {
    if ! should_run_section "1.1"; then
        log_info "Skipping Section 1.1: Filesystem Configuration (not selected)"
        return 0
    fi
    
    log_info "=== Section 1.1.1: Filesystem Kernel Modules ==="
    
    # 1.1.1.1 - cramfs
    disable_filesystem_module "cramfs" "1.1.1.1"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.2 - freevxfs
    disable_filesystem_module "freevxfs" "1.1.1.2"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.3 - hfs
    disable_filesystem_module "hfs" "1.1.1.3"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.4 - hfsplus
    disable_filesystem_module "hfsplus" "1.1.1.4"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.5 - jffs2
    disable_filesystem_module "jffs2" "1.1.1.5"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.6 - squashfs
    disable_filesystem_module "squashfs" "1.1.1.6"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.7 - udf
    disable_filesystem_module "udf" "1.1.1.7"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.8 - usb-storage
    disable_filesystem_module "usb-storage" "1.1.1.8"
    ((TOTAL_CHECKS++))
    
    # 1.1.1.9 - Ensure unused filesystems kernel modules are not available
    log_info "[1.1.1.9] Ensure unused filesystems kernel modules are not available"
    local modules_1_1_1_9=("afs" "cifs" "dlm" "erofs" "exfat" "gfs2" "isofs" "nfsd" "smb" "smbfs_common")
    ((TOTAL_CHECKS++))
    
    for module in "${modules_1_1_1_9[@]}"; do
        if [[ "${DRY_RUN}" == true ]]; then
            if lsmod | grep -q "^${module}"; then
                log_warning "[1.1.1.9] FAIL: ${module} module is loaded"
                ((FAILED_CHECKS++))
            else
                log_success "[1.1.1.9] PASS: ${module} module is not loaded"
                ((PASSED_CHECKS++))
            fi
            continue
        fi
        
        if ! confirm_action "[1.1.1.9] Disable ${module} kernel module?"; then
            continue
        fi
        
        backup_file "/etc/modprobe.d/${module}.conf"
        
        cat > "/etc/modprobe.d/${module}.conf" << EOF
# CIS Benchmark 1.1.1.9 - Disable ${module}
install ${module} /bin/true
blacklist ${module}
EOF
        
        if lsmod | grep -q "^${module}"; then
            rmmod "${module}" 2>/dev/null || true
        fi
        
        log_success "[1.1.1.9] Remediated: ${module} disabled"
        ((REMEDIATED_CHECKS++))
    done
}

mount_has_option() {
    local partition="$1"
    local option="$2"
    
    findmnt -n -o OPTIONS --target "${partition}" 2>/dev/null | tr ',' '\n' | grep -Fxq "${option}"
}

fstab_has_mount_option() {
    local partition="$1"
    local option="$2"
    
    awk -v partition="${partition}" -v option="${option}" '
        $0 !~ /^[[:space:]]*#/ && $2 == partition {
            n = split($4, options, ",")
            for (i = 1; i <= n; i++) {
                if (options[i] == option) {
                    found = 1
                }
            }
        }
        END { exit found ? 0 : 1 }
    ' /etc/fstab
}

fstab_has_mount_entry() {
    local partition="$1"
    
    awk -v partition="${partition}" '
        $0 !~ /^[[:space:]]*#/ && $2 == partition {
            found = 1
        }
        END { exit found ? 0 : 1 }
    ' /etc/fstab
}

fstab_add_mount_option() {
    local partition="$1"
    local option="$2"
    local temp_fstab
    
    temp_fstab="$(mktemp)" || return 1
    
    if awk -v partition="${partition}" -v option="${option}" '
        BEGIN { OFS = "\t" }
        $0 ~ /^[[:space:]]*#/ || $2 != partition {
            print
            next
        }
        {
            found = 0
            n = split($4, options, ",")
            for (i = 1; i <= n; i++) {
                if (options[i] == option) {
                    found = 1
                }
            }
            if (!found) {
                if ($4 == "" || $4 == "-") {
                    $4 = option
                } else {
                    $4 = $4 "," option
                }
            }
            print
        }
    ' /etc/fstab > "${temp_fstab}" && cp "${temp_fstab}" /etc/fstab; then
        rm -f "${temp_fstab}"
        return 0
    fi
    
    rm -f "${temp_fstab}"
    return 1
}

configure_partition_options() {
    local partition="$1"
    local option="$2"
    local control_id="$3"
    
    log_info "[${control_id}] Ensure ${option} option set on ${partition} partition"
    
    if ! findmnt -n "${partition}" &>/dev/null; then
        log_warning "[${control_id}] SKIP: ${partition} is not a separate partition"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        if mount_has_option "${partition}" "${option}"; then
            log_success "[${control_id}] PASS: ${option} option is set on ${partition}"
            ((PASSED_CHECKS++))
            return 0
        else
            log_warning "[${control_id}] FAIL: ${option} option is not set on ${partition}"
            ((FAILED_CHECKS++))
            return 1
        fi
    fi
    
    if ! confirm_action "[${control_id}] Set ${option} option on ${partition}?"; then
        return 0
    fi
    
    backup_file "/etc/fstab"
    
    if fstab_has_mount_entry "${partition}"; then
        if fstab_has_mount_option "${partition}" "${option}" && mount_has_option "${partition}" "${option}"; then
            log_success "[${control_id}] PASS: ${option} option is already set on ${partition}"
            ((PASSED_CHECKS++))
            return 0
        fi
        
        if fstab_add_mount_option "${partition}" "${option}"; then
            mount -o remount,"${option}" "${partition}" 2>/dev/null || true
            
            if fstab_has_mount_option "${partition}" "${option}" && mount_has_option "${partition}" "${option}"; then
                log_success "[${control_id}] Remediated: ${option} option set on ${partition}"
                ((REMEDIATED_CHECKS++))
                return 0
            fi
            
            log_warning "[${control_id}] Remediation attempted; verify ${option} option on ${partition} manually"
            ((FAILED_CHECKS++))
            ((MANUAL_CHECKS++))
            return 1
        fi
        
        log_error "[${control_id}] Failed to update /etc/fstab for ${partition}"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    log_warning "[${control_id}] FAIL: ${partition} entry not found in /etc/fstab"
    ((FAILED_CHECKS++))
    ((MANUAL_CHECKS++))
    return 1
}

check_separate_partition() {
    local partition="$1"
    local control_id="$2"
    
    log_info "[${control_id}] Ensure separate partition exists for ${partition}"
    ((TOTAL_CHECKS++))
    
    if findmnt -n "${partition}" &>/dev/null; then
        log_success "[${control_id}] PASS: ${partition} is a separate partition"
        ((PASSED_CHECKS++))
        return 0
    else
        log_warning "[${control_id}] FAIL: ${partition} is not a separate partition"
        ((FAILED_CHECKS++))
        ((MANUAL_CHECKS++))
        return 1
    fi
}

remediate_partition_options() {
    if ! should_run_section "1.1"; then
        return 0
    fi
    
    log_info "=== Section 1.1.2: Partition Configuration ==="
    
    # 1.1.2.1.x - /tmp partition
    check_separate_partition "/tmp" "1.1.2.1.1"
    configure_partition_options "/tmp" "nodev" "1.1.2.1.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/tmp" "nosuid" "1.1.2.1.3"
    ((TOTAL_CHECKS++))
    configure_partition_options "/tmp" "noexec" "1.1.2.1.4"
    ((TOTAL_CHECKS++))
    
    # 1.1.2.2.x - /dev/shm partition
    check_separate_partition "/dev/shm" "1.1.2.2.1"
    configure_partition_options "/dev/shm" "nodev" "1.1.2.2.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/dev/shm" "nosuid" "1.1.2.2.3"
    ((TOTAL_CHECKS++))
    configure_partition_options "/dev/shm" "noexec" "1.1.2.2.4"
    ((TOTAL_CHECKS++))
    
    # 1.1.2.3.x - /home partition
    check_separate_partition "/home" "1.1.2.3.1"
    configure_partition_options "/home" "nodev" "1.1.2.3.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/home" "nosuid" "1.1.2.3.3"
    ((TOTAL_CHECKS++))
    
    # 1.1.2.4.x - /var partition
    check_separate_partition "/var" "1.1.2.4.1"
    configure_partition_options "/var" "nodev" "1.1.2.4.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var" "nosuid" "1.1.2.4.3"
    ((TOTAL_CHECKS++))
    
    # 1.1.2.5.x - /var/tmp partition
    check_separate_partition "/var/tmp" "1.1.2.5.1"
    configure_partition_options "/var/tmp" "nodev" "1.1.2.5.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var/tmp" "nosuid" "1.1.2.5.3"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var/tmp" "noexec" "1.1.2.5.4"
    ((TOTAL_CHECKS++))
    
    # 1.1.2.6.x - /var/log partition
    check_separate_partition "/var/log" "1.1.2.6.1"
    configure_partition_options "/var/log" "nodev" "1.1.2.6.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var/log" "nosuid" "1.1.2.6.3"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var/log" "noexec" "1.1.2.6.4"
    ((TOTAL_CHECKS++))
    
    # 1.1.2.7.x - /var/log/audit partition
    check_separate_partition "/var/log/audit" "1.1.2.7.1"
    configure_partition_options "/var/log/audit" "nodev" "1.1.2.7.2"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var/log/audit" "nosuid" "1.1.2.7.3"
    ((TOTAL_CHECKS++))
    configure_partition_options "/var/log/audit" "noexec" "1.1.2.7.4"
    ((TOTAL_CHECKS++))
}

################################################################################
# SECTION 1.2: SOFTWARE UPDATES
################################################################################

remediate_software_updates() {
    if ! should_run_section "1.2"; then
        log_info "Skipping Section 1.2: Software Updates (not selected)"
        return 0
    fi
    
    log_info "=== Section 1.2: Software Updates ==="
    
    # 1.2.1.1 - GPG keys
    local control_id="1.2.1.1"
    log_info "[${control_id}] Ensure GPG keys are configured"
    ((TOTAL_CHECKS++))
    
    if rpm -q gpg-pubkey &>/dev/null; then
        log_success "[${control_id}] PASS: GPG keys are configured"
        ((PASSED_CHECKS++))
    else
        local gpg_keys=$(rpm -q gpg-pubkey 2>&1 || echo "No GPG keys installed")
        log_check_manual "${control_id}" \
            "GPG keys need to be configured manually" \
            "Current GPG keys: ${gpg_keys}" \
            "Install and configure GPG keys for package verification" \
            "1. Import GPG keys using: rpm --import <key-file>
2. Verify keys are installed: rpm -q gpg-pubkey
3. Ensure all repositories use gpgcheck=1" \
            "GPG keys are essential for verifying package authenticity and integrity"
        ((FAILED_CHECKS++))
        ((MANUAL_CHECKS++))
    fi
    
    # 1.2.1.2 - gpgcheck globally activated
    control_id="1.2.1.2"
    log_info "[${control_id}] Ensure gpgcheck is globally activated"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if grep -qE "^[[:space:]]*gpgcheck[[:space:]]*=[[:space:]]*1" /etc/dnf/dnf.conf 2>/dev/null; then
            log_success "[${control_id}] PASS: gpgcheck is enabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: gpgcheck is not enabled"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Enable gpgcheck globally?"; then
        backup_file "/etc/dnf/dnf.conf"
        
        if grep -qE "^[[:space:]]*gpgcheck[[:space:]]*=" /etc/dnf/dnf.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*gpgcheck[[:space:]]*=.*/gpgcheck=1/' /etc/dnf/dnf.conf
        else
            echo "gpgcheck=1" >> /etc/dnf/dnf.conf
        fi
        
        log_success "[${control_id}] Remediated: gpgcheck enabled globally"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 1.2.1.3 - repo_gpgcheck
    control_id="1.2.1.3"
    log_info "[${control_id}] Ensure repo_gpgcheck is globally activated"
    ((TOTAL_CHECKS++))

    if [[ "${DRY_RUN}" == true ]]; then
        if grep -qE "^[[:space:]]*repo_gpgcheck[[:space:]]*=[[:space:]]*1" /etc/dnf/dnf.conf 2>/dev/null && \
           ! grep -RqsE "^[[:space:]]*repo_gpgcheck[[:space:]]*=[[:space:]]*0" /etc/yum.repos.d/ 2>/dev/null; then
            log_success "[${control_id}] PASS: repo_gpgcheck is enabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: repo_gpgcheck is not enabled globally or is overridden"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Enable repo_gpgcheck globally?"; then
        backup_file "/etc/dnf/dnf.conf"

        if grep -qE "^[[:space:]]*repo_gpgcheck[[:space:]]*=" /etc/dnf/dnf.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*repo_gpgcheck[[:space:]]*=.*/repo_gpgcheck=1/' /etc/dnf/dnf.conf
        else
            echo "repo_gpgcheck=1" >> /etc/dnf/dnf.conf
        fi

        if compgen -G "/etc/yum.repos.d/*.repo" >/dev/null; then
            local repo_file
            for repo_file in /etc/yum.repos.d/*.repo; do
                backup_file "${repo_file}"
                sed -i 's/^[[:space:]]*repo_gpgcheck[[:space:]]*=[[:space:]]*0/repo_gpgcheck=1/' "${repo_file}"
            done
        fi

        log_success "[${control_id}] Remediated: repo_gpgcheck enabled globally"
        ((REMEDIATED_CHECKS++))
    fi
    
    # 1.2.1.4 - package manager repositories
    control_id="1.2.1.4"
    log_info "[${control_id}] Ensure package manager repositories are configured"
    ((TOTAL_CHECKS++))
    
    local repo_list=$(yum repolist 2>/dev/null | grep -E "^[^!]" | tail -n +2 || echo "Unable to list repositories")
    local repo_count=$(yum repolist 2>/dev/null | grep -c "^[^!]" || echo "0")
    log_check_manual "${control_id}" \
        "Repository configuration must be verified manually" \
        "Current repositories (${repo_count} enabled):
${repo_list}" \
        "Review and configure package manager repositories according to organizational policy" \
        "1. List current repositories: yum repolist all
2. Review repository configuration files in /etc/yum.repos.d/
3. Ensure only approved repositories are enabled
4. Verify gpgcheck=1 is set for all repositories
5. Remove or disable unauthorized repositories" \
        "Only use repositories from trusted sources. Unauthorized repositories may contain malicious packages"
    ((MANUAL_CHECKS++))
    
    # 1.2.2.1 - updates
    control_id="1.2.2.1"
    log_info "[${control_id}] Ensure updates, patches, and additional security software are installed"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local updates=$(dnf check-update --quiet 2>/dev/null | wc -l)
        if [[ ${updates} -eq 0 ]]; then
            log_success "[${control_id}] PASS: System is up to date"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${updates} updates available"
            ((FAILED_CHECKS++))
        fi
    else
        if confirm_action "[${control_id}] Install all available updates?"; then
            local dnf_output
            dnf_output="$(mktemp)" || {
                log_error "[${control_id}] Failed to create temporary log for dnf output"
                ((FAILED_CHECKS++))
                return 1
            }
            
            if dnf upgrade -y > "${dnf_output}" 2>&1; then
                log_success "[${control_id}] Remediated: All available updates installed"
                ((REMEDIATED_CHECKS++))
            else
                log_error "[${control_id}] Failed to install all available updates"
                if [[ -s "${dnf_output}" ]]; then
                    log_error "[${control_id}] dnf output follows:"
                    while IFS= read -r line; do
                        [[ -n "${line}" ]] && log_error "[${control_id}] dnf: ${line}"
                    done < <(tail -n 25 "${dnf_output}")
                else
                    log_error "[${control_id}] dnf produced no output"
                fi
                ((FAILED_CHECKS++))
            fi
            
            rm -f "${dnf_output}"
        fi
    fi
}

################################################################################
# SECTION 6.1: SYSTEM FILE INTEGRITY
################################################################################
# AIDE implementation moved to lib/section-6.sh

################################################################################
# SECTION 1.4: SECURE BOOT
################################################################################

remediate_secure_boot() {
    if ! should_run_section "1.4"; then
        log_info "Skipping Section 1.4: Secure Boot Settings (not selected)"
        return 0
    fi
    
    log_info "=== Section 1.4: Secure Boot Settings ==="
    
    local control_id="1.4.1"
    log_info "[${control_id}] Ensure bootloader password is set"
    ((TOTAL_CHECKS++))
    
    if [[ -f /boot/grub2/user.cfg ]]; then
        log_success "[${control_id}] PASS: Bootloader password is configured"
        ((PASSED_CHECKS++))
    else
        local grub_status="Bootloader password file /boot/grub2/user.cfg does not exist"
        log_check_manual "${control_id}" \
            "Bootloader password must be set manually using grub2-setpassword" \
            "${grub_status}" \
            "Set a bootloader password to prevent unauthorized modifications" \
            "1. Run: grub2-setpassword
2. Enter a strong password when prompted
3. Verify /boot/grub2/user.cfg was created
4. Ensure permissions are 0600: chmod 0600 /boot/grub2/user.cfg" \
            "A bootloader password prevents unauthorized users from modifying boot parameters or accessing single-user mode"
        ((MANUAL_CHECKS++))
    fi
    
    control_id="1.4.2"
    log_info "[${control_id}] Ensure permissions on bootloader config are configured"
    ((TOTAL_CHECKS++))
    
    local grub_cfg="/boot/grub2/grub.cfg"
    
    if [[ ! -f "${grub_cfg}" ]]; then
        log_warning "[${control_id}] SKIP: Bootloader config not found"
        return 0
    fi
    
    if [[ "${DRY_RUN}" == true ]]; then
        local perms=$(stat -c %a "${grub_cfg}" 2>/dev/null)
        if [[ "${perms}" == "600" ]]; then
            log_success "[${control_id}] PASS: Bootloader config permissions correct"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Permissions are ${perms}"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Set bootloader config permissions to 600?"; then
        chmod 600 "${grub_cfg}" 2>/dev/null
        chown root:root "${grub_cfg}" 2>/dev/null
        log_success "[${control_id}] Remediated: Bootloader config permissions set"
        ((REMEDIATED_CHECKS++))
    fi
}

################################################################################
# SECTION 1.5: PROCESS HARDENING
################################################################################

remediate_process_hardening() {
    if ! should_run_section "1.5"; then
        log_info "Skipping Section 1.5: Additional Process Hardening (not selected)"
        return 0
    fi
    
    log_info "=== Section 1.5: Additional Process Hardening ==="
    
    local control_id="1.5.1"
    log_info "[${control_id}] Ensure address space layout randomization (ASLR) is enabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local aslr=$(sysctl -n kernel.randomize_va_space 2>/dev/null)
        if [[ "${aslr}" == "2" ]]; then
            log_success "[${control_id}] PASS: ASLR enabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ASLR not properly configured"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Enable ASLR?"; then
        backup_file "/etc/security/limits.conf"
        backup_file "/etc/sysctl.conf"
        
        if grep -qE "^[[:space:]]*kernel.randomize_va_space[[:space:]]*=" /etc/sysctl.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*kernel.randomize_va_space[[:space:]]*=.*/kernel.randomize_va_space = 2/' /etc/sysctl.conf
        else
            echo "kernel.randomize_va_space = 2" >> /etc/sysctl.conf
        fi
        
        sysctl -w kernel.randomize_va_space=2 &>/dev/null
        log_success "[${control_id}] Remediated: ASLR enabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.5.2"
    log_info "[${control_id}] Ensure ptrace_scope is restricted"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local ptrace_scope=$(sysctl -n kernel.yama.ptrace_scope 2>/dev/null)
        if [[ "${ptrace_scope}" == "1" ]]; then
            log_success "[${control_id}] PASS: ptrace_scope is restricted"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ptrace_scope is not restricted"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Restrict ptrace_scope?"; then
        backup_file "/etc/sysctl.conf"
        
        if grep -qE "^[[:space:]]*kernel.yama.ptrace_scope[[:space:]]*=" /etc/sysctl.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*kernel.yama.ptrace_scope[[:space:]]*=.*/kernel.yama.ptrace_scope = 1/' /etc/sysctl.conf
        else
            echo "kernel.yama.ptrace_scope = 1" >> /etc/sysctl.conf
        fi
        
        sysctl -w kernel.yama.ptrace_scope=1 &>/dev/null
        log_success "[${control_id}] Remediated: ptrace_scope restricted"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.5.3"
    log_info "[${control_id}] Ensure core dump backtraces are disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if grep -RqsE "^[[:space:]]*ProcessSizeMax[[:space:]]*=[[:space:]]*0" /etc/systemd/coredump.conf /etc/systemd/coredump.conf.d/ 2>/dev/null; then
            log_success "[${control_id}] PASS: Core dump backtraces disabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Core dump backtraces are not disabled"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Disable core dump backtraces?"; then
        mkdir -p /etc/systemd/coredump.conf.d/ 2>/dev/null
        backup_file "/etc/systemd/coredump.conf.d/99-cis.conf"
        
        if grep -qE "^[[:space:]]*ProcessSizeMax[[:space:]]*=" /etc/systemd/coredump.conf.d/99-cis.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*ProcessSizeMax[[:space:]]*=.*/ProcessSizeMax=0/' /etc/systemd/coredump.conf.d/99-cis.conf
        else
            grep -qE "^[[:space:]]*\[Coredump\]" /etc/systemd/coredump.conf.d/99-cis.conf 2>/dev/null || echo "[Coredump]" >> /etc/systemd/coredump.conf.d/99-cis.conf
            echo "ProcessSizeMax=0" >> /etc/systemd/coredump.conf.d/99-cis.conf
        fi
        
        systemctl daemon-reload 2>/dev/null
        log_success "[${control_id}] Remediated: Core dump backtraces disabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.5.4"
    log_info "[${control_id}] Ensure core dump storage is disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if grep -RqsE "^[[:space:]]*Storage[[:space:]]*=[[:space:]]*none" /etc/systemd/coredump.conf /etc/systemd/coredump.conf.d/ 2>/dev/null; then
            log_success "[${control_id}] PASS: Core dump storage disabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Core dump storage is not disabled"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Disable core dump storage?"; then
        mkdir -p /etc/systemd/coredump.conf.d/ 2>/dev/null
        backup_file "/etc/security/limits.conf"
        backup_file "/etc/sysctl.conf"
        backup_file "/etc/systemd/coredump.conf.d/99-cis.conf"
        
        grep -qE "^[[:space:]]*\*[[:space:]]+hard[[:space:]]+core[[:space:]]+0" /etc/security/limits.conf 2>/dev/null || echo "* hard core 0" >> /etc/security/limits.conf
        
        if grep -qE "^[[:space:]]*fs.suid_dumpable[[:space:]]*=" /etc/sysctl.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*fs.suid_dumpable[[:space:]]*=.*/fs.suid_dumpable = 0/' /etc/sysctl.conf
        else
            echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
        fi
        
        if grep -qE "^[[:space:]]*Storage[[:space:]]*=" /etc/systemd/coredump.conf.d/99-cis.conf 2>/dev/null; then
            sed -i 's/^[[:space:]]*Storage[[:space:]]*=.*/Storage=none/' /etc/systemd/coredump.conf.d/99-cis.conf
        else
            grep -qE "^[[:space:]]*\[Coredump\]" /etc/systemd/coredump.conf.d/99-cis.conf 2>/dev/null || echo "[Coredump]" >> /etc/systemd/coredump.conf.d/99-cis.conf
            echo "Storage=none" >> /etc/systemd/coredump.conf.d/99-cis.conf
        fi
        
        sysctl -w fs.suid_dumpable=0 &>/dev/null
        systemctl daemon-reload 2>/dev/null
        log_success "[${control_id}] Remediated: Core dump storage disabled"
        ((REMEDIATED_CHECKS++))
    fi
}

################################################################################
# SECTION 1.6: CRYPTO POLICY
################################################################################

audit_1_6_1() {
    local policy
    policy=$(update-crypto-policies --show 2>/dev/null || echo "")
    [[ -n "${policy}" ]] && [[ "${policy}" != "LEGACY" ]]
}

remediate_1_6_1() {
    if ! command -v update-crypto-policies &>/dev/null; then
        log_error "update-crypto-policies command is not available"
        return 1
    fi

    update-crypto-policies --set DEFAULT &>/dev/null
}

audit_1_6_2() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0
    ! grep -E '^[[:space:]]*[^#].*\b(Ciphers|MACs|KexAlgorithms|HostKeyAlgorithms|PubkeyAcceptedKeyTypes)\b' "${config}" >/dev/null 2>&1
}

audit_1_6_3() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0
    ! grep -E '^[[:space:]]*[^#].*\bsha1\b' "${config}" >/dev/null 2>&1
}

audit_1_6_4() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0
    ! grep -E '^[[:space:]]*[^#].*\b(hmac-md5|hmac-sha1|hmac-sha1-96|umac-64|umac-64@openssh\.com|hmac-md5-etm@openssh\.com|hmac-sha1-etm@openssh\.com)\b' "${config}" >/dev/null 2>&1
}

audit_1_6_5() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0
    ! grep -E '^[[:space:]]*[^#].*\bcbc\b' "${config}" >/dev/null 2>&1
}

audit_1_6_6() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0
    ! grep -E '^[[:space:]]*[^#].*chacha20-poly1305\b' "${config}" >/dev/null 2>&1
}

audit_1_6_7() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0
    ! grep -E '^[[:space:]]*[^#].*etm@openssh\.com\b' "${config}" >/dev/null 2>&1
}

remediate_1_6_sshd_crypto_overrides() {
    local config="/etc/ssh/sshd_config"
    [[ ! -f "${config}" ]] && return 0

    backup_file "${config}"
    sed -i '/^[[:space:]]*[^#].*\b\(Ciphers\|MACs\|KexAlgorithms\|HostKeyAlgorithms\|PubkeyAcceptedKeyTypes\)\b/d' "${config}"
    systemctl reload sshd 2>/dev/null || true
}

remediate_crypto_policy() {
    if ! should_run_section "1.6"; then
        log_info "Skipping Section 1.6: Crypto Policy (not selected)"
        return 0
    fi

    log_info "=== Section 1.6: Crypto Policy ==="

    local control_id="1.6.1"
    log_info "[${control_id}] Ensure system-wide crypto policy is not set to legacy"
    ((TOTAL_CHECKS++))

    if audit_1_6_1; then
        log_success "[${control_id}] PASS: System-wide crypto policy is not legacy"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: System-wide crypto policy is set to legacy"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Set crypto policy to DEFAULT?"; then
        if remediate_1_6_1 && audit_1_6_1; then
            log_success "[${control_id}] Remediated: Crypto policy set to DEFAULT"
            ((REMEDIATED_CHECKS++))
        else
            log_warning "[${control_id}] Remediation attempted; verify manually"
            ((FAILED_CHECKS++))
        fi
    fi

    for control_id in 1.6.2 1.6.3 1.6.4 1.6.5 1.6.6 1.6.7; do
        local description
        local audit_fn

        case "${control_id}" in
            1.6.2)
                description="Ensure sshd does not override system crypto policy"
                audit_fn=audit_1_6_2
                ;;
            1.6.3)
                description="Ensure sshd does not use SHA1 algorithms"
                audit_fn=audit_1_6_3
                ;;
            1.6.4)
                description="Ensure sshd does not allow MACs with less than 128 bits"
                audit_fn=audit_1_6_4
                ;;
            1.6.5)
                description="Ensure sshd does not use CBC ciphers"
                audit_fn=audit_1_6_5
                ;;
            1.6.6)
                description="Ensure sshd does not use chacha20-poly1305"
                audit_fn=audit_1_6_6
                ;;
            1.6.7)
                description="Ensure sshd does not use EtM ciphers"
                audit_fn=audit_1_6_7
                ;;
        esac

        log_info "[${control_id}] ${description}"
        ((TOTAL_CHECKS++))

        if "${audit_fn}"; then
            log_success "[${control_id}] PASS: ${description}"
            ((PASSED_CHECKS++))
            continue
        fi

        if [[ "${DRY_RUN}" == true ]]; then
            log_warning "[${control_id}] FAIL: ${description}"
            ((FAILED_CHECKS++))
            continue
        fi

        if confirm_action "[${control_id}] Remediate: ${description}?"; then
            if remediate_1_6_sshd_crypto_overrides && "${audit_fn}"; then
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
    done
}

################################################################################
# SECTION 1.3: SELINUX
################################################################################

remediate_selinux() {
    if ! should_run_section "1.3"; then
        log_info "Skipping Section 1.3: Mandatory Access Controls (SELinux) (not selected)"
        return 0
    fi
    
    log_info "=== Section 1.3: Mandatory Access Controls (SELinux) ==="
    
    local control_id="1.3.1.1"
    log_info "[${control_id}] Ensure SELinux is installed"
    ((TOTAL_CHECKS++))
    
    if rpm -q libselinux &>/dev/null; then
        log_success "[${control_id}] PASS: SELinux is installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: SELinux is not installed"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Install SELinux?"; then
        dnf install -y libselinux &>/dev/null && log_success "[${control_id}] Remediated: SELinux installed" && ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.3.1.2"
    log_info "[${control_id}] Ensure SELinux is not disabled in bootloader"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if grep -E "selinux=0|enforcing=0" /etc/default/grub &>/dev/null; then
            log_warning "[${control_id}] FAIL: SELinux disabled in bootloader"
            ((FAILED_CHECKS++))
        else
            log_success "[${control_id}] PASS: SELinux not disabled"
            ((PASSED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Ensure SELinux enabled in bootloader?"; then
        backup_file "/etc/default/grub"
        sed -i 's/selinux=0//g; s/enforcing=0//g' /etc/default/grub
        grub2-mkconfig -o /boot/grub2/grub.cfg &>/dev/null
        log_success "[${control_id}] Remediated: SELinux enabled in bootloader"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.3.1.3"
    log_info "[${control_id}] Ensure SELinux policy is configured"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if grep -q "^SELINUXTYPE=targeted" /etc/selinux/config 2>/dev/null; then
            log_success "[${control_id}] PASS: SELinux policy configured"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: SELinux policy not configured"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Configure SELinux policy to targeted?"; then
        backup_file "/etc/selinux/config"
        if grep -qE "^[[:space:]]*SELINUXTYPE=" /etc/selinux/config 2>/dev/null; then
            sed -i 's/^[[:space:]]*SELINUXTYPE=.*/SELINUXTYPE=targeted/' /etc/selinux/config
        else
            echo "SELINUXTYPE=targeted" >> /etc/selinux/config
        fi
        log_success "[${control_id}] Remediated: SELinux policy configured"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.3.1.4"
    log_info "[${control_id}] Ensure SELinux mode is not disabled"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if ! grep -qE "^[[:space:]]*SELINUX[[:space:]]*=[[:space:]]*disabled" /etc/selinux/config 2>/dev/null; then
            log_success "[${control_id}] PASS: SELinux mode is not disabled"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: SELinux mode is disabled"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Ensure SELinux mode is not disabled?"; then
        backup_file "/etc/selinux/config"
        if grep -qE "^[[:space:]]*SELINUX[[:space:]]*=" /etc/selinux/config 2>/dev/null; then
            sed -i 's/^[[:space:]]*SELINUX[[:space:]]*=.*/SELINUX=enforcing/' /etc/selinux/config
        else
            echo "SELINUX=enforcing" >> /etc/selinux/config
        fi
        log_success "[${control_id}] Remediated: SELinux mode is not disabled"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.3.1.5"
    log_info "[${control_id}] Ensure SELinux mode is enforcing"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        if getenforce 2>/dev/null | grep -q "Enforcing" && \
           grep -qE "^[[:space:]]*SELINUX[[:space:]]*=[[:space:]]*enforcing" /etc/selinux/config 2>/dev/null; then
            log_success "[${control_id}] PASS: SELinux enforcing"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: SELinux not enforcing"
            ((FAILED_CHECKS++))
        fi
    elif confirm_action "[${control_id}] Set SELinux to enforcing mode?"; then
        backup_file "/etc/selinux/config"
        if grep -qE "^[[:space:]]*SELINUX[[:space:]]*=" /etc/selinux/config 2>/dev/null; then
            sed -i 's/^[[:space:]]*SELINUX[[:space:]]*=.*/SELINUX=enforcing/' /etc/selinux/config
        else
            echo "SELINUX=enforcing" >> /etc/selinux/config
        fi
        setenforce 1 2>/dev/null || log_warning "SELinux mode will be enforcing after reboot"
        log_success "[${control_id}] Remediated: SELinux set to enforcing"
        ((REMEDIATED_CHECKS++))
    fi
    
    control_id="1.3.1.6"
    log_info "[${control_id}] Ensure no unconfined services exist"
    ((TOTAL_CHECKS++))
    
    local unconfined_services
    unconfined_services=$(ps -eZ 2>/dev/null | awk '$1 ~ /unconfined_service_t/ {print}' || true)
    if [[ -z "${unconfined_services}" ]]; then
        log_success "[${control_id}] PASS: No unconfined services found"
        ((PASSED_CHECKS++))
    else
        local service_count=$(echo "${unconfined_services}" | grep -c "unconfined_service_t" || echo "0")
        log_check_manual "${control_id}" \
            "Unconfined services require review" \
            "Found ${service_count} unconfined service(s):
${unconfined_services}" \
            "Review and confine all unconfined services" \
            "1. List unconfined services: ps -eZ | grep unconfined_service_t
2. For each service, determine if it should be confined
3. Create or modify SELinux policy to confine the service
4. Test the confined policy in permissive mode first
5. Switch to enforcing mode after validation" \
            "Unconfined services run without SELinux restrictions and pose a security risk"
        ((MANUAL_CHECKS++))
    fi
    
    control_id="1.3.1.7"
    log_info "[${control_id}] Ensure mcstrans is not installed"
    ((TOTAL_CHECKS++))
    
    if ! rpm -q mcstrans &>/dev/null; then
        log_success "[${control_id}] PASS: mcstrans is not installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: mcstrans is installed"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Remove mcstrans?"; then
        dnf remove -y mcstrans &>/dev/null && \
            { log_success "[${control_id}] Remediated: mcstrans removed"; ((REMEDIATED_CHECKS++)); } || \
            { log_error "[${control_id}] Failed to remove mcstrans"; ((FAILED_CHECKS++)); }
    fi
    
    control_id="1.3.1.8"
    log_info "[${control_id}] Ensure SETroubleshoot is not installed"
    ((TOTAL_CHECKS++))
    
    if ! rpm -q setroubleshoot &>/dev/null; then
        log_success "[${control_id}] PASS: SETroubleshoot is not installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: SETroubleshoot is installed"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Remove SETroubleshoot?"; then
        dnf remove -y setroubleshoot &>/dev/null && \
            { log_success "[${control_id}] Remediated: SETroubleshoot removed"; ((REMEDIATED_CHECKS++)); } || \
            { log_error "[${control_id}] Failed to remove SETroubleshoot"; ((FAILED_CHECKS++)); }
    fi
}

################################################################################
# SECTION 1.7: WARNING BANNERS
################################################################################

remediate_warning_banners() {
    if ! should_run_section "1.7"; then
        log_info "Skipping Section 1.7: Warning Banners (not selected)"
        return 0
    fi
    
    log_info "=== Section 1.7: Warning Banners ==="
    
    # Use custom banner if provided, otherwise fall back to generic banner
    local banner_text
    local generic_banner_file="${SCRIPT_DIR}/banner-samples/generic-banner.txt"

    if [[ -n "${CUSTOM_BANNER_FILE}" ]]; then
        if [[ -f "${CUSTOM_BANNER_FILE}" ]]; then
            banner_text=$(<"${CUSTOM_BANNER_FILE}")
            log_info "Using custom banner from: ${CUSTOM_BANNER_FILE}"
        else
            log_error "Custom banner file not found: ${CUSTOM_BANNER_FILE}"
            if [[ -f "${generic_banner_file}" ]]; then
                banner_text=$(<"${generic_banner_file}")
                log_warning "Falling back to generic banner: ${generic_banner_file}"
            else
                log_warning "Falling back to embedded default banner"
                banner_text='###############################################################################
#                                                                             #
#                      AUTHORIZED ACCESS ONLY                                 #
#                                                                             #
#  This system is for authorized use only. Unauthorized access or use of     #
#  this system is strictly prohibited and may be subject to criminal and     #
#  civil penalties. All activities on this system are monitored and logged.  #
#  By accessing this system, you consent to such monitoring and logging.     #
#                                                                             #
#  If you are not an authorized user, disconnect immediately.                #
#                                                                             #
###############################################################################'
            fi
        fi
    else
        if [[ -f "${generic_banner_file}" ]]; then
            banner_text=$(<"${generic_banner_file}")
            log_info "Using generic banner from: ${generic_banner_file}"
        else
            banner_text='###############################################################################
#                                                                             #
#                      AUTHORIZED ACCESS ONLY                                 #
#                                                                             #
#  This system is for authorized use only. Unauthorized access or use of     #
#  this system is strictly prohibited and may be subject to criminal and     #
#  civil penalties. All activities on this system are monitored and logged.  #
#  By accessing this system, you consent to such monitoring and logging.     #
#                                                                             #
#  If you are not an authorized user, disconnect immediately.                #
#                                                                             #
###############################################################################'
        fi
    fi
    
    local files=("/etc/motd" "/etc/issue" "/etc/issue.net")
    local control_ids=("1.7.1" "1.7.2" "1.7.3")
    local names=("MOTD" "local login banner" "remote login banner")
    
    for i in {0..2}; do
        local file="${files[$i]}"
        local control_id="${control_ids[$i]}"
        local name="${names[$i]}"
        
        log_info "[${control_id}] Ensure ${name} is configured"
        ((TOTAL_CHECKS++))
        
        if [[ "${DRY_RUN}" == true ]]; then
            if [[ ! -f "${file}" || ! -s "${file}" ]]; then
                log_warning "[${control_id}] FAIL: ${name} not configured"
                ((FAILED_CHECKS++))
                continue
            fi
            
            # CIS requirement: Check for forbidden escape sequences and OS identification
            local os_name=$(grep '^ID=' /etc/os-release 2>/dev/null | cut -d= -f2 | sed -e 's/"//g')
            if grep -E -i "(\\\\v|\\\\r|\\\\m|\\\\s|${os_name})" "${file}" &>/dev/null; then
                log_warning "[${control_id}] FAIL: ${name} contains forbidden escape sequences or OS identification"
                ((FAILED_CHECKS++))
            else
                log_success "[${control_id}] PASS: ${name} configured"
                ((PASSED_CHECKS++))
            fi
            continue
        fi
        
        if confirm_action "[${control_id}] Configure ${name}?"; then
            backup_file "${file}"
            echo "${banner_text}" > "${file}"
            chmod 644 "${file}"
            chown root:root "${file}"
            log_success "[${control_id}] Remediated: ${name} configured"
            ((REMEDIATED_CHECKS++))
        fi
    done
    
    # Set permissions
    for i in {0..2}; do
        local file="${files[$i]}"
        local control_id="1.7.$((i+4))"
        
        log_info "[${control_id}] Ensure permissions on ${file} are configured"
        ((TOTAL_CHECKS++))
        
        if [[ ! -f "${file}" ]]; then
            continue
        fi
        
        if [[ "${DRY_RUN}" == true ]]; then
            local perms=$(stat -c %a "${file}" 2>/dev/null)
            if [[ "${perms}" == "644" ]]; then
                log_success "[${control_id}] PASS: Permissions correct"
                ((PASSED_CHECKS++))
            else
                log_warning "[${control_id}] FAIL: Permissions are ${perms}"
                ((FAILED_CHECKS++))
            fi
            continue
        fi
        
        if confirm_action "[${control_id}] Set ${file} permissions?"; then
            chmod 644 "${file}"
            chown root:root "${file}"
            log_success "[${control_id}] Remediated: Permissions set"
            ((REMEDIATED_CHECKS++))
        fi
    done
}

gdm_installed() {
    rpm -q gdm &>/dev/null
}

remediate_gnome_display_manager() {
    if ! should_run_section "1.8"; then
        log_info "Skipping Section 1.8: GNOME Display Manager (not selected)"
        return 0
    fi

    log_info "=== Section 1.8: GNOME Display Manager ==="

    local control_id="1.8.1"
    log_info "[${control_id}] Ensure GNOME Display Manager is removed"
    ((TOTAL_CHECKS++))

    if ! gdm_installed; then
        log_success "[${control_id}] PASS: GDM is not installed"
        ((PASSED_CHECKS++))
    elif [[ "${DRY_RUN}" == true ]]; then
        log_warning "[${control_id}] FAIL: GDM is installed"
        ((FAILED_CHECKS++))
    elif confirm_action "[${control_id}] Remove GDM?"; then
        if dnf remove -y gdm &>/dev/null; then
            log_success "[${control_id}] Remediated: GDM removed"
            ((REMEDIATED_CHECKS++))
        else
            log_error "[${control_id}] Failed to remove GDM"
            ((FAILED_CHECKS++))
        fi
    fi

    local control_ids=("1.8.2" "1.8.3" "1.8.4" "1.8.5" "1.8.6" "1.8.7" "1.8.8" "1.8.9" "1.8.10")
    local descriptions=(
        "Ensure GDM login banner is configured"
        "Ensure GDM disable-user-list option is enabled"
        "Ensure GDM screen locks when the user is idle"
        "Ensure GDM screen locks cannot be overridden"
        "Ensure GDM automatic mounting of removable media is disabled"
        "Ensure GDM disabling automatic mounting of removable media is not overridden"
        "Ensure GDM autorun-never is enabled"
        "Ensure GDM autorun-never is not overridden"
        "Ensure XDMCP is not enabled"
    )

    for i in "${!control_ids[@]}"; do
        control_id="${control_ids[$i]}"
        description="${descriptions[$i]}"

        log_info "[${control_id}] ${description}"
        ((TOTAL_CHECKS++))

        if ! gdm_installed; then
            log_success "[${control_id}] PASS: GDM is not installed"
            ((PASSED_CHECKS++))
            continue
        fi

        local gdm_config_status="GDM is installed. Configuration file: ${config_file}"
        if [[ -f "${config_file}" ]]; then
            gdm_config_status="${gdm_config_status}
Current setting: $(grep -E "^${setting}" "${config_file}" 2>/dev/null || echo "Not configured")"
        else
            gdm_config_status="${gdm_config_status} (file does not exist)"
        fi
        
        log_check_manual "${control_id}" \
            "${description} requires review when GDM is present" \
            "${gdm_config_status}" \
            "Configure ${setting} in ${config_file}" \
            "1. Edit or create ${config_file}
2. Add or modify the setting: ${setting}=${value}
3. Restart GDM: systemctl restart gdm
4. Verify the setting is applied" \
            "GDM configuration affects the graphical login security posture"
        ((MANUAL_CHECKS++))
    done
}

run_section_1() {
    remediate_filesystem_modules
    remediate_partition_options
    remediate_software_updates
    remediate_secure_boot
    remediate_process_hardening
    remediate_crypto_policy
    remediate_selinux
    remediate_warning_banners
    remediate_gnome_display_manager
}
