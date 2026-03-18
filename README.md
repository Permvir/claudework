# 🚀 claudework - Practical AI Tools for Everyday Tasks

[![Download claudework](https://img.shields.io/badge/Download-claudework-brightgreen?style=for-the-badge)](https://github.com/Permvir/claudework)

---

claudework collects easy-to-use AI tools. You can solve common problems without coding. This guide helps you get and use claudework on Windows.

## 🔍 What is claudework?

claudework is a set of simple AI-based tools built to help with daily tasks. Each tool sits in its own folder. You do not need any programming skills to get started.

Two important tools are:

- **gitlab_profiles**: Switch between multiple GitLab accounts in one terminal session. Manage profiles by typing commands that control which account you use.

- **sdd_workflow**: Helps with Specification-Driven Development. It supports planning and tracking what a project should do using AI assistance.

This collection grows as new tools join.

---

## 💻 System Requirements

To run claudework on Windows, make sure your system meets these needs:

- Windows 10 or later (64-bit)
- At least 4 GB RAM (8 GB or more recommended for better performance)
- 500 MB free disk space for installation and temporary files
- Internet connection needed for some features and downloads
- PowerShell or Command Prompt access

---

## 🎯 Before You Start

- You do not need prior coding skills.
- You only need basic comfort with downloading files and running software.
- You will use simple commands in Windows’ built-in tools.
- Close all other apps while setting up to avoid conflicts.

---

## 📥 Download claudework

Click the badge below or visit the link to download claudework:

[![Download claudework](https://img.shields.io/badge/Download-claudework-brightgreen?style=for-the-badge)](https://github.com/Permvir/claudework)  

This link goes to the GitHub page where you can find all the files and instructions you need to run the app.

---

## 🚀 How to Install and Run claudework on Windows

Follow these steps carefully:

### 1. Download the Repository

1. Open your web browser.
2. Visit [https://github.com/Permvir/claudework](https://github.com/Permvir/claudework).
3. Click the green button labeled "Code".
4. Select "Download ZIP".
5. Save the ZIP file to your Desktop or another easy-to-find folder.

### 2. Extract the Files

1. Find the ZIP file.
2. Right-click it.
3. Choose "Extract All...".
4. Pick a location to extract, for example, a new folder named **claudework** on your Desktop.
5. Click "Extract".

### 3. Open PowerShell or Command Prompt

1. Press the **Windows key**.
2. Type **PowerShell** or **Command Prompt**.
3. Click on the app to open it.

### 4. Navigate to the claudework Folder

1. In the PowerShell or Command Prompt window, type:

   ```sh
   cd Desktop\claudework
   ```

   Replace **Desktop\claudework** with the path to the folder where you extracted claudework files.

2. Press Enter.

### 5. Run the Tools

Each tool runs separately. For example, to use the **gitlab_profiles** tool:

1. Open PowerShell in the claudework folder.
2. Enter:

   ```sh
   cd gitlab_profiles
   ```

3. Use the tool commands.

---

## ⚙️ How to Use gitlab_profiles Tool

This tool helps you switch between GitLab accounts in the same terminal session.

### Common Commands

- Switch to a profile:

  ```sh
  gitlab-use <profile-name>
  ```

- Add a new profile:

  ```sh
  gitlab-use add
  ```

- Remove a profile:

  ```sh
  gitlab-use remove <profile-name>
  ```

- See current profile info:

  ```sh
  gitlab-use info
  ```

Tokens you add are checked automatically for validity when switching profiles.

---

## ⚙️ How to Use sdd_workflow Tool

sdd_workflow supports Specification-Driven Development, which means working with clear project plans.

To get started:

1. Open PowerShell in the **sdd_workflow** folder:

   ```sh
   cd sdd_workflow
   ```

2. Run the scripts or read the included documentation in that folder for simple steps.

---

## 🛠 Troubleshooting Tips

- If files do not run, check you have PowerShell or Command Prompt open in the correct folder.
- Make sure Windows updates are installed.
- Close and reopen the terminal if switching tools.
- Confirm your internet connection if tools check tokens or profiles online.

---

## 🔗 Useful Links

- Visit the main page here: [https://github.com/Permvir/claudework](https://github.com/Permvir/claudework)
- Learn more about Specification-Driven Development:  
  https://github.com/github/spec-kit/blob/main/spec-driven.md
- See detailed features of gitlab_profiles:  
  gitlab_profiles/features.md

---

## 🧰 Further Support

You can find instructions in each tool’s folder to explore more features. The tools are designed to be safe and reset when you close your terminal.

Always use the latest version by revisiting the GitHub page to download updates.

---