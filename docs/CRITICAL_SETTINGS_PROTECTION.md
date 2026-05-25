# Critical Settings Protection

This document describes the protections in place to prevent disruptive changes when using `--auto` or `--interactive` modes.

## Overview

Certain system settings are so critical that changing them automatically could:
- Lock administrators out of the system
- Break existing automation
- Disrupt production services
- Require console access to recover

These settings are protected by the `confirm_critical_action()` function which **ALWAYS requires explicit manual confirmation**, even in `--auto` mode.

## Protected Settings

### 1. SSH Root Login (5.1.20 - PermitRootLogin)

**Why Protected:**
- Disabling root SSH login without alternative access can lock you out
- Requires console access or another user with sudo to recover

**Protection:**
```bash
confirm_critical_action "[5.1.20] Set PermitRootLogin no?" \
    "WARNING: Disabling root login via SSH may lock you out if you don't have another way to access the system!
- Ensure you have a non-root user with sudo privileges
- Ensure you can access the system via console or other means
- Current setting: PermitRootLogin = ${actual}
- Proposed setting: PermitRootLogin = no"
```

**User Must:**
- Type "yes" (not just "y") to confirm
- Verify they have alternative access before proceeding

### 2. Sudoers Configuration

All sudoers modifications require critical confirmation to prevent breaking system administration access.

#### 5.2.1 - sudo use_pty
**Impact:** Requires sudo commands to run in pseudo-terminal
**Risk Level:** Low (generally safe)

#### 5.2.2 - sudo logfile
**Impact:** Adds logging to /var/log/sudo.log
**Risk Level:** Low (generally safe)

#### 5.2.3 - NOPASSWD Removal
**Impact:** **DISABLES passwordless sudo access**
**Risk Level:** **HIGH** - May break:
- Automation scripts
- Service accounts
- Scheduled tasks
- CI/CD pipelines

**Warning:**
```
WARNING: This will DISABLE passwordless sudo access!
- All NOPASSWD entries in sudoers will be commented out
- Users will be required to enter passwords for sudo
- This may break automation scripts or services
- Review /etc/sudoers and /etc/sudoers.d/* before proceeding
```

#### 5.2.4 - !authenticate Removal
**Impact:** Enforces re-authentication for privilege escalation
**Risk Level:** Medium - May affect workflows

#### 5.2.5 - timestamp_timeout
**Impact:** Changes sudo password cache to 15 minutes
**Risk Level:** Low - May affect user experience

### 3. Bootloader Password (1.4.1)

**Status:** **CHECK ONLY - NO REMEDIATION**

The script only checks if `/boot/grub2/user.cfg` exists. It **NEVER** attempts to set a bootloader password automatically.

**Behavior:**
- ✅ Checks for password file existence
- ✅ Logs as manual check if not found
- ✅ Provides instructions for manual setup
- ❌ Never executes `grub2-setpassword`
- ❌ Never modifies grub configuration

**Why No Auto-Remediation:**
- Setting wrong password could prevent system boot
- Requires physical/console access to recover
- Password must be securely documented
- Organization-specific password policies apply

## Implementation Details

### confirm_critical_action() Function

Located in: `lib/common.sh`

```bash
confirm_critical_action() {
    local prompt="$1"
    local warning="$2"
    local response
    
    # ALWAYS require manual confirmation for critical changes, even in --auto mode
    echo ""
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                           ⚠️  CRITICAL CHANGE  ⚠️                            ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "${warning}"
    echo ""
    read -p "${prompt} (yes/no): " -r response
    echo
    [[ "${response}" == "yes" ]]
}
```

**Key Features:**
- Ignores `--auto` mode flag
- Requires typing "yes" (not just "y")
- Displays prominent warning banner
- Shows detailed impact information
- Returns false if user types anything except "yes"

### Regular confirm_action() Function

For non-critical changes:
```bash
confirm_action() {
    local prompt="$1"
    local response
    
    if [[ "${INTERACTIVE}" == true ]]; then
        read -p "${prompt} (y/n): " -n 1 -r response
        echo
        [[ $response =~ ^[Yy]$ ]]
    else
        return 0  # Auto-approve in --auto mode
    fi
}
```

## Usage Examples

### Safe: Regular Changes in --auto Mode
```bash
./rhel9-cis-compliance-modular.sh --auto --section=1
```
- File permissions: ✅ Applied automatically
- Package installations: ✅ Applied automatically
- Service configurations: ✅ Applied automatically
- **Critical settings: ❌ Require manual confirmation**

### Critical Changes Always Require Confirmation
```bash
./rhel9-cis-compliance-modular.sh --auto --section=5
```

When reaching PermitRootLogin check:
```
╔════════════════════════════════════════════════════════════════════════════╗
║                           ⚠️  CRITICAL CHANGE  ⚠️                            ║
╚════════════════════════════════════════════════════════════════════════════╝

WARNING: Disabling root login via SSH may lock you out if you don't have another way to access the system!
- Ensure you have a non-root user with sudo privileges
- Ensure you can access the system via console or other means
- Current setting: PermitRootLogin = yes
- Proposed setting: PermitRootLogin = no

[5.1.20] Set PermitRootLogin no? (yes/no): _
```

User must type "yes" to proceed, or anything else to skip.

## Best Practices

### Before Running --auto Mode

1. **Review the changes** that will be applied
2. **Ensure alternative access** (console, non-root user with sudo)
3. **Test in non-production** environment first
4. **Have rollback plan** ready
5. **Document current state** before changes

### For Critical Settings

1. **Never blindly approve** critical changes
2. **Read the warning** carefully
3. **Verify prerequisites** are met
4. **Test access** after changes
5. **Keep console access** available during changes

### Recovery Procedures

If locked out after changes:

1. **Console Access:**
   - Physical console
   - Virtual console (VM/cloud)
   - IPMI/iLO/iDRAC

2. **Rollback:**
   ```bash
   ./rhel9-cis-compliance-modular.sh --rollback
   ```

3. **Manual Fix:**
   - Boot to single-user mode
   - Edit `/etc/ssh/sshd_config.d/00-cis-hardening.conf`
   - Edit `/etc/sudoers.d/00-cis`
   - Restart services

## Summary

| Setting | Auto-Applied | Requires Confirmation | Risk Level |
|---------|--------------|----------------------|------------|
| File permissions | ✅ Yes | ❌ No | Low |
| Package installs | ✅ Yes | ❌ No | Low |
| Service configs | ✅ Yes | ❌ No | Low-Medium |
| **PermitRootLogin** | ❌ No | ✅ Yes (critical) | **HIGH** |
| **Sudoers NOPASSWD** | ❌ No | ✅ Yes (critical) | **HIGH** |
| **Sudoers use_pty** | ❌ No | ✅ Yes (critical) | Low |
| **Sudoers logfile** | ❌ No | ✅ Yes (critical) | Low |
| **Sudoers !authenticate** | ❌ No | ✅ Yes (critical) | Medium |
| **Sudoers timeout** | ❌ No | ✅ Yes (critical) | Low |
| **Grub password** | ❌ No | ❌ No (check only) | N/A |

## Version History

- **v2.0.0** - Added critical settings protection
  - Implemented `confirm_critical_action()` function
  - Protected PermitRootLogin from auto-apply
  - Protected all sudoers modifications from auto-apply
  - Verified grub password is check-only