# Security Policy

> **Last Updated:** 20 October 2025
> **Contact:** security@example.com

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.x.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Please do NOT report security vulnerabilities via public GitHub issues.**

### How to Report

1. **Email:** security@example.com
2. **Subject:** `[SECURITY] Brief description`
3. **Include:**
   - Description of the vulnerability
   - Steps to reproduce
   - Affected versions
   - Potential impact
   - Suggested fix (if any)

### Response Timeline

- **Acknowledgment:** Within 48 hours
- **Initial Assessment:** Within 5 business days
- **Fix & Disclosure:** Coordinated with reporter

## Security Measures

### Current Baseline

- [ ] Image signing (Cosign)
- [ ] SBOM generation (Syft/Trivy)
- [ ] Vulnerability scanning (Trivy)
- [ ] Pod Security Standards (PSA restricted)
- [ ] Network Policies (default-deny)
- [ ] Secrets encryption at rest
- [ ] RBAC least-privilege
- [ ] Audit logging enabled

### Threat Model

See `docs/architecture/ARCHITECTURE.md` §30 for detailed threat model (STRIDE).

## Security Best Practices

1. **Never commit secrets** to Git
2. **Pin image digests** (not `:latest`)
3. **Sign all images** with Cosign
4. **Scan images** before deployment
5. **Rotate credentials** every 90 days
6. **Review RBAC** quarterly
7. **Enable audit logs** in production
8. **Test backups** monthly

## Disclosure Policy

- Vulnerabilities are disclosed **after** a fix is available
- **30-day embargo** period for critical issues
- Public disclosure via GitHub Security Advisory

## Hall of Fame

Contributors who responsibly disclose vulnerabilities will be acknowledged here (with permission).

---

**Thank you for keeping this project secure!** 🔒
