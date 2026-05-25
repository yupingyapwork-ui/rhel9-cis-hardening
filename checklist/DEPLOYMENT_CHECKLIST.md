# RHEL 9 CIS Compliance Tool - Deployment Checklist

## Pre-Deployment Checklist

### System Preparation
- [ ] Verify RHEL 9 operating system
  ```bash
  cat /etc/redhat-release
  ```
- [ ] Confirm root access available
  ```bash
  sudo -i
  ```
- [ ] Check available disk space (minimum 1GB in /var)
  ```bash
  df -h /var
  ```
- [ ] Create full system backup
  ```bash
  tar -czf /backup/system-$(date +%Y%m%d).tar.gz /etc /var/lib
  ```
- [ ] Document current system state
  ```bash
  systemctl list-units --state=running > /backup/services-before.txt
  ```

### Script Preparation
- [ ] Copy script to target system
  ```bash
  scp rhel9-cis-compliance-modular.sh root@target-server:/root/
  ```
- [ ] Verify script integrity (optional)
  ```bash
  sha256sum rhel9-cis-compliance-modular.sh
  ```
- [ ] Make script executable
  ```bash
  chmod +x /root/rhel9-cis-compliance-modular.sh
  ```
- [ ] Copy documentation files
  ```bash
  scp README.md docs/*.md checklist/*.md root@target-server:/root/
  ```

### Testing Environment
- [ ] Set up test VM or container
- [ ] Clone production configuration
- [ ] Verify test environment matches production
- [ ] Document test environment details

## Initial Assessment Checklist

### Dry-Run Assessment
- [ ] Run initial dry-run assessment
  ```bash
  ./rhel9-cis-compliance-modular.sh --dry-run
  ```
- [ ] Review generated reports
  ```bash
  cat /var/cis-compliance/reports/compliance-report-*.txt
  ```
- [ ] Review detailed log file
  ```bash
  less /var/cis-compliance/log/cis-compliance-*.log
  ```
- [ ] Document baseline compliance score
  ```bash
  grep "Compliance Rate" /var/cis-compliance/reports/compliance-report-*.txt
  ```
- [ ] Identify manual intervention items
  ```bash
  grep "MANUAL" /var/cis-compliance/log/cis-compliance-*.log
  ```

### Risk Assessment
- [ ] Review all failed checks
- [ ] Identify critical vs. non-critical controls
- [ ] Assess impact on applications
- [ ] Identify potential service disruptions
- [ ] Document dependencies
- [ ] Create rollback plan

## Test Environment Deployment

### Apply Changes in Test
- [ ] Run compliance tool in test environment
  ```bash
  ./rhel9-cis-compliance-modular.sh --interactive
  ```
- [ ] Verify all services start correctly
  ```bash
  systemctl list-units --state=failed
  ```
- [ ] Test critical applications
- [ ] Verify network connectivity
- [ ] Check SSH access
- [ ] Test user authentication
- [ ] Verify logging functionality
- [ ] Check firewall rules

### Test Validation
- [ ] Run post-change assessment
  ```bash
  ./rhel9-cis-compliance-modular.sh --dry-run
  ```
- [ ] Compare before/after compliance scores
- [ ] Document any issues encountered
- [ ] Test rollback procedure
  ```bash
  ./rhel9-cis-compliance-modular.sh --rollback
  ```
- [ ] Verify rollback success
- [ ] Document lessons learned

## Production Deployment Planning

### Change Management
- [ ] Create change request
- [ ] Document scope of changes
- [ ] Identify affected systems
- [ ] Schedule maintenance window
- [ ] Notify stakeholders
- [ ] Prepare communication plan
- [ ] Define success criteria
- [ ] Establish rollback criteria

### Pre-Production Backup
- [ ] Create full system backup
  ```bash
  tar -czf /backup/pre-cis-$(date +%Y%m%d).tar.gz /etc /var/lib /var/log
  ```
- [ ] Verify backup integrity
  ```bash
  tar -tzf /backup/pre-cis-$(date +%Y%m%d).tar.gz | head
  ```
- [ ] Store backup in safe location
- [ ] Document backup location
- [ ] Test backup restoration (in test environment)

### Deployment Preparation
- [ ] Review deployment procedure
- [ ] Prepare rollback script location
- [ ] Set up monitoring
- [ ] Prepare incident response plan
- [ ] Brief operations team
- [ ] Verify emergency contacts
- [ ] Prepare status update templates

## Production Deployment Execution

### Pre-Deployment Verification
- [ ] Verify maintenance window
- [ ] Confirm backup completion
- [ ] Check system health
  ```bash
  uptime
  df -h
  free -h
  ```
- [ ] Verify no critical processes running
- [ ] Document current system state

### Deployment Steps
- [ ] Run final dry-run assessment
  ```bash
  ./rhel9-cis-compliance-modular.sh --dry-run
  ```
