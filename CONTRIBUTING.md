# Contributing to AWS ARC Regional Failover

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check existing issues to avoid duplicates
2. Open a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (AWS region, version, etc.)

### Submitting Changes

1. **Fork the repository**
   ```bash
   git clone https://github.com/dallasclouddev/arc-regional-failover.git
   cd arc-regional-failover
   ```

2. **Create a feature branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Make your changes**
   - Follow existing code style
   - Update documentation as needed
   - Test your changes thoroughly

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Description of changes"
   ```

5. **Push and create a pull request**
   ```bash
   git push origin feature/your-feature-name
   ```

## Development Guidelines

### Code Style

- **Python**: Follow PEP 8 guidelines
- **CloudFormation**: Use consistent indentation (2 spaces)
- **Bash**: Use shellcheck for validation
- **Comments**: Add comments for complex logic

### Testing

Before submitting:

1. Test CloudFormation templates:
   ```bash
   aws cloudformation validate-template --template-body file://template.yaml
   ```

2. Test scripts with ShellCheck:
   ```bash
   shellcheck scripts/*.sh
   ```

3. Test Python code:
   ```bash
   pylint app/python/*.py
   ```

### Documentation

Update documentation when:
- Adding new features
- Changing deployment procedures
- Modifying architecture
- Updating dependencies

## Areas for Contribution

We welcome contributions in these areas:

### Infrastructure
- Additional CloudFormation templates
- Terraform equivalents
- CDK implementations
- Support for additional AWS regions

### Application
- Additional language implementations (Node.js, Java, Go)
- Enhanced monitoring and alerting
- Performance optimizations
- Better error handling

### Documentation
- Improved deployment guides
- Additional architecture diagrams
- Cost optimization strategies
- Troubleshooting guides

### Testing
- Automated testing scripts
- Chaos engineering scenarios
- Performance benchmarks
- Integration tests

## Pull Request Process

1. **Update documentation** for any changes
2. **Add tests** if applicable
3. **Ensure all tests pass**
4. **Update README.md** with details of changes if needed
5. **Request review** from maintainers

## Code Review Criteria

Pull requests are reviewed for:
- Functionality and correctness
- Code quality and style
- Documentation completeness
- Security considerations
- AWS best practices

## Community Guidelines

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Focus on collaboration

## Questions?

- Open an issue for discussion
- Check existing documentation
- Review closed issues for similar questions

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
