# c2rust-installer

c2rust 相关 Rust 项目的自动化安装脚本。

## 概述

本仓库提供了一个 `install.sh` 脚本，可以自动发现并安装脚本所在目录中所有以 `c2rust-` 为前缀的 Rust 项目。

## 前置要求

- 系统中必须安装 Rust 和 Cargo
- 可从 [https://rustup.rs/](https://rustup.rs/) 安装

## 使用方法

### 基本安装

使用默认前缀 (`$HOME/.c2rust`) 安装所有 c2rust 项目：

```bash
./install.sh
```

### 自定义安装路径

指定自定义的安装前缀：

```bash
./install.sh --prefix=/opt/c2rust
```

或使用空格分隔的语法：

```bash
./install.sh --prefix /opt/c2rust
```

### 帮助信息

显示使用说明：

```bash
./install.sh --help
```

## 功能特性

- **自动发现**：查找所有以 `c2rust-` 开头且包含 Rust 项目的目录
- **验证**：检查 `Cargo.toml` 文件以确保目录是 Rust 项目
- **自定义安装路径**：支持 `--prefix` 选项来指定安装目录
- **进度报告**：在安装过程中显示清晰的进度信息
- **错误处理**：提供详细的错误消息和安装摘要
- **PATH 提醒**：如果安装目录不在您的 PATH 中会发出提醒

## 工作原理

脚本执行以下操作：

1. 在安装脚本所在的目录中搜索所有匹配 `c2rust-*` 的子目录
2. 验证每个目录是否包含 `Cargo.toml` 文件
3. 对每个项目路径执行 `cargo install --path "<project_path>" --root <prefix>` 进行安装
4. 报告每个项目的安装成功/失败状态
5. 显示所有安装的摘要

## 安装路径

默认情况下，二进制文件将安装到：
- `$HOME/.c2rust/bin`（默认前缀）
- `<prefix>/bin`（自定义前缀）

请确保将安装目录添加到您的 PATH：

```bash
export PATH="$HOME/.c2rust/bin:$PATH"
```

## 示例输出

```
==========================================
c2rust Projects Installer
==========================================

Installation prefix: /home/user/.c2rust
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

Installation prefix: /home/user/.c2rust
  Binaries:        /home/user/.c2rust/bin

所有安装已成功完成！
```

## 故障排除

### 未找到项目

如果脚本报告未找到项目，请确保：
- 您的目录以 `c2rust-` 开头
- 每个目录都包含 `Cargo.toml` 文件
- 您使用的是本仓库中的 `install.sh` 脚本（它会在脚本自身所在位置发现项目，而不是当前工作目录）

### 安装失败

如果某个项目安装失败：
- 检查项目的 `Cargo.toml` 是否有效
- 确保所有依赖项都可用
- 查看错误消息以了解具体问题

### 未找到 Cargo

如果脚本报告未找到 cargo：
- 从 [https://rustup.rs/](https://rustup.rs/) 安装 Rust
- 确保 cargo 在您的 PATH 中

## 许可证

请参阅各个项目各自的许可证。

