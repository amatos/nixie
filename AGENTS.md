# CLAUDE.md

This file provides guidance to LLM agents when working with code in this repository.

## What this is

TEMPLATE

## Git commit messages

Commit messages follow the [Conventional Commits](https://www.conventionalcommits.org/)
specification. The summary line should be prefixed with a type (`feat`, `fix`, `docs`,
`chore`, `refactor`, etc.), and the body should use a succinct bulleted list to describe
what changed:

```shell
<type>[optional scope]: brief summary

- path/to/file: what changed and why
- path/to/other/file: what changed and why
```

## Changelog

`CHANGELOG.md` follows the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.
Update it whenever you make a change to the repository. Add entries under the `## [Unreleased]`
section, using `### Added`, `### Changed`, `### Fixed`, or `### Removed` sub-headings as appropriate.
Each entry should name the affected file and briefly explain what changed and why.

When committing manually, use a tool like [commitizen](https://github.com/commitizen-tools/commitizen)
(`cz commit`) to ensure commit messages and changelog entries stay consistent and useful.
