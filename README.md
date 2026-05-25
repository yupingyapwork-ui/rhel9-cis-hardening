# RHEL 9 CIS Benchmark Automated Compliance Tool

## Overview

A comprehensive, production-ready automated compliance tool for configuring Red Hat Enterprise Linux 9 servers to meet CIS Benchmark standards v2.0.0. Features a modular architecture designed for maintainability, scalability, and air-gapped environments with complete offline operation.

## 🎯 Implementation Status

**✅ 100% Complete - All 329 CIS Checks Implemented**

| Section | Description | Checks | Status |
|---------|-------------|--------|--------|
| 1 | Initial Setup | 72 | ✅ Complete |
| 2 | Services | 40 | ✅ Complete |
| 3 | Network Configuration | 13 | ✅ Complete |
| 4 | Firewall Configuration | 11 | ✅ Complete |
| 5 | Access Control | 71 | ✅ Complete |
| 6 | Logging and Auditing | 100 | ✅ Complete |
| 7 | System Maintenance | 22 | ✅ Complete |

---

## 🚀 Quick Start

### Prerequisites

- Root/sudo access
- RHEL 9 operating system
- Bash shell
- At least 1GB free disk space in `/var`

### Installation

```bash
# Clone or extract to /opt
cd /opt
# Extract RHEL9-CIS-Tool directory

# Make scripts executable
cd RHEL9-CIS-Tool
chmod +x rhel9-cis-compliance-modular.sh
chmod +x lib/*.sh
```

### Basic Usage

```bash
# 1. Check compliance without making changes (RECOMMENDED FIRST STEP)
sudo ./rhel9-cis-compliance-modular.sh --dry-run

# 2. Review the HTML report
firefox /var/lib/cis-compliance/reports/compliance-report-*.html

# 3. Apply fixes with confirmation for each change
sudo ./rhel9-cis-compliance-modular.sh --interactive

# 4. Apply all fixes automatically (use with caution!)
sudo ./rhel9-cis-compliance-modular.sh --auto
```

### Section-Specific Operations

```bash
# Run specific section only
sudo ./rhel9-cis-compliance-modular.sh --section=1 --dry-run

# Run multiple sections
sudo ./rhel9-cis-compliance-modular.sh --section=1 --section=5 --auto

# Interactive section selection menu
sudo ./rhel9-cis-compliance-modular.sh --sections --interactive
```

---

## 📁 Project Structure

```
RHEL9-CIS-Tool/
├── rhel9-cis-compliance-modular.sh    # Main orchestrator (USE THIS)
├── lib/                               # Modular section libraries
│   ├── common.sh                      # Shared functions & utilities
│   ├── section-1.sh                   # ✅ Initial Setup (72 checks)
│   ├── section-2.sh                   # ✅ Services (40 checks)
│   ├── section-3.sh                   # ✅ Network Configuration (13 checks)
│   ├── section-4.sh                   # ✅ Firewall Configuration (11 checks)
│   ├── section-5.sh                   # ✅ Access Control (71 checks)
│   ├── section-6.sh                   # ✅ Logging and Auditing (100 checks)
│   └── section-7.sh                   # ✅ System Maintenance (22 checks)
├── docs/                              # Documentation
│   ├── IMPLEMENTATION_STATUS.md       # Detailed implementation status
│   └── MANUAL_CHECKS_GUIDE.md         # Manual intervention guide
├── banner-samples/                    # Custom banner templates
├── checklist/                         # Deployment checklists
└── sample-log/                        # Example outputs
```

---

## ✨ Features

### Core Capabilities

- ✅ **Complete CIS Coverage**: All 329 checks across 7 sections
- ✅ **Compliance Checking**: Dry-run mode to assess current state
- ✅ **Automated Remediation**: Apply fixes automatically or interactively
- ✅ **Backup & Rollback**: Automatic backup of all modified files
- ✅ **Section Selection**: Run specific sections or all sections
- ✅ **Enhanced Logging**: Three separate logs (main, failed checks, manual checks) with detailed troubleshooting information
- ✅ **Professional Reports**: HTML and text compliance reports
- ✅ **Custom Banners**: Support for organization-specific warning banners
- ✅ **Manual Check Tracking**: Clear identification of site-policy checks

