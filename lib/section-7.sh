#!/bin/bash

################################################################################
# RHEL 9 CIS Benchmark - Section 7: System Maintenance
# Version: 2.0.0
# Description: Implementation of CIS Section 7 controls
################################################################################

################################################################################
# SECTION 7.1: SYSTEM FILE PERMISSIONS
################################################################################

check_file_permissions() {
    local file="$1"
    local expected_perms="$2"
    local control_id="$3"
    
    log_info "[${control_id}] Ensure permissions on ${file} are configured"
    ((TOTAL_CHECKS++))
    
    if [[ ! -e "${file}" ]]; then
        log_warning "[${control_id}] SKIP: ${file} does not exist"
        return 0
    fi
    
    local current_perms=$(stat -c %a "${file}" 2>/dev/null)
    
    if [[ "${DRY_RUN}" == true ]]; then
        if [[ "${current_perms}" == "${expected_perms}" ]]; then
            log_success "[${control_id}] PASS: ${file} permissions are ${current_perms}"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${file} permissions are ${current_perms} (expected ${expected_perms})"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi
    
    if confirm_action "[${control_id}] Set ${file} permissions to ${expected_perms}?"; then
        chmod "${expected_perms}" "${file}" 2>/dev/null
        chown root:root "${file}" 2>/dev/null
        log_success "[${control_id}] Remediated: ${file} permissions set to ${expected_perms}"
        ((REMEDIATED_CHECKS++))
    fi
}

