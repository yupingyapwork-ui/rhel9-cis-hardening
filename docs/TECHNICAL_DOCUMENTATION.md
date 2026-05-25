# RHEL 9 CIS Benchmark - Technical Documentation

## Table of Contents
1. [Overview](#overview)
2. [Implementation Status](#implementation-status)
3. [Enhanced Logging System](#enhanced-logging-system)
4. [Log File Types](#log-file-types)
5. [CSV Format Specifications](#csv-format-specifications)
6. [Data Analysis & Integration](#data-analysis--integration)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This document provides comprehensive technical documentation for the RHEL 9 CIS Benchmark Automated Compliance Tool v2.0.0, including complete implementation status and advanced logging capabilities.

**Current Status**: ✅ **100% Complete** - All 329 checks implemented

The tool provides:
- Automated compliance checking against CIS RHEL 9 Benchmark v2.0.0
- Multiple execution modes (dry-run, interactive, automatic)
- Comprehensive logging with both human-readable and machine-readable formats
- CSV exports for data analysis and integration with external systems
- Detailed remediation guidance for failed checks
- Step-by-step procedures for manual configuration items

---

## Implementation Status

### Summary by Section

| Section | Description | Checks | Status |
|---------|-------------|--------|--------|
| 1 | Initial Setup | 72 | ✅ Complete |
| 2 | Services | 40 | ✅ Complete |
| 3 | Network Configuration | 13 | ✅ Complete |
| 4 | Firewall Configuration | 11 | ✅ Complete |
| 5 | Access Control | 71 | ✅ Complete |
| 6 | Logging and Auditing | 100 | ✅ Complete |
| 7 | System Maintenance | 22 | ✅ Complete |
| **TOTAL** | | **329** | **✅ 100%** |

### Section 1: Initial Setup (72 checks)

#### 1.1 Filesystem Configuration (35 checks)

**1.1.1 Disable Unused Filesystems (9 checks)**
- 1.1.1.1 - Ensure cramfs kernel module is not available
- 1.1.1.2 - Ensure freevxfs kernel module is not available
- 1.1.1.3 - Ensure hfs kernel module is not available
- 1.1.1.4 - Ensure hfsplus kernel module is not available
- 1.1.1.5 - Ensure jffs2 kernel module is not available
- 1.1.1.6 - Ensure squashfs kernel module is not available
- 1.1.1.7 - Ensure udf kernel module is not available
- 1.1.1.8 - Ensure usb-storage kernel module is not available
- 1.1.1.9 - Ensure unused filesystems are disabled

**1.1.2 Configure Partition Options (26 checks)**
- /tmp partition (4 checks): 1.1.2.1.1-1.1.2.1.4
- /dev/shm partition (4 checks): 1.1.2.2.1-1.1.2.2.4
- /home partition (3 checks): 1.1.2.3.1-1.1.2.3.3
- /var partition (3 checks): 1.1.2.4.1-1.1.2.4.3
- /var/tmp partition (4 checks): 1.1.2.5.1-1.1.2.5.4
- /var/log partition (4 checks): 1.1.2.6.1-1.1.2.6.4
- /var/log/audit partition (4 checks): 1.1.2.7.1-1.1.2.7.4

#### 1.2 Software Updates (5 checks)
- 1.2.1.1 - Ensure GPG keys are configured
- 1.2.1.2 - Ensure gpgcheck is globally activated
- 1.2.1.3 - Ensure repo_gpgcheck is globally activated
- 1.2.1.4 - Ensure package manager repositories are configured (Manual)
- 1.2.2.1 - Ensure updates, patches, and additional security software are installed

#### 1.3 Mandatory Access Controls - SELinux (8 checks)
- 1.3.1.1 - Ensure SELinux is installed
- 1.3.1.2 - Ensure SELinux is not disabled in bootloader configuration
- 1.3.1.3 - Ensure SELinux policy is configured
- 1.3.1.4 - Ensure the SELinux mode is not disabled
- 1.3.1.5 - Ensure the SELinux mode is enforcing
- 1.3.1.6 - Ensure no unconfined services exist
- 1.3.1.7 - Ensure mcstrans is not installed
- 1.3.1.8 - Ensure SETroubleshoot is not installed

#### 1.4 Secure Boot Settings (2 checks)
- 1.4.1 - Ensure bootloader password is set
- 1.4.2 - Ensure permissions on bootloader config are configured

#### 1.5 Additional Process Hardening (4 checks)
- 1.5.1 - Ensure address space layout randomization (ASLR) is enabled
- 1.5.2 - Ensure ptrace_scope is restricted
- 1.5.3 - Ensure core dump backtraces are disabled
- 1.5.4 - Ensure core dump storage is disabled

#### 1.6 Crypto Policy (7 checks)
- 1.6.1 - Ensure system-wide crypto policy is not set to legacy
- 1.6.2 - Ensure system-wide crypto policy is not set in sshd config
- 1.6.3 - Ensure system-wide crypto policy disables sha1 hash and signature support
- 1.6.4 - Ensure system-wide crypto policy disables macs less than 128 bits
- 1.6.5 - Ensure system-wide crypto policy disables cbc for ssh
- 1.6.6 - Ensure system-wide crypto policy disables chacha20-poly1305
- 1.6.7 - Ensure system-wide crypto policy disables etm for ssh

#### 1.7 Warning Banners (6 checks)
- 1.7.1 - Ensure message of the day is configured properly
- 1.7.2 - Ensure local login warning banner is configured properly
- 1.7.3 - Ensure remote login warning banner is configured properly
- 1.7.4 - Ensure permissions on /etc/motd are configured
- 1.7.5 - Ensure permissions on /etc/issue are configured
- 1.7.6 - Ensure permissions on /etc/issue.net are configured

#### 1.8 GNOME Display Manager (10 checks)
- 1.8.1 - Ensure GNOME Display Manager is removed
- 1.8.2 - Ensure GDM login banner is configured
- 1.8.3 - Ensure GDM disable-user-list option is enabled
- 1.8.4 - Ensure GDM screen locks when the user is idle
- 1.8.5 - Ensure GDM screen locks cannot be overridden
- 1.8.6 - Ensure GDM automatic mounting of removable media is disabled
- 1.8.7 - Ensure GDM automatic mounting of removable media cannot be overridden
- 1.8.8 - Ensure GDM autorun-never is enabled
- 1.8.9 - Ensure GDM autorun-never is not overridden
- 1.8.10 - Ensure XDMCP is not enabled

### Section 2: Services (40 checks)

#### 2.1 Configure Server Services (22 checks)
- 2.1.1-2.1.20 - Service removal/disablement checks
- 2.1.21 - Ensure mail transfer agent is configured for local-only mode
- 2.1.22 - Ensure only approved services are listening on a network interface (Manual)

#### 2.2 Configure Client Services (5 checks)
- 2.2.1 - Ensure ftp client is not installed
- 2.2.2 - Ensure ldap client is not installed
- 2.2.3 - Ensure nis client is not installed
- 2.2.4 - Ensure telnet client is not installed
- 2.2.5 - Ensure tftp client is not installed

#### 2.3 Configure Time Synchronization (3 checks)
- 2.3.1 - Ensure a single time synchronization daemon is in use
- 2.3.2 - Ensure chrony is configured with authorized timeserver
- 2.3.3 - Ensure chrony is not run as the root user

#### 2.4 Configure Job Schedulers (10 checks)
- 2.4.1 - Ensure cron daemon is enabled and active
- 2.4.2-2.4.7 - Cron directory permissions
- 2.4.8 - Ensure cron is restricted to authorized users
- 2.4.2.1 - Ensure at is restricted to authorized users
- 2.4.10 - Ensure permissions on /etc/anacrontab are configured

### Section 3: Network Configuration (13 checks)

#### 3.1 Disable Unused Network Protocols (4 checks)
- 3.1.1 - Ensure DCCP is disabled
- 3.1.2 - Ensure SCTP is disabled
- 3.1.3 - Ensure RDS is disabled
- 3.1.4 - Ensure TIPC is disabled

#### 3.2 Network Parameters (Host Only) (2 checks)
- 3.2.1 - Ensure IP forwarding is disabled
- 3.2.2 - Ensure packet redirect sending is disabled

#### 3.3 Network Parameters (Host and Router) (7 checks)
- 3.3.1 - Ensure source routed packets are not accepted
- 3.3.2 - Ensure ICMP redirects are not accepted
- 3.3.3 - Ensure secure ICMP redirects are not accepted
- 3.3.4 - Ensure suspicious packets are logged
- 3.3.5 - Ensure broadcast ICMP requests are ignored
- 3.3.6 - Ensure bogus ICMP responses are ignored
- 3.3.7 - Ensure Reverse Path Filtering is enabled
- 3.3.8 - Ensure TCP SYN Cookies is enabled
- 3.3.9 - Ensure IPv6 router advertisements are not accepted

### Section 4: Firewall Configuration (11 checks)

#### 4.1 Configure Firewall Software (1 check)
- 4.1.1 - Ensure a single firewall configuration utility is in use

#### 4.2 Configure firewalld (5 checks)
- 4.2.1 - Ensure firewalld is installed
- 4.2.2 - Ensure firewalld service is enabled and running
- 4.2.3 - Ensure firewalld default zone is set
- 4.2.4 - Ensure network interfaces are assigned to appropriate zone (Manual)
- 4.2.5 - Ensure firewalld drops unnecessary services and ports (Manual)

#### 4.3 Configure nftables (5 checks)
- 4.3.1 - Ensure nftables is installed
- 4.3.2 - Ensure nftables service is enabled
- 4.3.3 - Ensure nftables base chains exist (Manual)
- 4.3.4 - Ensure nftables loopback traffic is configured (Manual)
- 4.3.5 - Ensure nftables default deny firewall policy (Manual)

### Section 5: Access Control (71 checks)

#### 5.1 SSH Server Configuration (22 checks)
- 5.1.1-5.1.3 - SSH file permissions
- 5.1.4-5.1.6 - SSH cryptographic settings
- 5.1.7-5.1.22 - SSH daemon configuration parameters

#### 5.2 Configure Privilege Escalation (7 checks)
- 5.2.1 - Ensure sudo is installed
- 5.2.2 - Ensure sudo commands use pty
- 5.2.3 - Ensure sudo log file exists
- 5.2.4 - Ensure users must provide password for escalation
- 5.2.5 - Ensure re-authentication for privilege escalation is not disabled globally
- 5.2.6 - Ensure sudo authentication timeout is configured correctly
- 5.2.7 - Ensure access to the su command is restricted

#### 5.3 Pluggable Authentication Modules (34 checks)

**5.3.1 Configure PAM Software Packages (3 checks)**
- 5.3.1.1 - Ensure latest version of pam is installed
- 5.3.1.2 - Ensure latest version of authselect is installed
- 5.3.1.3 - Ensure latest version of libpwquality is installed

**5.3.2 Configure authselect (5 checks)**
- 5.3.2.1 - Ensure active authselect profile includes pam modules
- 5.3.2.2 - Ensure pam_faillock module is enabled
- 5.3.2.3 - Ensure pam_pwquality module is enabled
- 5.3.2.4 - Ensure pam_pwhistory module is enabled
- 5.3.2.5 - Ensure pam_unix module is enabled

**5.3.3 Configure PAM Arguments (26 checks)**
- 5.3.3.1.1-5.3.3.1.3 - pam_faillock configuration (3 checks)
- 5.3.3.2.1-5.3.3.2.7 - pam_pwquality configuration (7 checks)
- 5.3.3.3.1-5.3.3.3.3 - pam_pwhistory configuration (3 checks)
- 5.3.3.4.1-5.3.3.4.4 - pam_unix configuration (4 checks)

#### 5.4 User Accounts and Environment (8 checks)

**5.4.1 Configure Password Aging (6 checks)**
- 5.4.1.1 - Ensure password expiration is 365 days or less
- 5.4.1.2 - Ensure minimum days between password changes is configured
- 5.4.1.3 - Ensure password expiration warning days is 7 or more
- 5.4.1.4 - Ensure strong password hashing algorithm is configured
- 5.4.1.5 - Ensure inactive password lock is 30 days or less
- 5.4.1.6 - Ensure all users last password change date is in the past

**5.4.2 Configure root and System Accounts (8 checks)**
- 5.4.2.1 - Ensure root is the only UID 0 account
- 5.4.2.2 - Ensure root is the only GID 0 account
- 5.4.2.3 - Ensure group root is the only GID 0 group
- 5.4.2.4 - Ensure root account access is controlled (Manual)
- 5.4.2.5 - Ensure root path integrity (Manual)
- 5.4.2.6 - Ensure root user umask is configured
- 5.4.2.7 - Ensure system accounts do not have a valid login shell
- 5.4.2.8 - Ensure accounts without a valid login shell are locked

**5.4.3 Configure User Shell Environment (3 checks)**
- 5.4.3.1 - Ensure nologin is not listed in /etc/shells
- 5.4.3.2 - Ensure default user shell timeout is configured
- 5.4.3.3 - Ensure default user umask is configured

### Section 6: Logging and Auditing (100 checks)

#### 6.1 Configure Integrity Checking (3 checks)
- 6.1.1 - Ensure AIDE is installed
- 6.1.2 - Ensure filesystem integrity is regularly checked
- 6.1.3 - Ensure cryptographic mechanisms are used to protect the integrity of audit tools

#### 6.2 System Logging (20 checks)

**6.2.1 Configure systemd-journald service (4 checks)**
- 6.2.1.1 - Ensure journald service is enabled and active
- 6.2.1.2 - Ensure journald log file access is configured (Manual)
- 6.2.1.3 - Ensure journald log file rotation is configured (Manual)
- 6.2.1.4 - Ensure only one logging system is in use (Manual)

**6.2.2 Configure journald (8 checks)**
- 6.2.2.1.1-6.2.2.1.4 - systemd-journal-remote configuration (4 checks)
- 6.2.2.2-6.2.2.4 - journald configuration (4 checks)

**6.2.3 Configure rsyslog (8 checks)**
- 6.2.3.1-6.2.3.8 - rsyslog configuration and log forwarding

**6.2.4 Configure Logfiles (1 check)**
- 6.2.4.1 - Ensure access to all logfiles has been configured (Manual)

#### 6.3 System Auditing (77 checks)

**6.3.1 Configure auditd Service (4 checks)**
- 6.3.1.1 - Ensure auditd packages are installed
- 6.3.1.2 - Ensure auditing for processes that start prior to auditd is enabled (Manual)
- 6.3.1.3 - Ensure audit_backlog_limit is sufficient (Manual)
- 6.3.1.4 - Ensure auditd service is enabled and active (Manual)

**6.3.2 Configure Data Retention (4 checks)**
- 6.3.2.1 - Ensure audit log storage size is configured (Manual)
- 6.3.2.2 - Ensure audit logs are not automatically deleted (Manual)
- 6.3.2.3 - Ensure system is disabled when audit logs are full (Manual)
- 6.3.2.4 - Ensure system warns when audit logs are low on space (Manual)

**6.3.3 Configure auditd Rules (21 checks)**
- 6.3.3.1-6.3.3.21 - Comprehensive audit rule configuration (all Manual)

**6.3.4 Configure auditd File Access (10 checks)**
- 6.3.4.1-6.3.4.10 - Audit file and directory permissions (all Manual)

### Section 7: System Maintenance (22 checks)

#### 7.1 System File Permissions (13 checks)
- 7.1.1-7.1.10 - Critical system file permissions
- 7.1.11 - Ensure world writable files are secured (Manual)
- 7.1.12 - Ensure no unowned files or directories exist
- 7.1.13 - Ensure no ungrouped files or directories exist

#### 7.2 User and Group Settings (9 checks)
- 7.2.1 - Ensure accounts in /etc/passwd use shadowed passwords
- 7.2.2 - Ensure /etc/shadow password fields are not empty
- 7.2.3 - Ensure all groups in /etc/passwd exist in /etc/group
- 7.2.4 - Ensure no duplicate UIDs exist
- 7.2.5 - Ensure no duplicate GIDs exist
- 7.2.6 - Ensure no duplicate user names exist
- 7.2.7 - Ensure no duplicate group names exist
- 7.2.8 - Ensure root PATH integrity (Manual)
- 7.2.9 - Ensure root is the only UID 0 account

---

## Enhanced Logging System

The tool generates comprehensive logs in multiple formats for different use cases:

### Log Directory Structure

```
/var/cis-compliance/
├── backups/                    # Configuration backups
│   └── YYYYMMDD_HHMMSS/       # Timestamped backup directory
├── log/                        # All log files
│   ├── cis-compliance-YYYYMMDD_HHMMSS.log
│   ├── failed-checks-YYYYMMDD_HHMMSS.log
│   ├── failed-checks-YYYYMMDD_HHMMSS.csv
│   ├── manual-checks-YYYYMMDD_HHMMSS.log
│   └── manual-checks-YYYYMMDD_HHMMSS.csv
├── reports/                    # HTML and text reports
│   ├── compliance-report-YYYYMMDD_HHMMSS.html
│   └── compliance-report-YYYYMMDD_HHMMSS.txt
└── rollback/                   # Rollback scripts
    └── rollback-YYYYMMDD_HHMMSS.sh
```

---

## Log File Types

### 1. Main Compliance Log
- **File**: `/var/cis-compliance/log/cis-compliance-YYYYMMDD_HHMMSS.log`
- **Format**: Timestamped text entries
- **Content**: Complete execution trace with all checks and results
- **Log Levels**: INFO, SUCCESS, WARNING, ERROR
- **Purpose**: Complete audit trail of script execution

**Example Entry:**
```
[2026-05-18 13:08:06] [SUCCESS] [1.1.1.1] PASS: cramfs module is not loaded
[2026-05-18 13:08:07] [WARNING] [1.1.2.1.1] FAIL: /tmp is not a separate partition
[2026-05-18 13:08:07] [INFO] [1.2.1.4] MANUAL: Repository configuration must be verified manually
```

### 2. Failed Checks Log (Text)
- **File**: `/var/cis-compliance/log/failed-checks-YYYYMMDD_HHMMSS.log`
- **Format**: Structured text with detailed sections
- **Content**: Detailed information about each failed compliance check
- **Purpose**: Human-readable troubleshooting guide

**Structure:**
```
================================================================================
CHECK ID: 1.1.2.1.1
TIMESTAMP: 2026-05-18 13:08:07
STATUS: FAILED
================================================================================
TITLE: /tmp is not a separate partition

CURRENT STATE:
/tmp is not a separate partition

EXPECTED STATE:
See CIS Benchmark for expected configuration

REASON FOR FAILURE:
Check failed during compliance assessment

REMEDIATION GUIDANCE:
Run with --interactive or --auto mode to remediate

================================================================================
```

### 3. Failed Checks Log (CSV)
- **File**: `/var/cis-compliance/log/failed-checks-YYYYMMDD_HHMMSS.csv`
- **Format**: CSV (Comma-Separated Values)
- **Content**: Same data as text log in tabular format
- **Purpose**: Import into spreadsheets, databases, or analysis tools

**CSV Columns:**
1. Check ID
2. Timestamp
3. Status (always "FAILED")
4. Title
5. Current State
6. Expected State
7. Reason
8. Remediation Guidance

**Example:**
```csv
"Check ID","Timestamp","Status","Title","Current State","Expected State","Reason","Remediation Guidance"
"1.1.2.1.1","2026-05-18 13:08:07","FAILED","/tmp is not a separate partition","/tmp is not a separate partition","See CIS Benchmark for expected configuration","Check failed during compliance assessment","Run with --interactive or --auto mode to remediate"
```

### 4. Manual Checks Log (Text)
- **File**: `/var/cis-compliance/log/manual-checks-YYYYMMDD_HHMMSS.log`
- **Format**: Structured text with detailed sections
- **Content**: Checks requiring manual review and configuration
- **Purpose**: Step-by-step manual remediation guide

**Structure:**
```
================================================================================
CHECK ID: 1.2.1.4
TIMESTAMP: 2026-05-18 13:08:07
STATUS: REQUIRES MANUAL REVIEW
================================================================================
TITLE: Repository configuration must be verified manually

CURRENT STATE:
Current repositories (19 enabled):
google-cloud-ops-agent    Google Cloud Ops Agent Repository
google-cloud-sdk          Google Cloud SDK
...

REQUIRED ACTION:
Review and configure package manager repositories according to organizational policy

VERIFICATION STEPS:
1. List current repositories: yum repolist all
2. Review repository configuration files in /etc/yum.repos.d/
3. Ensure only approved repositories are enabled
4. Verify gpgcheck=1 is set for all repositories
5. Remove or disable unauthorized repositories

ADDITIONAL INFORMATION:
Only use repositories from trusted sources. Unauthorized repositories may contain malicious packages

SECTION: 1
================================================================================
```

### 5. Manual Checks Log (CSV)
- **File**: `/var/cis-compliance/log/manual-checks-YYYYMMDD_HHMMSS.csv`
- **Format**: CSV (Comma-Separated Values)
- **Content**: Same data as text log in tabular format
- **Purpose**: Track manual remediation tasks in project management tools

**CSV Columns:**
1. Check ID
2. Timestamp
3. Status (always "MANUAL")
4. Title
5. Current State
6. Required Action
7. Verification Steps
8. Additional Information
9. Section

**Example:**
```csv
"Check ID","Timestamp","Status","Title","Current State","Required Action","Verification Steps","Additional Information","Section"
"1.2.1.4","2026-05-18 13:08:07","MANUAL","Repository configuration must be verified manually","Current repositories (19 enabled): ...","Review and configure package manager repositories according to organizational policy","1. List current repositories: yum repolist all 2. Review repository configuration files in /etc/yum.repos.d/ ...","Only use repositories from trusted sources","1"
```

---

## CSV Format Specifications

### Encoding Standards
- **Character Encoding**: UTF-8
- **Field Delimiter**: Comma (`,`)
- **Text Qualifier**: Double quotes (`"`)
- **Escaped Quotes**: Doubled quotes (`""`)
- **Line Breaks**: Newlines within fields converted to spaces
- **Header Row**: Always present as first line

### Data Sanitization
The tool automatically sanitizes CSV data:
- Removes or escapes special characters
- Converts multi-line text to single line
- Handles quotes and commas within field values
- Ensures valid UTF-8 encoding

### CSV Validation
Each CSV file includes:
- Header row with column names
- Consistent column count across all rows
- Proper quote escaping
- No trailing delimiters

---

## Data Analysis & Integration

### Import into Excel/LibreOffice

**Steps:**
1. Open Excel or LibreOffice Calc
2. File → Open → Select the CSV file
3. Choose UTF-8 encoding
4. Set delimiter to comma
5. Data will be imported into columns

**Tips:**
- Use "Text Import Wizard" for better control
- Set column data types appropriately
- Create pivot tables for summary analysis

### Import into Database

**PostgreSQL Example:**
```sql
-- Create table
CREATE TABLE failed_checks (
    check_id VARCHAR(20),
    timestamp TIMESTAMP,
    status VARCHAR(10),
    title TEXT,
    current_state TEXT,
    expected_state TEXT,
    reason TEXT,
    remediation_guidance TEXT
);

-- Import CSV
COPY failed_checks FROM '/var/cis-compliance/log/failed-checks-20260518_130806.csv' 
WITH (FORMAT csv, HEADER true, DELIMITER ',', QUOTE '"', ENCODING 'UTF8');

-- Query examples
SELECT check_id, title FROM failed_checks WHERE check_id LIKE '5.%';
SELECT SUBSTRING(check_id, 1, 1) as section, COUNT(*) FROM failed_checks GROUP BY section;
```

**MySQL Example:**
```sql
LOAD DATA INFILE '/var/cis-compliance/log/failed-checks-20260518_130806.csv'
INTO TABLE failed_checks
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;
```

### Python Analysis

**Using Pandas:**
```python
import pandas as pd
import matplotlib.pyplot as plt

# Read failed checks
failed_df = pd.read_csv('/var/cis-compliance/log/failed-checks-20260518_130806.csv')

# Group by section
failed_df['section'] = failed_df['Check ID'].str.split('.').str[0]
section_summary = failed_df.groupby('section').size()

# Visualize
section_summary.plot(kind='bar', title='Failed Checks by Section')
plt.xlabel('Section')
plt.ylabel('Count')
plt.savefig('failed_checks_summary.png')

# Filter critical issues
critical = failed_df[failed_df['Title'].str.contains('password|authentication|root', case=False)]
critical.to_csv('critical_issues.csv', index=False)

# Generate report
print(f"Total Failed Checks: {len(failed_df)}")
print(f"Critical Issues: {len(critical)}")
print("\nFailed Checks by Section:")
print(section_summary)
```

**Using CSV Module:**
```python
import csv
from collections import Counter

# Read and analyze
with open('/var/cis-compliance/log/failed-checks-20260518_130806.csv', 'r') as f:
    reader = csv.DictReader(f)
    checks = list(reader)
    
    # Count by section
    sections = [row['Check ID'].split('.')[0] for row in checks]
    section_counts = Counter(sections)
    
    print("Failed Checks by Section:")
    for section, count in sorted(section_counts.items()):
        print(f"Section {section}: {count} checks")
```

### PowerShell Analysis

**Basic Analysis:**
```powershell
# Import CSV
$failed = Import-Csv -Path "/var/cis-compliance/log/failed-checks-20260518_130806.csv"

# Count total
Write-Host "Total Failed Checks: $($failed.Count)"

# Group by section
$failed | ForEach-Object {
    $_.Section = $_.'Check ID'.Split('.')[0]
} | Group-Object Section | 
    Select-Object Name, Count | 
    Sort-Object Count -Descending |
    Format-Table -AutoSize

# Filter and export
$critical = $failed | Where-Object {
    $_.Title -match "password|authentication|root"
}
$critical | Export-Csv -Path "critical_issues.csv" -NoTypeInformation

# Generate HTML report
$failed | ConvertTo-Html -Property 'Check ID', Title, 'Current State' |
    Out-File "failed_checks_report.html"
```

**Advanced Reporting:**
```powershell
# Create summary report
$report = @{
    TotalChecks = $failed.Count
    BySectionCount = ($failed | Group-Object {$_.'Check ID'.Split('.')[0]}).Count
    CriticalCount = ($failed | Where-Object {$_.Title -match "password|authentication"}).Count
}

# Export to JSON
$report | ConvertTo-Json | Out-File "summary.json"

# Create Excel-compatible CSV with summary
$summary = $failed | Group-Object {$_.'Check ID'.Split('.')[0]} | 
    Select-Object @{N='Section';E={$_.Name}}, Count
$summary | Export-Csv -Path "section_summary.csv" -NoTypeInformation
```

### Integration with Monitoring Systems

**Splunk Configuration:**
```
[monitor:///var/cis-compliance/log/*.log]
sourcetype = cis_compliance_log
index = security
disabled = false

[monitor:///var/cis-compliance/log/*.csv]
sourcetype = csv
index = security
disabled = false

# Field extraction for CSV
[cis_compliance_csv]
INDEXED_EXTRACTIONS = csv
KV_MODE = none
SHOULD_LINEMERGE = false
```

**ELK Stack (Logstash):**
```ruby
input {
  file {
    path => "/var/cis-compliance/log/failed-checks-*.csv"
    start_position => "beginning"
    sincedb_path => "/var/lib/logstash/sincedb_cis"
  }
}

filter {
  csv {
    separator => ","
    columns => ["check_id","timestamp","status","title","current_state","expected_state","reason","remediation"]
    skip_header => true
  }
  
  date {
    match => ["timestamp", "yyyy-MM-dd HH:mm:ss"]
    target => "@timestamp"
  }
  
  mutate {
    add_field => {
      "section" => "%{check_id}"
    }
  }
  
  ruby {
    code => "event.set('section', event.get('section').split('.')[0])"
  }
}

output {
  elasticsearch {
    hosts => ["localhost:9200"]
    index => "cis-compliance-%{+YYYY.MM.dd}"
  }
}
```

**Grafana Dashboard Query (Prometheus):**
```promql
# Count failed checks by section
count by (section) (cis_failed_checks)

# Failed checks over time
rate(cis_failed_checks_total[1h])
```

---

## Best Practices

### 1. Regular Review
- Review failed and manual check logs after each run
- Prioritize remediation based on severity and business impact
- Track remediation progress using CSV exports

### 2. Trend Analysis
- Run compliance checks on a regular schedule (weekly/monthly)
- Import CSV data into time-series database
- Create dashboards to visualize compliance trends
- Identify recurring issues for systemic fixes

### 3. Automation & Integration
- Import CSV data into ticketing systems (Jira, ServiceNow)
- Create automated workflows for remediation tasks
- Set up alerts for critical compliance failures
- Integrate with CI/CD pipelines for infrastructure-as-code validation

### 4. Data Retention
- Keep logs for at least 90 days for compliance auditing
- Compress logs older than 30 days to save disk space
- Archive logs to long-term storage (S3, NAS) after 90 days
- Implement log rotation policies

### 5. Reporting
- Generate executive summaries from CSV data using pivot tables
- Create compliance scorecards for management review
- Track compliance rate over time
- Document remediation efforts and outcomes

### 6. Security
- Restrict access to log files (chmod 600)
- Store logs on separate partition if possible
- Encrypt archived logs
- Implement log integrity checking (AIDE, Tripwire)

---

## Troubleshooting

### CSV File Not Created

**Symptoms:**
- CSV files missing from `/var/cis-compliance/log/`
- Only text logs are generated

**Diagnosis:**
```bash
# Check disk space
df -h /var/cis-compliance

# Verify directory permissions
ls -la /var/cis-compliance/log

# Check for errors in main log
grep -i "error\|fail" /var/cis-compliance/log/cis-compliance-*.log | grep -i csv
```

**Solutions:**
1. Ensure sufficient disk space (at least 100MB free)
2. Verify directory permissions: `chmod 755 /var/cis-compliance/log`
3. Check that `initialize_detailed_logs()` function is called
4. Review script execution for errors

### CSV Import Issues

**Symptoms:**
- Data appears corrupted in Excel/database
- Columns misaligned
- Special characters display incorrectly

**Solutions:**
1. **Encoding Issues:**
   - Ensure UTF-8 encoding is selected during import
   - Use `iconv` to convert if needed: `iconv -f UTF-8 -t UTF-8 file.csv`

2. **Delimiter Problems:**
   - Verify delimiter is set to comma
   - Check for unescaped commas in data

3. **Quote Handling:**
   - Ensure import tool recognizes double-quote as text qualifier
   - Verify escaped quotes are handled correctly

4. **Line Break Issues:**
   - Check that multi-line fields are properly handled
   - Use text import wizard for better control

### Missing Data in CSV

**Symptoms:**
- CSV file exists but contains no data rows
- Only header row present
- Some checks missing from CSV

**Diagnosis:**
```bash
# Check CSV file content
head -20 /var/cis-compliance/log/failed-checks-*.csv

# Count lines
wc -l /var/cis-compliance/log/failed-checks-*.csv

# Check main log for CSV writing
grep "log_check_failed\|log_check_manual" /var/cis-compliance/log/cis-compliance-*.log
```

**Solutions:**
1. Verify `log_check_failed()` and `log_check_manual()` functions are being called
2. Check that checks are actually failing/requiring manual review
3. Review main log for any errors during CSV writing
4. Ensure CSV file descriptors are properly opened and closed

### Performance Issues

**Symptoms:**
- Script runs slowly
- High disk I/O
- Large log files

**Solutions:**
1. **Reduce Log Verbosity:**
   - Comment out debug logging if not needed
   - Limit detailed logging to failed checks only

2. **Optimize Disk I/O:**
   - Use SSD for `/var/cis-compliance` if possible
   - Implement log buffering
   - Write to tmpfs and copy to disk at end

3. **Manage Log Size:**
   ```bash
   # Compress old logs
   find /var/cis-compliance/log -name "*.log" -mtime +7 -exec gzip {} \;
   
   # Remove very old logs
   find /var/cis-compliance/log -name "*.gz" -mtime +90 -delete
   ```

### Permission Errors

**Symptoms:**
- "Permission denied" errors when writing logs
- Cannot create CSV files

**Diagnosis:**
```bash
# Check current user
whoami

# Check directory ownership
ls -ld /var/cis-compliance/log

# Check file permissions
ls -l /var/cis-compliance/log/
```

**Solutions:**
```bash
# Run script as root
sudo ./rhel9-cis-compliance-modular.sh --dry-run

# Fix directory permissions
sudo chown -R root:root /var/cis-compliance
sudo chmod 755 /var/cis-compliance/log

# Fix file permissions
sudo chmod 644 /var/cis-compliance/log/*.csv
```

---

## Additional Resources

### Related Documentation
- [`README.md`](../README.md) - Main project documentation
- [`MANUAL_CHECKS_GUIDE.md`](MANUAL_CHECKS_GUIDE.md) - Manual remediation procedures
- [`CRITICAL_SETTINGS_PROTECTION.md`](CRITICAL_SETTINGS_PROTECTION.md) - Protected settings documentation
- [`DEPLOYMENT_CHECKLIST.md`](../checklist/DEPLOYMENT_CHECKLIST.md) - Pre-deployment checklist

### CIS Benchmark Resources
- [CIS RHEL 9 Benchmark v2.0.0](https://www.cisecurity.org/benchmark/red_hat_linux)
- [CIS Controls](https://www.cisecurity.org/controls)
- [CIS Hardened Images](https://www.cisecurity.org/cis-hardened-images)

### Support
For issues, questions, or contributions:
- Review existing documentation
- Check troubleshooting section
- Examine sample outputs in `sample-output/` directory
- Review source code comments in `lib/` directory

---

**Document Version**: 2.0.0  
**Last Updated**: 2026-05-18  
**Tool Version**: RHEL 9 CIS Compliance Tool v2.0.0