# macOS Development Environment Setup & Homebrew Apps Tracker

This repository provides a suite of scripts and detailed instructions to help you set up your macOS development environment—even if you’re new to the process. The repository includes:

- **Environment Setup & App Installation Script (`setup-environment.sh`):**  
  Installs Homebrew (if needed), Git, Node.js, and Python3. It also installs essential applications using Homebrew such as Visual Studio Code, Raycast, OBS, VLC, Tailscale, Notion, and opens the App Store for Xcode. Finally, it checks for an SSH key (and creates one if necessary), then displays clear instructions on how to add it to GitHub.

- **Dynamic Homebrew Apps Tracker (`list-brew-apps-dynamic.sh`):**  
  Maintains a cumulative list of all Homebrew packages and cask apps installed on your system. The script checks for new installations, updates persistent files, generates timestamped export files, and (if enabled) automatically commits and pushes changes to your GitHub repository. It also includes a self-update feature and an optional watch mode.

- **Git & SSH Setup Instructions:**  
  Step-by-step guidance for generating an SSH key, adding it to GitHub, and initializing your local Git repository.

---

## Table of Contents

- [Features](#features)
- [Scripts Overview](#scripts-overview)
  - [1. Environment Setup & App Installation Script](#1-environment-setup--app-installation-script)
  - [2. Dynamic Homebrew Apps Tracker](#2-dynamic-homebrew-apps-tracker)
- [Prerequisites](#prerequisites)
- [Setup Instructions](#setup-instructions)
  - [A. Clone the Repository](#a-clone-the-repository)
  - [B. Run the Environment Setup & App Installation Script](#b-run-the-environment-setup--app-installation-script)
  - [C. Configure Git & SSH Keys](#c-configure-git--ssh-keys)
  - [D. Use the Dynamic Homebrew Apps Tracker](#d-use-the-dynamic-homebrew-apps-tracker)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Automated Environment Setup & App Installation:**  
  Installs Homebrew, Git, Node.js, and Python3. Also installs essential apps:
  - **Visual Studio Code**
  - **Raycast**
  - **OBS**
  - **VLC**
  - **Tailscale**
  - **Notion**
  - **Xcode** (opens the App Store for installation)

- **Dynamic Monitoring:**  
  Continuously tracks your Homebrew-installed packages and cask apps, updating persistent logs and generating cumulative timestamped reports.

- **Auto-Upload & Self-Update:**  
  Automatically commits and pushes changes to your GitHub repository (if enabled) and can update itself from a remote URL.

- **Easy Git & SSH Setup:**  
  Step-by-step instructions to generate an SSH key and add it to GitHub, with guidance on initializing a Git repository.

---

## Scripts Overview

### 1. Environment Setup & App Installation Script

File: `setup-environment.sh`

This script will:
- **Install Homebrew:** Checks if Homebrew is installed; if not, installs it.
- **Install Core Tools:** Installs Git, Node.js, and Python3.
- **Install Essential Apps:** Uses Homebrew to install:
  - Visual Studio Code
  - Raycast
  - OBS
  - VLC
  - Tailscale
  - Notion  
  For **Xcode**, it opens the App Store using its URL.
- **SSH Key Management:** Checks for an existing SSH key (using Ed25519); if none exists, prompts for your email and generates a new key. It then displays the public key and detailed instructions for uploading it to GitHub.

### 2. Dynamic Homebrew Apps Tracker

File: `list-brew-apps-dynamic.sh`

This dynamic script will:
- **Maintain Persistent Lists:** Keep track of Homebrew packages and cask apps in `~/brew-installed-lists`.
- **Cumulative Export:** Generate timestamped cumulative export files with all detected apps.
- **Auto-Upload:** Automatically commit and push updates to a GitHub repository (if enabled).
- **Self-Update & Watch Mode:** Check for newer script versions from a remote URL and optionally run in watch mode (e.g., every hour).

---

## Prerequisites

- **Operating System:** macOS with zsh as your default shell.
- **Internet Connection:** Active internet is required for installations and updates.
- **Basic Terminal Knowledge:** Familiarity with command line operations.
- **Homebrew:** The script installs Homebrew if it is not already present.
- **Git:** Installed (the script installs it if needed).

---

## Setup Instructions

### A. Clone the Repository

Open your terminal and run:

```bash
git clone git@github.com:yourusername/your-repo.git
cd your-repo