### Modular Architecture Benefits

- 🔧 **Maintainable**: Each section in its own file (vs 1276-line monolith)
- 📈 **Scalable**: Easy to add new checks or extend functionality
- 🧪 **Testable**: Individual sections can be tested independently
- 👥 **Collaborative**: Multiple developers can work simultaneously
- 📚 **Clear**: Separation of concerns with focused modules

---

## 🔧 Command-Line Options

```
--dry-run          Report compliance status without making changes
--interactive      Prompt for confirmation before each remediation
--auto             Apply all remediations without interaction
--sections         Select specific sections to remediate (interactive menu)
--section=N        Remediate specific section (e.g., --section=1)
--banner-file=PATH Custom banner text file for warning banners
--backup-only      Create backups without applying changes
--rollback         Restore from previous backup
--report           Generate compliance report only
--help             Display help message
```

---

## 🎮 Usage Examples

### Scenario 1: First-Time Assessment

```bash
# Step 1: Check current compliance
sudo ./rhel9-cis-compliance-modular.sh --dry-run

# Step 2: Review the HTML report
firefox /var/lib/cis-compliance/reports/compliance-report-*.html

# Step 3: Apply fixes interactively
sudo ./rhel9-cis-compliance-modular.sh --interactive

# Step 4: Verify results
sudo ./rhel9-cis-compliance-modular.sh --dry-run
```

### Scenario 2: Harden New Server

```bash
# Apply all sections automatically
sudo ./rhel9-cis-compliance-modular.sh --auto

# Or apply specific sections
sudo ./rhel9-cis-compliance-modular.sh --section=1 --section=5 --section=6 --auto

# Reboot if needed
sudo reboot
```

### Scenario 3: Selective Hardening

```bash
# Use interactive section selection
sudo ./rhel9-cis-compliance-modular.sh --sections --interactive

# Select specific sections when prompted
# Example: 1 3 4 5 7
```

### Scenario 4: Custom Banner

```bash
# Use organization-specific banner
sudo ./rhel9-cis-compliance-modular.sh \
  --banner-file=./banner-samples/generic-banner.txt \
  --section=1 --auto
```

### Scenario 5: Compliance Reporting Only

```bash
# Generate reports without remediation
sudo ./rhel9-cis-compliance-modular.sh --report
```

---

## 🪧 Custom Banner Samples

The `banner-samples/` directory contains sample banner text files that can be used with the `--banner-file` option.

### Usage

```bash
# Use a custom banner file
sudo ./rhel9-cis-compliance-modular.sh --banner-file=./banner-samples/generic-banner.txt --auto
```

### Available Samples

#### `generic-banner.txt`

Generic warning banner suitable for most organizations.

- General unauthorized access warning
- Monitoring and logging notice
- Suitable for commercial and government use

### Creating Your Own Banner

Create a text file with your organization's warning message:

```bash
# Example: Create a custom banner
cat > my-custom-banner.txt << 'EOF'
###############################################################################
#                                                                             #
#                      YOUR ORGANIZATION NAME                                  #
#                      AUTHORIZED ACCESS ONLY                                  #
#                                                                             #
#  Your custom warning message here...                                         #
#                                                                             #
###############################################################################
EOF

# Use it with the script
sudo ./rhel9-cis-compliance-modular.sh --banner-file=./my-custom-banner.txt --auto
```

### Banner Guidelines

#### CIS Benchmark Requirements

According to CIS Benchmark Section 1.7, warning banners should:

1. **Not contain** system information (OS version, hostname, etc.)
2. **Include** appropriate use notification
3. **Include** monitoring/logging notice
4. **Include** legal consequences warning

#### Best Practices

1. **Keep it concise** - Users should be able to read it quickly
2. **Be clear** - Use simple, direct language
3. **Be legal** - Consult your legal team for appropriate wording
4. **Be consistent** - Use the same banner across all systems
5. **Update regularly** - Review and update as policies change

#### Format Tips

