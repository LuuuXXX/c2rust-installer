# c2rust-installer

An automated installation script for c2rust-related Rust projects.

## Overview

This repository provides an `install.sh` script that automatically discovers and installs all Rust projects in the script directory that are prefixed with `c2rust-`.

## Prerequisites

- Rust and Cargo must be installed on your system
- Install from [https://rustup.rs/](https://rustup.rs/)

## Usage

### Basic Installation

Install all c2rust projects with default prefix (`$HOME/.local`):

```bash
./install.sh
```

### Custom Installation Path

Specify a custom installation prefix:

```bash
./install.sh --prefix=/opt/c2rust
```

Or with space-separated syntax:

```bash
./install.sh --prefix /opt/c2rust
```

### Help Information

Display usage information:

```bash
./install.sh --help
```

## Features

- **Automatic Discovery**: Finds all directories starting with `c2rust-` that contain Rust projects
- **Validation**: Checks for `Cargo.toml` files to ensure directories are Rust projects
- **Custom Installation Path**: Support for `--prefix` option to specify installation directory
- **Progress Reporting**: Shows clear progress information during installation
- **Error Handling**: Provides detailed error messages and installation summary
- **PATH Reminder**: Notifies if the installation directory is not in your PATH

## How It Works

The script:

1. Searches the directory containing the installer script for all subdirectories matching `c2rust-*`
2. Validates that each directory contains a `Cargo.toml` file
3. Installs each project using `cargo install --path . --root <prefix>`
4. Reports installation success/failure for each project
5. Displays a summary of all installations

## Installation Path

By default, binaries are installed to:
- `$HOME/.local/bin` (default prefix)
- `<prefix>/bin` (custom prefix)

Make sure to add the installation directory to your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Example Output

```
==========================================
c2rust Projects Installer
==========================================

Installation prefix: /home/user/.local
Script directory: /path/to/c2rust-installer

Searching for c2rust-* projects...
Found 2 project(s):
  - c2rust-tool1
  - c2rust-tool2

Installing c2rust-tool1...
✓ Successfully installed c2rust-tool1

Installing c2rust-tool2...
✓ Successfully installed c2rust-tool2

==========================================
Installation Summary
==========================================
Successfully installed (2):
  ✓ c2rust-tool1
  ✓ c2rust-tool2

Installation path: /home/user/.local/bin

All installations completed successfully!
```

## Troubleshooting

### No projects found

If the script reports no projects found, ensure:
- Your directories start with `c2rust-`
- Each directory contains a `Cargo.toml` file
- You're using the `install.sh` script from this repository (it discovers projects relative to its own location, not your current working directory)

### Installation failures

If a project fails to install:
- Check that the project's `Cargo.toml` is valid
- Ensure all dependencies are available
- Check the error message for specific issues

### Cargo not found

If the script reports that cargo is not found:
- Install Rust from [https://rustup.rs/](https://rustup.rs/)
- Ensure cargo is in your PATH

## License

See the individual projects for their respective licenses.
