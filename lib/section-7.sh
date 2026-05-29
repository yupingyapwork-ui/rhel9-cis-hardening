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
    
    # 7.1.11 - Ensure world writable files and directories are secured
    local control_id="7.1.11"
    log_info "[${control_id}] Ensure world writable files and directories are secured"
    ((TOTAL_CHECKS++))

    local world_writable=$(find / -xdev \( -type f -o -type d \) -perm -0002 2>/dev/null | head -20)
    local ww_count=$(find / -xdev \( -type f -o -type d \) -perm -0002 2>/dev/null | wc -l)

    if [[ "${DRY_RUN}" == true ]]; then
        if [[ ${ww_count} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No world writable files or directories found"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${ww_count} world writable file(s) or directory(ies) found"
            ((FAILED_CHECKS++))
        fi
    else
        if [[ ${ww_count} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No world writable files or directories found"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${ww_count} world writable file(s) or directory(ies) found"
            log_warning "[${control_id}] REVIEW: ${world_writable:-No world writable files or directories found}"
            ((FAILED_CHECKS++))
        fi
    fi

    # 7.1.12 - Ensure no files or directories without an owner and a group exist
    control_id="7.1.12"
    log_info "[${control_id}] Ensure no files or directories without an owner and a group exist"
    ((TOTAL_CHECKS++))

    local unowned_files=$(find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | head -20)
    local unowned_count=$(find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | wc -l)

    if [[ "${DRY_RUN}" == true ]]; then
        if [[ ${unowned_count} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No files or directories without an owner or group found"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${unowned_count} files or directories without an owner or group found"
            ((FAILED_CHECKS++))
        fi
    else
        if [[ ${unowned_count} -eq 0 ]]; then
            log_success "[${control_id}] PASS: No files or directories without an owner or group found"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: ${unowned_count} files or directories without an owner or group found"
            log_warning "[${control_id}] REVIEW: ${unowned_files:-No files or directories without an owner or group found}"
            ((FAILED_CHECKS++))
        fi
    fi

    # 7.1.13 - Ensure SUID and SGID files are reviewed
    control_id="7.1.13"
    log_info "[${control_id}] Ensure SUID and SGID files are reviewed"
    ((TOTAL_CHECKS++))

    local suid_sgid_files=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | head -20)
    local suid_sgid_count=$(find / -xdev -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)

    log_check_manual "${control_id}" \
        "Review SUID and SGID files" \
        "Found ${suid_sgid_count} SUID/SGID file(s) (showing first 20):
${suid_sgid_files:-No SUID or SGID files found}" \
        "Review each SUID/SGID file and confirm it is required" \
        "1. Use find / -xdev -type f \( -perm -4000 -o -perm -2000 \) to list SUID/SGID files
2. Investigate whether each file requires elevated privileges
3. Remove setuid/setgid bit from unnecessary files: chmod u-s <file> or chmod g-s <file>
4. Document approved exceptions in security policy" \
        "SUID/SGID files should be reviewed to ensure they are required and secure"
    ((MANUAL_CHECKS++))
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
    
    # 7.2.8 - Ensure local interactive user home directories are configured
    control_id="7.2.8"
    log_info "[${control_id}] Ensure local interactive user home directories are configured"
    ((TOTAL_CHECKS++))

    local valid_shells
    valid_shells="^($(awk -F/ '$NF != "nologin" {print}' /etc/shells | sed -rn '/^\//{s,/,\\/,g;p}' | paste -s -d '|' - ))$"
    local home_issues=""

    while IFS=: read -r user home; do
        if [[ -z "$user" || -z "$home" ]]; then
            continue
        fi

        if [[ ! -d "$home" ]]; then
            home_issues+="User '$user' home directory '$home' does not exist\n"
            continue
        fi

        local owner mode
        owner=$(stat -c '%U' "$home" 2>/dev/null)
        mode=$(stat -c '%a' "$home" 2>/dev/null)

        if [[ "$owner" != "$user" ]]; then
            home_issues+="User '$user' home directory '$home' is owned by '$owner'\n"
        fi

        if (( (8#$mode) & 027 )); then
            home_issues+="User '$user' home directory '$home' is mode '$mode' and should be 750 or more restrictive\n"
        fi
    done < <(awk -v pat="$valid_shells" -F: '$(NF) ~ pat {print $1 ":" $(NF-1)}' /etc/passwd)

    if [[ "${DRY_RUN}" == true ]]; then
        if [[ -z "$home_issues" ]]; then
            log_success "[${control_id}] PASS: Local interactive user home directories are configured"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Issues found with local interactive user home directories"
            log_warning "[${control_id}] REVIEW: $home_issues"
            ((FAILED_CHECKS++))
        fi
    else
        if [[ -z "$home_issues" ]]; then
            log_success "[${control_id}] PASS: Local interactive user home directories are configured"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Issues found with local interactive user home directories"
            log_warning "[${control_id}] REVIEW: $home_issues"
            ((FAILED_CHECKS++))
        fi
    fi

# 7.2.9 - Ensure local interactive user dot files access is configured
    control_id="7.2.9"
    log_info "[${control_id}] Ensure local interactive user dot files access is configured"
    ((TOTAL_CHECKS++))

    local dot_issues=""

    while IFS=: read -r user home; do
        if [[ -z "$user" || -z "$home" || ! -d "$home" ]]; then
            continue
        fi

        local group
        group=$(id -gn "$user" 2>/dev/null)

        while IFS= read -r -d $'\0' file; do
            local base mode owner gowner
            base=$(basename "$file")
            mode=$(stat -c '%a' "$file" 2>/dev/null)
            owner=$(stat -c '%U' "$file" 2>/dev/null)
            gowner=$(stat -c '%G' "$file" 2>/dev/null)

            case "$base" in
                .forward|.rhost)
                    dot_issues+="User '$user' home file '$file' should not exist\n"
                    ;;
                .netrc)
                    if (( (8#$mode) & 0177 )); then
                        dot_issues+="User '$user' dot file '$file' is mode '$mode' and should be 0600 or more restrictive\n"
                    fi
                    if [[ "$owner" != "$user" ]]; then
                        dot_issues+="User '$user' dot file '$file' is owned by '$owner'\n"
                    fi
                    if [[ "$gowner" != "$group" ]]; then
                        dot_issues+="User '$user' dot file '$file' group owner is '$gowner' and should be '$group'\n"
                    fi
                    ;;
                .bash_history)
                    if (( (8#$mode) & 0177 )); then
                        dot_issues+="User '$user' dot file '$file' is mode '$mode' and should be 0600 or more restrictive\n"
                    fi
                    if [[ "$owner" != "$user" ]]; then
                        dot_issues+="User '$user' dot file '$file' is owned by '$owner'\n"
                    fi
                    if [[ "$gowner" != "$group" ]]; then
                        dot_issues+="User '$user' dot file '$file' group owner is '$gowner' and should be '$group'\n"
                    fi
                    ;;
                *)
                    if (( (8#$mode) & 0133 )); then
                        dot_issues+="User '$user' dot file '$file' is mode '$mode' and should be 0644 or more restrictive\n"
                    fi
                    if [[ "$owner" != "$user" ]]; then
                        dot_issues+="User '$user' dot file '$file' is owned by '$owner'\n"
                    fi
                    if [[ "$gowner" != "$group" ]]; then
                        dot_issues+="User '$user' dot file '$file' group owner is '$gowner' and should be '$group'\n"
                    fi
                    ;;
            esac
        done < <(find "$home" -xdev -type f -name '.*' -print0 2>/dev/null)
    done < <(awk -v pat="$valid_shells" -F: '$(NF) ~ pat {print $1 ":" $(NF-1)}' /etc/passwd)

    if [[ "${DRY_RUN}" == true ]]; then
        if [[ -z "$dot_issues" ]]; then
            log_success "[${control_id}] PASS: Local interactive user dot file access is configured"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Issues found with local interactive user dot file permissions"
            log_warning "[${control_id}] REVIEW: $dot_issues"
            ((FAILED_CHECKS++))
        fi
    else
        if [[ -z "$dot_issues" ]]; then
            log_success "[${control_id}] PASS: Local interactive user dot file access is configured"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL: Issues found with local interactive user dot file permissions"
            log_warning "[${control_id}] REVIEW: $dot_issues"
            ((FAILED_CHECKS++))
        fi
    fi
}

################################################################################
# SECTION 7 MAIN RUNNER
################################################################################

run_section_7() {
    remediate_system_file_permissions
    remediate_user_group_settings
}