- Use `#` for borders to make it stand out
- Keep lines under 80 characters for terminal compatibility
- Center-align text for better readability
- Leave blank lines for spacing

### Examples for Different Organizations

#### Financial Institution

```text
###############################################################################
#                                                                             #
#                      BANK XYZ - AUTHORIZED ACCESS ONLY                       #
#                                                                             #
#  This system contains confidential financial information. Unauthorized       #
#  access is prohibited and will be prosecuted to the fullest extent of        #
#  the law. All activities are monitored and recorded.                         #
#                                                                             #
###############################################################################
```

#### Healthcare Organization

```text
###############################################################################
#                                                                             #
#                  HOSPITAL ABC - PROTECTED HEALTH INFORMATION                 #
#                                                                             #
#  This system contains Protected Health Information (PHI) subject to          #
#  HIPAA regulations. Unauthorized access is strictly prohibited.              #
#  All access is monitored and logged.                                         #
#                                                                             #
###############################################################################
```

#### Government Agency

```text
###############################################################################
#                                                                             #
#                  GOVERNMENT AGENCY - OFFICIAL USE ONLY                       #
#                                                                             #
#  This is a government computer system. Unauthorized access or misuse         #
#  is subject to criminal and civil penalties. All activities are              #
#  monitored and may be disclosed to law enforcement.                          #
#                                                                             #
###############################################################################
```

#### Educational Institution

```text
###############################################################################
#                                                                             #
#                  UNIVERSITY XYZ - AUTHORIZED USERS ONLY                      #
#                                                                             #
#  This system is for authorized university personnel and students only.       #
#  Unauthorized access violates university policy and may result in            #
#  disciplinary action. All activities are logged.                             #
#                                                                             #
###############################################################################
```

### Testing Your Banner

Before deploying, test your banner:

```bash
# Preview the banner
cat my-custom-banner.txt

# Test with dry-run mode
sudo ./rhel9-cis-compliance-modular.sh --banner-file=./my-custom-banner.txt --section=1.7 --dry-run

# Apply to test system first
sudo ./rhel9-cis-compliance-modular.sh --banner-file=./my-custom-banner.txt --section=1.7 --interactive
```

### Banner Locations

The script applies the banner to three locations:

- `/etc/motd` - Message of the Day (shown after login)
- `/etc/issue` - Local login banner (shown before login on console)
- `/etc/issue.net` - Remote login banner (shown before SSH login)

### Compliance Notes

- The banner file must be readable by the script
- The script will fall back to the default generic banner if the file is not found
- Banner files should be stored securely and version controlled
- Review banners annually or when policies change

### Support

For questions about banner content:

- Consult your organization's legal team
- Review your organization's security policies
- Refer to CIS Benchmark Section 1.7 for technical requirements

---

## 📊 Enhanced Logging System

### 1. Purpose

The enhanced logging system addresses critical operational needs:

**Problem Solved**: Traditional single-log approach makes it difficult to:
- Identify why specific checks failed
- Understand current vs. expected system state
- Get actionable remediation guidance
- Track manual checks requiring attention

**Solution**: Three specialized log files providing:
- **Troubleshooting**: Detailed failure analysis with current/expected states
- **Remediation**: Exact commands to fix issues
- **Compliance**: Documentation for manual checks and audit trails
- **Efficiency**: Separate logs for different purposes (no searching through massive files)

### 2. How to Use

#### Log Files Location
All logs are stored in `/var/cis-compliance/log` with timestamps in format `YYYYMMDD_HHMMSS`.

#### Three Log Files Generated

**A. Main Compliance Log** (`cis-compliance-TIMESTAMP.log`)
- **Purpose**: Complete execution log with all checks and results
- **Contents**: Pre-execution validation, all check executions (PASS/FAIL/MANUAL), remediation actions, summary statistics
- **Use When**: You need to see the complete execution flow and overall results

**Example Entry**:
```
[2026-05-16 16:14:20] [INFO] [6.1.1] Ensure AIDE is installed
[2026-05-16 16:14:20] [SUCCESS] [6.1.1] PASS: AIDE is installed
```

