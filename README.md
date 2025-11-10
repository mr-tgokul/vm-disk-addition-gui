
# VM Disk Addition Tool (PowerShell GUI)

**Automate the process of adding virtual disks to multiple VMs in a VMware vSphere environment using a user-friendly GUI.**

---

## **Table of Contents**
- [Overview](#overview)  
- [Features](#features)  
- [Prerequisites](#prerequisites)  
- [Usage](#usage)  
- [VM List File Format](#vm-list-file-format)  
- [Logging](#logging)  
- [Error Handling](#error-handling)  
- [Screenshots](#screenshots)  
- [License](#license)  

---

## **Overview**
The VM Disk Addition Tool is a PowerShell GUI script designed to simplify the process of adding virtual disks to multiple virtual machines in VMware vSphere. Administrators can connect to vCenter, select clusters and datastores, specify disk sizes, and manage VM lists—all through an intuitive graphical interface. The script also generates detailed logs for auditing and troubleshooting.

---

## **Features**
- Graphical interface for easy input:
  - vCenter Server, Username, Password
  - Cluster Name, Datastore Cluster
  - CRQ Number, Disk Size, VM List File
- Connect/disconnect vCenter safely
- Automatically selects the best datastore with sufficient free space
- Adds disks to multiple VMs in bulk
- Real-time progress monitoring with a progress bar
- Rich, color-coded logging in GUI and to a file
- VM list file can be selected from **any location** using a Browse button
- Validates VM existence and cluster membership before disk addition

---

## **Prerequisites**
- PowerShell 5.1 or later
- VMware PowerCLI module installed (`Install-Module -Name VMware.PowerCLI`)
- Access to the target vCenter server and necessary permissions to add disks
- Windows OS for GUI support

---

## **Usage**
1. Clone or download this repository.
2. Open PowerShell and navigate to the script directory.
3. Run the script:
   ```powershell
   .\VM_Disk_Addition_Tool.ps1
   ```
4. Fill in the required fields:
   - **vCenter Server** and login credentials  
   - **Cluster Name** and **Datastore Cluster**  
   - **CRQ Number** (optional for logging purposes)  
   - **Disk Size (GB)**  
   - **VM List File** (Browse to select the text file)
5. Click **Connect** to connect to vCenter.
6. Click **Start Disk Addition** to begin adding disks to the VMs.
7. Monitor the progress in the GUI and check the generated log file.

---

## **VM List File Format**
- The script accepts a simple plain text file with **one VM name per line**.
- Example:
  ```
  VM01
  VM02
  VM03
  ```
- The file can be located anywhere on your system; the script will handle full paths.

---

## **Logging**
- Logs are displayed in the GUI in a RichTextBox with color-coded messages:
  - **INFO** – White  
  - **SUCCESS** – Light Green  
  - **WARNING** – Orange  
  - **ERROR** – Red  
  - **HIGHLIGHT** – Cyan
- A timestamped log file is automatically created in `C:\Temp\disk-add\`.
- Log files include:
  - Script execution details  
  - User and machine information  
  - VM and disk operations

---

## **Error Handling**
- Validates all input fields before execution.
- Checks that VMs exist and belong to the specified cluster.
- Skips VMs if there is no datastore with enough free space.
- GUI remains responsive even during wait periods or errors.

---

## **Screenshots**
<img width="883" height="692" alt="image" src="https://github.com/user-attachments/assets/1b73b43f-4503-4232-b740-4ecbea83db87" />

---

## **License**
This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
