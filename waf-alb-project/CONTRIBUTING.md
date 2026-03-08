# Contributing Guide

Thank you for considering contributing to this project!

## Development Setup

1. Fork the repository
2. Clone your fork
3. Create a feature branch
4. Make your changes
5. Test thoroughly
6. Submit a pull request

## Code Standards

### Terraform

- Use `terraform fmt` before committing
- Run `terraform validate` to check syntax
- Follow HashiCorp's style guide
- Add comments for complex logic
- Use meaningful variable names

### Documentation

- Update README.md for user-facing changes
- Update CHANGELOG.md following Keep a Changelog format
- Add examples for new features
- Include architecture diagrams when relevant

## Testing Requirements

Before submitting a PR:

1. Run validation script:
   ```bash
   bash validate.sh
   ```

2. Test in dev environment:
   ```bash
   terraform plan -var-file="environments/dev/terraform.tfvars"
   ```

3. Verify no breaking changes to existing deployments

4. Update tests if adding new features

## Pull Request Process

1. Update documentation
2. Add entry to CHANGELOG.md
3. Ensure all tests pass
4. Request review from maintainers
5. Address review feedback
6. Squash commits before merge

## Commit Message Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- style: Code style changes (formatting)
- refactor: Code refactoring
- test: Test additions or changes
- chore: Build process or auxiliary tool changes

Example:
```
feat(waf): add XSS protection rule

Add AWS Managed XSS Protection rule set to WAF module
with configurable override action.

Closes #123
```

## Reporting Issues

When reporting issues, include:

- Terraform version
- AWS provider version
- Environment (dev/staging/prod)
- Steps to reproduce
- Expected vs actual behavior
- Relevant logs or error messages

## Feature Requests

Feature requests are welcome! Please:

- Check existing issues first
- Describe the use case
- Explain why it's valuable
- Suggest implementation approach (optional)

## Code Review Guidelines

Reviewers should check:

- Code follows Terraform best practices
- Changes are well-documented
- Tests are included
- No security vulnerabilities introduced
- Backward compatibility maintained
- Performance impact considered

## Release Process

1. Update version in CHANGELOG.md
2. Create release branch
3. Test in all environments
4. Tag release
5. Update documentation
6. Announce release

## Questions?

Open an issue or reach out to maintainers.