**B. Failed Checks Log** (`failed-checks-TIMESTAMP.log`)
- **Purpose**: Detailed information about each failed compliance check
- **Contents**: Check ID, current system state, expected state, failure reason, remediation commands
- **Use When**: You need to troubleshoot failures and understand how to fix them

**Example Entry**:
```
================================================================================
CHECK ID: 3.3.2
TIMESTAMP: 2026-05-16 16:41:42
STATUS: FAILED
================================================================================
TITLE: net.ipv6.conf.default.accept_redirects = 1 (expected 0)

CURRENT STATE:
net.ipv6.conf.default.accept_redirects = 1

EXPECTED STATE:
net.ipv6.conf.default.accept_redirects = 0

REASON FOR FAILURE:
Parameter net.ipv6.conf.default.accept_redirects is set to 1 but should be 0

REMEDIATION GUIDANCE:
Set net.ipv6.conf.default.accept_redirects to 0 in the appropriate configuration file

================================================================================
```

**C. Manual Checks Log** (`manual-checks-TIMESTAMP.log`)
- **Purpose**: Comprehensive details for checks requiring manual review
- **Contents**: Check ID, current configuration, required actions, step-by-step verification, organizational context
- **Use When**: You need to implement site-specific policies or configurations

**Example Entry**:
```
================================================================================
CHECK ID: 6.2.1.2
TIMESTAMP: 2026-05-16 16:14:20
STATUS: REQUIRES MANUAL REVIEW
================================================================================
TITLE: Ensure journald log file access is configured

CURRENT STATE:
Current permissions: drwxr-sr-x 2 root systemd-journal 4096 May 16 16:14 /var/log/journal

REQUIRED ACTION:
Configure appropriate permissions on /var/log/journal directory

VERIFICATION STEPS:
1. Check current permissions: ls -ld /var/log/journal
2. Set ownership: chown root:systemd-journal /var/log/journal
3. Set permissions: chmod 2755 /var/log/journal
4. Verify: ls -ld /var/log/journal

ADDITIONAL INFORMATION:
Proper log file access controls prevent unauthorized viewing or modification of system logs

REFERENCES:
- CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0
- Section: 6
- Control: 6.2.1.2

================================================================================
```

#### Viewing Logs

```bash
# View main execution log
less /var/log/cis-compliance/cis-compliance-*.log

# View only failed checks with remediation guidance
less /var/log/cis-compliance/failed-checks-*.log

# View manual checks requiring your attention
less /var/log/cis-compliance/manual-checks-*.log

# Search for specific check
grep "3.3.2" /var/log/cis-compliance/failed-checks-*.log

# Count failed checks
grep -c "STATUS: FAILED" /var/log/cis-compliance/failed-checks-*.log

# Count manual checks
grep -c "STATUS: REQUIRES MANUAL REVIEW" /var/log/cis-compliance/manual-checks-*.log
```

#### Typical Workflow

1. **Run Assessment**:
   ```bash
   sudo ./rhel9-cis-compliance-modular.sh --dry-run
   ```

2. **Review Failed Checks**:
   ```bash
   less /var/log/cis-compliance/failed-checks-*.log
   ```
   - Understand what failed and why
   - Note the remediation commands
   - Plan fixes based on priority

3. **Review Manual Checks**:
   ```bash
   less /var/log/cis-compliance/manual-checks-*.log
   ```
   - Identify site-specific configurations needed
   - Follow verification steps
   - Document decisions made

4. **Apply Remediations**:
   ```bash
   sudo ./rhel9-cis-compliance-modular.sh --interactive
   ```

5. **Verify Results**:
   ```bash
   sudo ./rhel9-cis-compliance-modular.sh --dry-run
   # Check if failed-checks log is now empty or reduced
   ```

### 3. Design Considerations

#### Automatic Detection
The system uses **intelligent pattern matching** in the [`log_warning()`](lib/common.sh:79) function:
- Automatically detects `[X.X.X] FAIL: description` patterns
- Automatically detects `[X.X.X] MANUAL: description` patterns
- Parses `parameter = value (expected other)` format
- Routes to appropriate detailed log files

**Key Benefit**: All existing code automatically benefits without modification. No changes needed to section files (1-7).