- [ ] Review and confirm changes
- [ ] Execute compliance tool
  ```bash
  ./rhel9-cis-compliance-modular.sh --interactive  # or --auto
  ```
- [ ] Monitor execution progress
- [ ] Document any errors or warnings
- [ ] Save rollback script location
  ```bash
  ls -l /var/cis-compliance/rollback/
  ```

### Post-Deployment Verification
- [ ] Verify script completion
- [ ] Check for errors in log
  ```bash
  grep "ERROR" /var/cis-compliance/log/cis-compliance-*.log
  ```
- [ ] Verify all services running
  ```bash
  systemctl list-units --state=failed
  ```
- [ ] Test SSH access
- [ ] Verify network connectivity
- [ ] Test critical applications
- [ ] Check user authentication
- [ ] Verify logging functionality
- [ ] Test firewall rules

### Compliance Verification
- [ ] Run post-deployment assessment
  ```bash
  ./rhel9-cis-compliance-modular.sh --dry-run
  ```
- [ ] Review compliance score improvement
- [ ] Verify remediated controls
- [ ] Document remaining issues
- [ ] Generate final reports
  ```bash
  ./rhel9-cis-compliance-modular.sh --report
  ```

## Post-Deployment Tasks

### System Monitoring
- [ ] Monitor system logs for 24 hours
  ```bash
  journalctl -f
  ```
- [ ] Check for SELinux denials
  ```bash
  ausearch -m avc -ts recent
  ```
- [ ] Monitor application logs
- [ ] Verify audit logging
  ```bash
  tail -f /var/log/audit/audit.log
  ```
- [ ] Check system performance
- [ ] Monitor user feedback

### Documentation
- [ ] Document final compliance score
- [ ] Record all changes made
- [ ] Update system documentation
- [ ] Document any issues encountered
- [ ] Record resolution steps
- [ ] Update runbooks
- [ ] Archive reports and logs

### Stakeholder Communication
- [ ] Send deployment completion notice
- [ ] Report compliance improvements
- [ ] Document any outstanding items
- [ ] Schedule follow-up review
- [ ] Update change request status

## Rollback Procedure (If Needed)

### Rollback Decision Criteria
- [ ] Critical service failure
- [ ] Application malfunction
- [ ] Security incident
- [ ] Performance degradation
- [ ] User access issues

### Rollback Execution
- [ ] Notify stakeholders of rollback
- [ ] Execute rollback script
  ```bash
  ./rhel9-cis-compliance-modular.sh --rollback
  ```
- [ ] Verify service restoration
- [ ] Test critical applications
- [ ] Verify user access
- [ ] Document rollback reason
- [ ] Schedule post-mortem review

## Ongoing Maintenance

### Regular Tasks
- [ ] Schedule weekly compliance checks
  ```bash
  # Add to crontab
  0 2 * * 0 /root/rhel9-cis-compliance-modular.sh --dry-run
  ```
- [ ] Review compliance reports monthly
- [ ] Update documentation quarterly
- [ ] Test rollback procedure annually
- [ ] Review and update script as needed

### Monitoring Setup
- [ ] Configure compliance monitoring
- [ ] Set up alerting for drift
- [ ] Integrate with SIEM
- [ ] Schedule regular audits
- [ ] Document monitoring procedures

### Continuous Improvement
- [ ] Review manual intervention items
- [ ] Automate additional controls
- [ ] Update for new CIS versions
- [ ] Incorporate lessons learned
- [ ] Share best practices

## Sign-Off

### Deployment Team
- [ ] System Administrator: _________________ Date: _______
- [ ] Security Team: _________________ Date: _______
- [ ] Application Owner: _________________ Date: _______
- [ ] Change Manager: _________________ Date: _______

### Verification
- [ ] All checklist items completed
- [ ] Documentation updated
- [ ] Stakeholders notified
- [ ] Monitoring configured
- [ ] Backup verified
- [ ] Rollback tested

## Emergency Contacts

| Role | Name | Contact |
|------|------|---------|
| System Administrator | | |
| Security Team Lead | | |
| Application Owner | | |
| Change Manager | | |
| On-Call Engineer | | |

## Important File Locations

| Item | Location |
|------|----------|
| Compliance Script | `/root/rhel9-cis-compliance-modular.sh` |
| Documentation | `/root/README.md` |
| Logs | `/var/cis-compliance/log/` |
| Reports | `/var/cis-compliance/reports/` |
| Backups | `/var/cis-compliance/backups/` |
| Rollback Scripts | `/var/cis-compliance/rollback/` |
| System Backup | `/backup/` |

## Notes and Comments

```
Date: _______________
Deployment Notes:




Issues Encountered:




Resolutions Applied:




Follow-up Actions:




```

---

**Checklist Version**: 1.0
**Last Updated**: May 13, 2026
**Status**: Ready for Use
