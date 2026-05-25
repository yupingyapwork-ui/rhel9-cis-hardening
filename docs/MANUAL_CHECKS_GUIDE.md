# Manual Checks Guide

## Overview

The RHEL 9 CIS Compliance Tool automatically remediates most checks, but some require manual intervention. This guide explains how to identify and address manual checks.

## How to Identify Manual Checks

### 1. During Script Execution

Manual checks are clearly marked with **[WARNING] MANUAL:** prefix:

```bash
sudo ./rhel9-cis-compliance-modular.sh --dry-run

# Output will show:
[WARNING] [1.2.1.1] MANUAL: GPG keys need to be configured manually
[WARNING] [1.2.1.3] MANUAL: repo_gpgcheck must be configured manually
[WARNING] [1.4.1] MANUAL: Bootloader password must be set manually using grub2-setpassword
```

### 2. In the Summary Report

After execution, the summary shows the count:

```
===============================================================================
CIS BENCHMARK COMPLIANCE ASSESSMENT SUMMARY
===============================================================================
Total Checks:           400
Passed Checks:          250
Failed Checks:          150
Remediated Checks:      120
Manual Review Required: 30
===============================================================================
```

### 3. In the Log File

Search the log file for all manual checks:

```bash
# View all manual checks
grep "MANUAL:" /var/cis-compliance/log/cis-compliance-*.log

# Count manual checks
grep -c "MANUAL:" /var/cis-compliance/log/cis-compliance-*.log

# View manual checks with context
grep -B2 -A2 "MANUAL:" /var/cis-compliance/log/cis-compliance-*.log
```

### 4. In the HTML Report

Open the HTML report in a browser:

```bash
firefox /var/cis-compliance/reports/compliance-report-*.html
```

Manual checks are highlighted in **orange/yellow** with "Manual Review Required" label.

### 5. In the Text Report

```bash
cat /var/cis-compliance/reports/compliance-report-*.txt | grep -A5 "Manual Review"
```

## Common Manual Checks

### Section 1.2: Software Updates

**1.2.1.1 - GPG Keys Configuration**
- **Why Manual:** GPG keys are organization-specific
- **Action Required:**
  ```bash
  # Import your organization's GPG keys
  rpm --import /path/to/your/gpg-key
  ```

**1.2.1.3 - repo_gpgcheck Configuration**
- **Why Manual:** Requires verification of repository configuration
- **Action Required:**
  ```bash
  # Edit each repo file
  vi /etc/yum.repos.d/*.repo
  # Add: repo_gpgcheck=1
  ```

**1.2.1.4 - Repository Configuration**
- **Why Manual:** Organization-specific repositories
- **Action Required:** Verify all repositories are authorized

**1.2.2.1 - System Updates**
- **Why Manual:** Updates should be tested before applying
- **Action Required:**
  ```bash
  # Review available updates
  dnf check-update

  # Apply updates in maintenance window
  dnf update -y
  ```

### Section 1.4: Secure Boot

**1.4.1 - Bootloader Password**
- **Why Manual:** Password must be set securely
- **Action Required:**
  ```bash
  # Set GRUB2 password
  grub2-setpassword
  # Enter password when prompted

  # Verify
  grep "^GRUB2_PASSWORD" /boot/grub2/user.cfg
  ```

### Section 1.1.2: Partition Configuration

**1.1.2.x.1 - Separate Partitions**
- **Why Manual:** Cannot create partitions on running system
- **Action Required:**
  - Requires system reinstall or repartitioning
  - Plan during initial OS installation
  - Use LVM for flexibility

### Section 1.3: SELinux

**1.3.1.6 - Unconfined Services**
- **Why Manual:** Requires service-specific analysis
- **Action Required:**
  ```bash
  # List unconfined services
  ps -eZ | grep unconfined_service_t

  # Create custom policies as needed
  audit2allow -a -M custom_policy
  semodule -i custom_policy.pp
  ```

### Section 1.8: GNOME Display Manager

**1.8.x - GDM Configuration**
- **Why Manual:** Only applies if GUI is installed
- **Action Required:** Configure GDM settings if GUI is present

### Section 2.1.22: Network Services

**2.1.22 - Approved Services**
- **Why Manual:** Organization-specific service requirements
- **Action Required:**
  ```bash
  # List all listening services
  ss -tulpn

  # Disable unauthorized services
  systemctl disable <service-name>
  ```

### Section 4: Firewall