#### Smart Parsing
For failed checks, the system automatically extracts:
- **Parameter name**: From the failure message
- **Current value**: What the system currently has
- **Expected value**: What it should be
- **Remediation**: Generated based on the parameter type

**Example Pattern Recognition**:
```
Input:  [3.3.2] FAIL: net.ipv6.conf.default.accept_redirects = 1 (expected 0)
Output:
  - Parameter: net.ipv6.conf.default.accept_redirects
  - Current: 1
  - Expected: 0
  - Remediation: Set net.ipv6.conf.default.accept_redirects to 0 in /etc/sysctl.conf
```

#### Backward Compatibility
- Existing [`log_warning()`](lib/common.sh:77), [`log_error()`](lib/common.sh:173), [`log_success()`](lib/common.sh:72) functions unchanged
- All 329 checks across 7 sections work without modification
- Enhanced logging is additive, not disruptive

#### Performance
- Log writes are non-blocking (use `2>/dev/null || true`)
- Minimal overhead (regex matching only on WARNING messages)
- No impact on check execution speed

### 4. Notes to Consider

#### Important Limitations

1. **Pattern Dependency**: Automatic parsing works best with standardized message formats:
   - `[X.X.X] FAIL: description` → Detected
   - `[X.X.X] FAIL: param = value (expected other)` → Parsed with details
   - Custom formats may not be parsed automatically

2. **Manual Check Detail**: For maximum detail in manual checks, use explicit [`log_check_manual()`](lib/common.sh:119) function instead of relying on automatic detection.

3. **File Permissions**: Log files are created with default permissions. Consider:
   ```bash
   # Restrict access to logs (contain system configuration details)
   chmod 600 /var/log/cis-compliance/*.log
   ```

4. **Disk Space**: Three log files consume more space than one:
   - Main log: ~100-500 KB
   - Failed checks: ~10-100 KB (depends on failures)
   - Manual checks: ~50-200 KB (depends on manual checks)
   - **Total**: ~200-800 KB per run

5. **Log Rotation**: Consider implementing log rotation:
   ```bash
   # Keep only last 10 runs
   cd /var/log/cis-compliance
   ls -t cis-compliance-*.log | tail -n +11 | xargs rm -f
   ls -t failed-checks-*.log | tail -n +11 | xargs rm -f
   ls -t manual-checks-*.log | tail -n +11 | xargs rm -f
   ```

#### Best Practices

1. **Always Review Failed Checks Log First**: It provides the most actionable information for remediation.

2. **Document Manual Check Decisions**: When implementing manual checks, document your decisions:
   ```bash
   # Add notes to manual checks log
   echo "DECISION: Configured journald with SystemMaxUse=1G per policy" >> /var/log/cis-compliance/manual-checks-*.log
   ```

3. **Archive Logs for Compliance**: Keep logs as evidence of compliance efforts:
   ```bash
   # Archive logs with date
   tar -czf compliance-logs-$(date +%Y%m%d).tar.gz /var/log/cis-compliance/
   ```

4. **Use Logs for Trending**: Compare logs over time to track compliance improvements:
   ```bash
   # Compare failed check counts
   grep -c "STATUS: FAILED" /var/log/cis-compliance/failed-checks-20260516*.log
   grep -c "STATUS: FAILED" /var/log/cis-compliance/failed-checks-20260517*.log
   ```

5. **Integrate with Monitoring**: Consider parsing logs for monitoring systems:
   ```bash
   # Extract failed check count for monitoring
   FAILED_COUNT=$(grep -c "STATUS: FAILED" /var/log/cis-compliance/failed-checks-*.log)
   echo "cis_failed_checks ${FAILED_COUNT}" | nc monitoring-server 9091
   ```

#### Security Considerations

- **Sensitive Information**: Logs may contain system configuration details. Protect accordingly.
- **Access Control**: Restrict log file access to authorized personnel only.
- **Audit Trail**: Logs serve as audit evidence. Implement tamper-protection if required.
- **Retention Policy**: Define and implement log retention policies per organizational requirements.

---

## 📊 Output Files

After execution, find reports and logs in:

