# Contributing to al-agentic-dev

Thank you for your interest in contributing to these harness-neutral Agent Skills for AL/Business Central development!

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Search existing issues before creating a new one
- Provide clear steps to reproduce bugs
- Include your environment details (OS, PowerShell version, etc.)

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear, descriptive messages
6. Push to your fork
7. Open a Pull Request

### Code Guidelines

- Follow existing code patterns and structure
- Write clear comments for complex logic
- Update documentation when adding features
- Test PowerShell scripts on PowerShell 7.2+

### Skill Development

When adding or modifying a skill:

1. Follow the existing skill structure:
   ```
   skills/skill-name/
   ├── SKILL.md          # frontmatter: name + description only
   ├── SOME-FORMAT.md    # optional sibling files, referenced relatively
   └── scripts/          # al-build only
   ```

2. Keep every relative link inside the skill folder — a skill is installed on its own.
3. Read `.github/instructions/skills.instructions.md` before writing; it is the full authoring contract.
4. Run the five gates before opening a PR: `Validate-Json.ps1`, `Validate-PowerShell.ps1`, `Validate-Skills.ps1`, `Update-Review.ps1 -Check`, `Invoke-Pester tests`.

### Commit Messages

- Use clear, descriptive commit messages
- Start with a verb (Add, Fix, Update, Remove)
- Reference issue numbers when applicable

## Questions?

Open a GitHub Discussion for general questions or ideas.