remediate_system_file_permissions() {
    if ! should_run_section "7.1"; then
        log_info "Skipping Section 7.1: System File Permissions (not selected)"
        return 0
    fi
    
    log_info "=== Section 7.1: System File Permissions ==="
    
    # 7.1.1 - Ensure permissions on /etc/passwd are configured
    check_file_permissions "/etc/passwd" "644" "7.1.1"
    
    # 7.1.2 - Ensure permissions on /etc/passwd- are configured
    check_file_permissions "/etc/passwd-" "644" "7.1.2"
    
    # 7.1.3 - Ensure permissions on /etc/group are configured
    check_file_permissions "/etc/group" "644" "7.1.3"
    
    # 7.1.4 - Ensure permissions on /etc/group- are configured
    check_file_permissions "/etc/group-" "644" "7.1.4"
    
    # 7.1.5 - Ensure permissions on /etc/shadow are configured
    check_file_permissions "/etc/shadow" "0" "7.1.5"
    
    # 7.1.6 - Ensure permissions on /etc/shadow- are configured
    check_file_permissions "/etc/shadow-" "0" "7.1.6"
    
    # 7.1.7 - Ensure permissions on /etc/gshadow are configured
    check_file_permissions "/etc/gshadow" "0" "7.1.7"
    
    # 7.1.8 - Ensure permissions on /etc/gshadow- are configured
    check_file_permissions "/etc/gshadow-" "0" "7.1.8"
    
    # 7.1.9 - Ensure permissions on /etc/shells are configured
    check_file_permissions "/etc/shells" "644" "7.1.9"
    
    # 7.1.10 - Ensure permissions on /etc/security/opasswd are configured
    check_file_permissions "/etc/security/opasswd" "600" "7.1.10"
    
    # 7.1.11 - Ensure world writable files are secured
    local control_id="7.1.11"
    log_info "[${control_id}] Ensure world writable files are secured"
    ((TOTAL_CHECKS++))
    
    local world_writable=$(find / -xdev -type f -perm -0002 2>/dev/null | head -20)
    local ww_count=$(find / -xdev -type f -perm -0002 2>/dev/null | wc -l)
    log_check_manual "${control_id}" \
        "Review and secure world-writable files" \
        "Found ${ww_count} world-writable file(s) (showing first 20):
${world_writable:-No world-writable files found}" \
        "Review and remove world-writable permissions from files" \
        "1. Find all world-writable files: find / -xdev -type f -perm -0002
2. Review each file to determine if world-write is necessary
3. Remove world-write permission: chmod o-w <file>
4. Consider using sticky bit for shared directories: chmod +t <directory>
5. Document any exceptions in security policy" \
        "World-writable files can be modified by any user, posing a security risk"
    ((MANUAL_CHECKS++))
    
    # 7.1.12 - Ensure no unowned files or directories exist
    control_id="7.1.12"
    log_info "[${control_id}] Ensure no unowned files or directories exist"
    ((TOTAL_CHECKS++))
    
    local unowned_files=$(find / -xdev -nouser 2>/dev/null | head -20)
    local unowned_count=$(find / -xdev -nouser 2>/dev/null | wc -l)
    
    if [[ "${DRY_RUN}" == true ]]; then
        if [[ ${unowned_count} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No unowned files found"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${unowned_count} unowned files found"
            ((FAILED_CHECKS++))
        fi
    else
        log_check_manual "${control_id}" \
            "Review and assign ownership to unowned files" \
            "Found ${unowned_count} unowned file(s) (showing first 20):
${unowned_files:-No unowned files found}" \
            "Assign appropriate ownership to all unowned files" \
            "1. Find all unowned files: find / -xdev -nouser
2. Investigate why files are unowned (deleted user, migration, etc.)
3. Assign ownership: chown <user>:<group> <file>
4. Or delete if no longer needed: rm <file>
5. Verify: find / -xdev -nouser" \
            "Unowned files may indicate deleted user accounts or security issues"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.1.13 - Ensure no ungrouped files or directories exist
    control_id="7.1.13"
    log_info "[${control_id}] Ensure no ungrouped files or directories exist"
    ((TOTAL_CHECKS++))
    
    local ungrouped_files=$(find / -xdev -nogroup 2>/dev/null | head -20)
    local ungrouped_count=$(find / -xdev -nogroup 2>/dev/null | wc -l)
    
    if [[ "${DRY_RUN}" == true ]]; then
        if [[ ${ungrouped_count} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No ungrouped files found"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${ungrouped_count} ungrouped files found"
            ((FAILED_CHECKS++))
        fi
    else
        log_check_manual "${control_id}" \
            "Review and assign group to ungrouped files" \
            "Found ${ungrouped_count} ungrouped file(s) (showing first 20):
${ungrouped_files:-No ungrouped files found}" \
            "Assign appropriate group ownership to all ungrouped files" \
            "1. Find all ungrouped files: find / -xdev -nogroup
2. Investigate why files are ungrouped (deleted group, migration, etc.)
3. Assign group: chgrp <group> <file>
4. Or delete if no longer needed: rm <file>
5. Verify: find / -xdev -nogroup" \
            "Ungrouped files may indicate deleted groups or security issues"
        ((MANUAL_CHECKS++))
    fi
}

################################################################################
# SECTION 7.2: USER AND GROUP SETTINGS
################################################################################

remediate_user_group_settings() {
    if ! should_run_section "7.2"; then
        log_info "Skipping Section 7.2: User and Group Settings (not selected)"
        return 0
    fi
    
    log_info "=== Section 7.2: User and Group Settings ==="
    
    # 7.2.1 - Ensure accounts in /etc/passwd use shadowed passwords
    local control_id="7.2.1"
    log_info "[${control_id}] Ensure accounts in /etc/passwd use shadowed passwords"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local non_shadowed=$(awk -F: '($2 != "x") {print $1}' /etc/passwd 2>/dev/null | wc -l)
        if [[ ${non_shadowed} -eq 0 ]]; then
            log_success "[${control_id}] PASS: All accounts use shadowed passwords"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${non_shadowed} accounts not using shadowed passwords"
            ((FAILED_CHECKS++))
        fi
    else
        local non_shadowed_accounts=$(awk -F: '($2 != "x") {print $1}' /etc/passwd 2>/dev/null | head -20)
        local non_shadowed_count=$(awk -F: '($2 != "x") {print $1}' /etc/passwd 2>/dev/null | wc -l)
        log_check_manual "${control_id}" \
            "Ensure all accounts use shadowed passwords" \
            "Found ${non_shadowed_count} account(s) not using shadowed passwords:
${non_shadowed_accounts:-All accounts use shadowed passwords}" \
            "Convert all accounts to use shadowed passwords" \
            "1. Check for non-shadowed accounts: awk -F: '(\$2 != \"x\") {print \$1}' /etc/passwd
2. Run pwconv to convert to shadow passwords: pwconv
3. Verify all accounts now use 'x': awk -F: '(\$2 != \"x\") {print \$1}' /etc/passwd
4. Ensure /etc/shadow has proper permissions: chmod 0000 /etc/shadow" \
            "Shadow passwords store encrypted passwords separately from /etc/passwd for better security"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.2 - Ensure /etc/shadow password fields are not empty
    control_id="7.2.2"
    log_info "[${control_id}] Ensure /etc/shadow password fields are not empty"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local empty_pass=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l)
        if [[ ${empty_pass} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No accounts with empty passwords"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${empty_pass} accounts with empty passwords"
            ((FAILED_CHECKS++))
        fi
    else
        local empty_pass_accounts=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null)
        local empty_pass_count=$(awk -F: '($2 == "") {print $1}' /etc/shadow 2>/dev/null | wc -l)
        log_check_manual "${control_id}" \
            "Lock or delete accounts with empty passwords" \
            "Found ${empty_pass_count} account(s) with empty passwords:
${empty_pass_accounts:-No accounts with empty passwords}" \
            "Lock or delete all accounts with empty passwords" \
            "1. Find accounts with empty passwords: awk -F: '(\$2 == \"\") {print \$1}' /etc/shadow
2. Lock account: passwd -l <username>
3. Or delete account: userdel <username>
4. Verify: awk -F: '(\$2 == \"\") {print \$1}' /etc/shadow" \
            "Accounts with empty passwords can be accessed without authentication"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.3 - Ensure all groups in /etc/passwd exist in /etc/group
    control_id="7.2.3"
    log_info "[${control_id}] Ensure all groups in /etc/passwd exist in /etc/group"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local missing_groups=0
        for gid in $(awk -F: '{print $4}' /etc/passwd | sort -u); do
            if ! grep -q "^[^:]*:[^:]*:${gid}:" /etc/group; then
                ((missing_groups++))
            fi
        done
        
        if [[ ${missing_groups} -eq 0 ]]; then
            log_success "[${control_id}] PASS: All groups exist"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${missing_groups} groups missing from /etc/group"
            ((FAILED_CHECKS++))
        fi
    else
        local missing_gids=""
        for gid in $(awk -F: '{print $4}' /etc/passwd | sort -u); do
            if ! grep -q "^[^:]*:[^:]*:${gid}:" /etc/group; then
                missing_gids="${missing_gids}GID ${gid}\n"
            fi
        done
        log_check_manual "${control_id}" \
            "Create missing groups in /etc/group" \
            "Missing groups:
${missing_gids:-All groups exist in /etc/group}" \
            "Create all missing groups referenced in /etc/passwd" \
            "1. Find missing groups: for gid in \$(awk -F: '{print \$4}' /etc/passwd | sort -u); do grep -q \"^[^:]*:[^:]*:\${gid}:\" /etc/group || echo \"Missing GID: \${gid}\"; done
2. Create missing group: groupadd -g <gid> <groupname>
3. Verify: grep \":<gid>:\" /etc/group" \
            "All GIDs in /etc/passwd must have corresponding entries in /etc/group"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.4 - Ensure no duplicate UIDs exist
    control_id="7.2.4"
    log_info "[${control_id}] Ensure no duplicate UIDs exist"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local dup_uids=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d | wc -l)
        if [[ ${dup_uids} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No duplicate UIDs"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${dup_uids} duplicate UIDs found"
            ((FAILED_CHECKS++))
        fi
    else
        local dup_uids=$(awk -F: '{print $3}' /etc/passwd | sort | uniq -d)
        local dup_uid_users=$(for uid in ${dup_uids}; do echo "UID ${uid}:"; awk -F: -v uid="${uid}" '$3 == uid {print "  " $1}' /etc/passwd; done)
        log_check_manual "${control_id}" \
            "Resolve duplicate UIDs" \
            "Duplicate UIDs found:
${dup_uid_users:-No duplicate UIDs}" \
            "Assign unique UIDs to all users" \
            "1. Find duplicate UIDs: awk -F: '{print \$3}' /etc/passwd | sort | uniq -d
2. For each duplicate, list users: awk -F: '\$3 == <uid> {print \$1}' /etc/passwd
3. Change UID: usermod -u <new_uid> <username>
4. Update file ownership: find / -user <old_uid> -exec chown <new_uid> {} \\;
5. Verify: awk -F: '{print \$3}' /etc/passwd | sort | uniq -d" \
            "Duplicate UIDs can cause permission and ownership conflicts"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.5 - Ensure no duplicate GIDs exist
    control_id="7.2.5"
    log_info "[${control_id}] Ensure no duplicate GIDs exist"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local dup_gids=$(awk -F: '{print $3}' /etc/group | sort | uniq -d | wc -l)
        if [[ ${dup_gids} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No duplicate GIDs"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${dup_gids} duplicate GIDs found"
            ((FAILED_CHECKS++))
        fi
    else
        local dup_gids=$(awk -F: '{print $3}' /etc/group | sort | uniq -d)
        local dup_gid_groups=$(for gid in ${dup_gids}; do echo "GID ${gid}:"; awk -F: -v gid="${gid}" '$3 == gid {print "  " $1}' /etc/group; done)
        log_check_manual "${control_id}" \
            "Resolve duplicate GIDs" \
            "Duplicate GIDs found:
${dup_gid_groups:-No duplicate GIDs}" \
            "Assign unique GIDs to all groups" \
            "1. Find duplicate GIDs: awk -F: '{print \$3}' /etc/group | sort | uniq -d
2. For each duplicate, list groups: awk -F: '\$3 == <gid> {print \$1}' /etc/group
3. Change GID: groupmod -g <new_gid> <groupname>
4. Update file ownership: find / -group <old_gid> -exec chgrp <new_gid> {} \\;
5. Verify: awk -F: '{print \$3}' /etc/group | sort | uniq -d" \
            "Duplicate GIDs can cause permission and ownership conflicts"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.6 - Ensure no duplicate user names exist
    control_id="7.2.6"
    log_info "[${control_id}] Ensure no duplicate user names exist"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local dup_users=$(awk -F: '{print $1}' /etc/passwd | sort | uniq -d | wc -l)
        if [[ ${dup_users} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No duplicate user names"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${dup_users} duplicate user names found"
            ((FAILED_CHECKS++))
        fi
    else
        local dup_users=$(awk -F: '{print $1}' /etc/passwd | sort | uniq -d)
        log_check_manual "${control_id}" \
            "Resolve duplicate user names" \
            "Duplicate user names found:
${dup_users:-No duplicate user names}" \
            "Ensure all user names are unique" \
            "1. Find duplicate names: awk -F: '{print \$1}' /etc/passwd | sort | uniq -d
2. Review each duplicate user
3. Rename or delete duplicate: usermod -l <new_name> <old_name> or userdel <username>
4. Verify: awk -F: '{print \$1}' /etc/passwd | sort | uniq -d" \
            "Duplicate user names can cause authentication and authorization issues"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.7 - Ensure no duplicate group names exist
    control_id="7.2.7"
    log_info "[${control_id}] Ensure no duplicate group names exist"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local dup_groups=$(awk -F: '{print $1}' /etc/group | sort | uniq -d | wc -l)
        if [[ ${dup_groups} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No duplicate group names"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${dup_groups} duplicate group names found"
            ((FAILED_CHECKS++))
        fi
    else
        local dup_groups=$(awk -F: '{print $1}' /etc/group | sort | uniq -d)
        log_check_manual "${control_id}" \
            "Resolve duplicate group names" \
            "Duplicate group names found:
${dup_groups:-No duplicate group names}" \
            "Ensure all group names are unique" \
            "1. Find duplicate names: awk -F: '{print \$1}' /etc/group | sort | uniq -d
2. Review each duplicate group
3. Rename or delete duplicate: groupmod -n <new_name> <old_name> or groupdel <groupname>
4. Verify: awk -F: '{print \$1}' /etc/group | sort | uniq -d" \
            "Duplicate group names can cause permission and authorization issues"
        ((MANUAL_CHECKS++))
    fi
    
    # 7.2.8 - Ensure root PATH Integrity
    control_id="7.2.8"
    log_info "[${control_id}] Ensure root PATH Integrity"
    ((TOTAL_CHECKS++))
    
    local root_path=$(echo $PATH)
    local path_issues=""
    if echo "${root_path}" | grep -q "::"; then
        path_issues="${path_issues}- Empty directory in PATH (::)\n"
    fi
    if echo "${root_path}" | grep -q ":$"; then
        path_issues="${path_issues}- Trailing colon in PATH\n"
    fi
    if echo "${root_path}" | grep -qE "(^|:)\.($|:)"; then
        path_issues="${path_issues}- Current directory (.) in PATH\n"
    fi
    
    log_check_manual "${control_id}" \
        "Verify root PATH does not include '.' or writable directories" \
        "Current root PATH:
${root_path}

Potential issues:
${path_issues:-No obvious issues detected (manual verification still required)}" \
        "Ensure root PATH does not contain '.' or world-writable directories" \
        "1. Check root PATH: echo \$PATH
2. Remove '.' from PATH if present
3. Check for world-writable directories: for dir in \$(echo \$PATH | tr ':' ' '); do ls -ld \$dir; done
4. Remove world-writable permissions: chmod o-w <directory>
5. Update PATH in /root/.bash_profile or /root/.bashrc" \
        "Insecure PATH can allow attackers to execute malicious commands as root"
    ((MANUAL_CHECKS++))
    
    # 7.2.9 - Ensure root is the only UID 0 account
    control_id="7.2.9"
    log_info "[${control_id}] Ensure root is the only UID 0 account"
    ((TOTAL_CHECKS++))
    
    if [[ "${DRY_RUN}" == true ]]; then
        local uid0_count=$(awk -F: '($3 == 0) {print $1}' /etc/passwd | wc -l)
        if [[ ${uid0_count} -eq 1 ]]; then
            log_success "[${control_id}] PASS: Only root has UID 0"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${uid0_count} accounts with UID 0"
            ((FAILED_CHECKS++))
        fi
    else
        local uid0_accounts=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)
        log_check_manual "${control_id}" \
            "Remove or change UID for non-root accounts with UID 0" \
            "Accounts with UID 0:
${uid0_accounts}" \
            "Ensure only root account has UID 0" \
            "1. Find UID 0 accounts: awk -F: '(\$3 == 0) {print \$1}' /etc/passwd
2. For non-root accounts with UID 0:
   - Change UID: usermod -u <new_uid> <username>
   - Or delete account: userdel <username>
3. Update file ownership: find / -user 0 -not -user root -exec chown <new_uid> {} \\;
4. Verify: awk -F: '(\$3 == 0) {print \$1}' /etc/passwd" \
            "Only the root account should have UID 0 (superuser privileges)"
        ((MANUAL_CHECKS++))
    fi
}

################################################################################
# SECTION 7 MAIN RUNNER
################################################################################

run_section_7() {
    remediate_system_file_permissions
    remediate_user_group_settings
}

# Made with Bob