- **HTML Report**: `/var/lib/cis-compliance/reports/compliance-report-TIMESTAMP.html`
- **Text Report**: `/var/lib/cis-compliance/reports/compliance-report-TIMESTAMP.txt`
- **Log File**: `/var/log/cis-compliance/cis-compliance-TIMESTAMP.log`
- **Backups**: `/var/lib/cis-compliance/backups/TIMESTAMP/`
- **Rollback Script**: `/var/lib/cis-compliance/rollback/rollback-TIMESTAMP.sh`

### Understanding Output

**Console Output:**
```
[INFO] Starting CIS Benchmark compliance assessment...
[SUCCESS] [1.1.1.1] PASS: cramfs module is not loaded
[WARNING] [1.1.1.2] FAIL: freevxfs module is loaded
[INFO] [1.1.1.2] Remediated: freevxfs disabled
```

**Summary Report:**
```
===============================================================================
CIS BENCHMARK COMPLIANCE ASSESSMENT SUMMARY
===============================================================================
Total Checks:           329
Passed Checks:          250
Failed Checks:          79
Remediated Checks:      75
Manual Review Required: 4
===============================================================================
```

---

## 🏗️ Architecture

### Module Descriptions

#### Main Orchestrator (`rhel9-cis-compliance-modular.sh`)
The main entry point that:
- Parses command-line arguments
- Sources all library modules
- Coordinates execution flow
- Generates reports and summaries

#### Common Library (`lib/common.sh`)
Contains shared functionality:
- Logging functions (`log_info`, `log_success`, `log_warning`, `log_error`)
- Utility functions (`print_banner`, `print_usage`, `show_section_menu`)
- Section selection logic (`should_run_section`)
- User interaction (`confirm_action`)
- File operations (`backup_file`, `create_directories`)
- Validation functions (`check_root`, `check_rhel9`, `check_disk_space`)
- Report generation (`generate_html_report`, `generate_text_report`)

#### Section Modules (`lib/section-*.sh`)
Each section implements specific CIS Benchmark controls:

- **Section 1** - Initial Setup (72 checks)
  - Filesystem configuration, software updates, SELinux, secure boot, process hardening, crypto policy, warning banners, GDM

- **Section 2** - Services (40 checks)
  - Server services, client services, time synchronization, job schedulers

- **Section 3** - Network Configuration (13 checks)
  - Unused protocols, network parameters (host and router)

- **Section 4** - Firewall Configuration (11 checks)
  - Firewall software, firewalld, nftables

- **Section 5** - Access Control (71 checks)
  - SSH server, privilege escalation, PAM, user accounts and environment

- **Section 6** - Logging and Auditing (100 checks)
  - AIDE integrity checking, system logging (journald/rsyslog), auditd

- **Section 7** - System Maintenance (22 checks)
  - System file permissions, user and group settings

---

## 🛡️ Security Considerations

### Best Practices

1. **Always test in dry-run mode first**
   ```bash
   sudo ./rhel9-cis-compliance-modular.sh --dry-run
   ```

2. **Use interactive mode for production systems**
   ```bash
   sudo ./rhel9-cis-compliance-modular.sh --interactive
   ```

3. **Review reports before applying fixes**
   - Check the HTML report
   - Understand what will change
   - Plan for potential downtime

4. **Backup critical systems before remediation**
   ```bash
   # The tool creates backups, but consider additional backups
   sudo tar -czf /backup/system-backup-$(date +%Y%m%d).tar.gz /etc
   ```

5. **Test on non-production systems first**
   - Use a test VM or container
   - Verify application compatibility
   - Document any issues

6. **Schedule maintenance windows**
   - Some changes require reboot
   - Services may need restart
   - Plan for potential issues

### Manual Checks

Some controls require manual intervention due to site-specific policies:
- Bootloader password configuration (1.4.1)
- Repository verification (1.2.1.4)
- SSH access lists (5.1.7)
- Password complexity policies (5.3.3.2.3)
- Network interface zone assignment (4.2.4)
- Custom firewall rules (4.2.5, 4.3.3-4.3.5)
- Logging and auditing configurations (Section 6.2-6.3)
- Root account access control (5.4.2.4-5.4.2.5)