**4.2.1 - Firewall Services and Ports**
- **Why Manual:** Application-specific requirements
- **Action Required:**
  ```bash
  # Review current rules
  firewall-cmd --list-all

  # Remove unnecessary services
  firewall-cmd --permanent --remove-service=<service>
  firewall-cmd --reload
  ```

### Section 5: Access Control (71 checks)

**Section 5 Overview:**
Section 5 contains 71 checks covering SSH configuration, privilege escalation, PAM, and user account security. Most checks are automated, but some require site-specific policy decisions.

**5.1 - Configure SSH Server (22 checks)**
- **5.1.1-5.1.6:** Automated - SSH file permissions and cryptographic algorithms
- **5.1.7:** Manual - SSH access lists (AllowUsers, AllowGroups, DenyUsers, DenyGroups)
- **5.1.8-5.1.22:** Automated - SSH daemon configuration with site-policy defaults

**5.2 - Configure Privilege Escalation (7 checks)**
- **5.2.1-5.2.7:** Automated - sudo installation and configuration, su command restriction

**5.3 - Pluggable Authentication Modules (34 checks)**
- **5.3.1.1-5.3.1.3:** Automated - PAM package installation/updates
- **5.3.2.1-5.3.2.5:** Automated - authselect profile and PAM module verification
- **5.3.3.1.1-5.3.3.1.3:** Automated - Password lockout configuration
- **5.3.3.2.1-5.3.3.2.2:** Automated - Password length and character changes
- **5.3.3.2.3:** Manual - Password complexity (minclass or credit settings)
- **5.3.3.2.4-5.3.3.4.4:** Automated - Password quality and PAM unix configuration

**5.4 - User Accounts and Environment (8 checks)**
- **5.4.1.1-5.4.1.6:** Automated - Password aging, expiration, and hashing
- **5.4.2.1-5.4.2.3:** Automated - Root and system account UID/GID verification
- **5.4.2.4:** Manual - Root account access control
- **5.4.2.5:** Manual - Root PATH integrity
- **5.4.2.6-5.4.3.3:** Automated - User umask, shell, and timeout configuration

**Action Required for Manual Checks:**
```bash
# 5.1.7 - Configure SSH access lists
vi /etc/ssh/sshd_config.d/00-cis-hardening.conf
# Add: AllowUsers user1 user2
# Or: AllowGroups sshusers

# 5.3.3.2.3 - Configure password complexity
vi /etc/security/pwquality.conf.d/50-cis.conf
# Option 1: minclass = 4
# Option 2: dcredit = -1, ucredit = -1, lcredit = -1, ocredit = -1

# 5.4.2.4 - Verify root account access
passwd -S root  # Check if locked or has password

# 5.4.2.5 - Review root PATH
echo $PATH
# Verify all directories exist, are owned by root, and not world-writable
```

### Section 6: Logging and Auditing

**Section 6 Overview:**
Section 6 contains 100 checks covering logging and auditing. Most require site-specific configuration based on organizational security policies.

**6.1 - Configure Integrity Checking (3 checks)**
- **6.1.1-6.1.3:** Automated - AIDE installation, scheduling, and audit tool integrity monitoring

**6.2 - System Logging (20 checks)**
- **6.2.1.1:** Automated - journald service enabled/active
- **6.2.1.2-6.2.4.1:** Manual - journald and rsyslog configuration per site policy

**6.3 - System Auditing (77 checks)**
- **6.3.1.1:** Automated - auditd packages installed
- **6.3.1.2-6.3.4.10:** Manual - auditd service, retention, rules, and file permissions per site policy

**Action Required:**
```bash
# Configure journald
vi /etc/systemd/journald.conf

# Configure rsyslog
vi /etc/rsyslog.conf

# Configure audit rules
vi /etc/audit/rules.d/50-cis.rules

# Configure audit retention
vi /etc/audit/auditd.conf
```

### Section 7.1.13: SUID/SGID Files

**7.1.13 - SUID and SGID Files Review**
- **Why Manual:** Requires security review
- **Action Required:**
  ```bash
  # Find all SUID files
  find / -perm /4000 -type f 2>/dev/null

  # Find all SGID files
  find / -perm /2000 -type f 2>/dev/null

  # Review each file and remove SUID/SGID if not needed
  chmod u-s /path/to/file  # Remove SUID
  chmod g-s /path/to/file  # Remove SGID
  ```

## Workflow for Handling Manual Checks

### Step 1: Run Initial Assessment