See [`docs/MANUAL_CHECKS_GUIDE.md`](docs/MANUAL_CHECKS_GUIDE.md) for detailed guidance.

---

## 🔨 Development

### Adding New Checks

1. Open the appropriate section file (e.g., `lib/section-1.sh`)
2. Add your remediation function following the existing pattern:

```bash
remediate_new_control() {
    if ! should_run_section "X.Y"; then
        log_info "Skipping Section X.Y (not selected)"
        return 0
    fi

    log_info "=== Section X.Y: Description ==="

    local control_id="X.Y.Z"
    log_info "[${control_id}] Ensure description"
    ((TOTAL_CHECKS++))

    if [[ "${DRY_RUN}" == true ]]; then
        # Check compliance
        if check_condition; then
            log_success "[${control_id}] PASS"
            ((PASSED_CHECKS++))
        else
            log_warning "[${control_id}] FAIL"
            ((FAILED_CHECKS++))
        fi
        return 0
    fi

    if confirm_action "[${control_id}] Apply remediation?"; then
        backup_file "/path/to/file"
        # Apply remediation
        log_success "[${control_id}] Remediated"
        ((REMEDIATED_CHECKS++))
    fi
}
```

3. Add the function call to the section's main runner (e.g., `run_section_1()`)

### Testing Changes

```bash
# Syntax check
bash -n lib/section-X.sh

# Dry-run test
./rhel9-cis-compliance-modular.sh --section=X --dry-run

# Interactive test
./rhel9-cis-compliance-modular.sh --section=X --interactive
```

---

## 🐛 Troubleshooting

### Permission Denied
```bash
chmod +x rhel9-cis-compliance-modular.sh
chmod +x lib/*.sh
```

### Module Not Found
```bash
# Verify lib directory exists
ls -la lib/

# Ensure you're in the correct directory
cd /path/to/RHEL9-CIS-Tool
```

### Insufficient Disk Space
```bash
# Check available space
df -h /var

# Clean up old backups if needed
sudo rm -rf /var/lib/cis-compliance/backups/OLD_TIMESTAMP
```

### Check Logs
```bash
# View latest log
sudo tail -f /var/log/cis-compliance/cis-compliance-*.log

# Search for errors
sudo grep ERROR /var/log/cis-compliance/cis-compliance-*.log
```

---

## 📖 Documentation

- **[Implementation Status](docs/IMPLEMENTATION_STATUS.md)** - Detailed check-by-check status
- **[Manual Checks Guide](docs/MANUAL_CHECKS_GUIDE.md)** - Manual intervention required
- **[Deployment Checklist](checklist/DEPLOYMENT_CHECKLIST.md)** - Pre/post deployment steps

---

## 🤝 Contributing

When contributing:

1. Follow the established coding patterns
2. Add comprehensive logging
3. Include dry-run checks for all remediations
4. Update documentation for new features
5. Test thoroughly before submitting

---

## 📝 Version History

- **v2.0.0** (2026-05-16): Complete implementation
  - ✅ All 329 CIS checks implemented (100%)
  - ✅ Sections 1-7 fully functional
  - ✅ Comprehensive documentation
  - ✅ Production-ready modular architecture

- **v1.0.0** (2026-05-15): Initial modular architecture
  - Refactored from monolithic script
  - Implemented Sections 1, 2, 3, 4, 5, 7
  - Created modular structure

---

## 📄 License

This tool is provided as-is for CIS Benchmark compliance automation.

---

## 🔗 References

- [CIS Red Hat Enterprise Linux 9 Benchmark v2.0.0](CIS_Red_Hat_Enterprise_Linux_9_Benchmark_v2.0.0.pdf)
- [Center for Internet Security](https://www.cisecurity.org/)

---

## ⚠️ Disclaimer

This tool automates CIS Benchmark compliance but:
- Does not guarantee 100% compliance
- Requires manual verification of some controls
- Should be tested before production use
- May require customization for your environment
- Is not officially endorsed by CIS

Always review changes and test thoroughly before deploying to production systems.

---