```bash
sudo ./rhel9-cis-compliance-modular.sh --dry-run
```

### Step 2: Extract Manual Checks List

```bash
# Create a list of all manual checks
grep "MANUAL:" /var/cis-compliance/log/cis-compliance-*.log > manual-checks.txt

# Review the list
cat manual-checks.txt
```

### Step 3: Prioritize Manual Checks

Categorize by priority:
- **Critical:** Bootloader password, GPG keys, system updates
- **High:** Firewall rules, service configuration
- **Medium:** Logging configuration, file permissions review
- **Low:** Documentation, policy reviews

### Step 4: Address Each Manual Check

Create a tracking spreadsheet:

| Check ID | Description | Priority | Status | Notes |
|----------|-------------|----------|--------|-------|
| 1.2.1.1 | GPG Keys | Critical | ✅ Done | Keys imported |
| 1.4.1 | Bootloader Password | Critical | ✅ Done | Password set |
| 2.1.22 | Approved Services | High | 🔄 In Progress | Reviewing |

### Step 5: Re-run Assessment

After addressing manual checks:

```bash
sudo ./rhel9-cis-compliance-modular.sh --dry-run
```

Verify the manual checks count decreases.

## Automation Tips

### Create a Manual Checks Report

```bash
#!/bin/bash
# generate-manual-report.sh

LOG_FILE=$(ls -t /var/cis-compliance/log/cis-compliance-*.log | head -1)

echo "Manual Checks Report"
echo "===================="
echo "Generated: $(date)"
echo ""
echo "Manual Checks Found:"
grep "MANUAL:" "$LOG_FILE" | while read line; do
    echo "  - $line"
done

echo ""
echo "Total Manual Checks: $(grep -c "MANUAL:" "$LOG_FILE")"
```

### Track Manual Check Progress

```bash
#!/bin/bash
# track-manual-progress.sh

BASELINE_COUNT=30  # Initial manual checks count

CURRENT_LOG=$(ls -t /var/cis-compliance/log/cis-compliance-*.log | head -1)
CURRENT_COUNT=$(grep -c "MANUAL:" "$CURRENT_LOG")

echo "Manual Checks Progress"
echo "====================="
echo "Baseline:  $BASELINE_COUNT"
echo "Current:   $CURRENT_COUNT"
echo "Completed: $((BASELINE_COUNT - CURRENT_COUNT))"
echo "Remaining: $CURRENT_COUNT"
echo "Progress:  $(( (BASELINE_COUNT - CURRENT_COUNT) * 100 / BASELINE_COUNT ))%"
```

## Best Practices

### 1. Document All Manual Actions

Create a log of manual interventions:

```bash
# manual-actions.log
2026-05-15 10:00 - Set GRUB2 password (Check 1.4.1)
2026-05-15 10:15 - Imported GPG keys (Check 1.2.1.1)
2026-05-15 10:30 - Configured firewall rules (Check 4.2.1)
```

### 2. Schedule Regular Reviews

```bash
# Add to crontab for monthly manual check review
0 9 1 * * /root/generate-manual-report.sh | mail -s "Monthly Manual Checks Review" admin@example.com
```

### 3. Create Organization-Specific Procedures

Document your organization's procedures for each manual check:

```
Manual Check Procedures - Organization XYZ
==========================================

1.2.1.1 - GPG Keys
  - Contact: security-team@xyz.com
  - Keys Location: /secure/gpg-keys/
  - Import Command: rpm --import /secure/gpg-keys/xyz-key.gpg

1.4.1 - Bootloader Password
  - Contact: infrastructure-team@xyz.com
  - Password Policy: 16+ characters, stored in vault
  - Procedure: Use grub2-setpassword, document in vault
```

### 4. Integrate with Change Management

- Create change tickets for manual checks
- Track completion in your ITSM system
- Require approval for critical manual changes

## Summary

Manual checks are an essential part of CIS compliance. The script clearly identifies them with:

- ✅ **[WARNING] MANUAL:** prefix in output
- ✅ Count in summary report
- ✅ Searchable in log files
- ✅ Highlighted in HTML reports
- ✅ Listed in text reports

**Key Takeaway:** Manual checks require human judgment and organization-specific decisions. The script identifies them clearly so you can address them systematically.

---

**For Questions:**
- Review the log file: `/var/cis-compliance/log/cis-compliance-*.log`
- Check the HTML report: `/var/cis-compliance/reports/compliance-report-*.html`
- Consult the CIS Benchmark PDF for detailed requirements
