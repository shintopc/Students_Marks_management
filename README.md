# Student Marks Management System

A comprehensive Windows Desktop application built with Flutter for managing student data, academic records, and grade reporting. Designed for schools to streamline the grading process with a modern, user-friendly interface.

## 🚀 Key Features

### 1. 🎓 Student Management
- **Add/Edit Students:** Manage student profiles with Roll No, Name, and Admission Number.
- **Bulk Entry:** Quickly add multiple students to a class using the Bulk Entry interface.
- **Search & Filter:** Instantly find students by Name or Roll No.
- **Import/Export:** Export student lists to Excel.

### 2. 📚 Academic Management
- **Class Management:** Create classes (e.g., "10 A", "8 B") and assign specific subjects to them.
- **Subject Management:** Define subjects with custom "Max Marks" (Written + Practical components).
- **Term Management:** Configure academic terms (e.g., Term 1, Term 2, Annual).

### 3. 📝 Marks Entry & Grading
- **Efficient Entry:** Enter marks subject-wise for the entire class.
- **Validation:** Real-time validation ensures marks do not exceed the maximum limit.
- **Custom Grading Engine:** Automatic Grade and GPA calculation based on flexible grading rules.
  - Supports different rules for Grade 8, 9, and 10 (e.g., A+ starts at 90% or 80%).
  - customizable grading scales via Settings.

### 4. 📊 Analysis & Reporting
- **Grade Analysis:** View detailed performance metrics for specific exams.
- **Tabulation Registers:** Generate class-wide marks sheets (TR) in PDF or Excel formats.
- **Report Cards:** Generate professional individual Student Report Cards (PDF) with multi-term support.
- **Export Power:** "Save as PDF" and "Export to Excel" available for all major reports.

### 5. 👥 User Management & Security
- **Role-Based Access:**
  - **Admin:** Full access to Settings, User Management, and all data.
  - **Teacher:** Restricted access to assigned classes and subjects.
- **Teacher Assignments:** Admins can link specific teachers to specific classes/subjects.
- **Secure Login:** Password-protected access for all users.

### 6. ⚙️ Settings & Data Safety
- **School Profile:** Customize School Name and Logo for Reports.
- **Backup & Restore:** Securely backup the entire database and restore it when needed.
- **Factory Reset:** Option to wipe academic data while preserving User accounts and Configurations.
- **Grading Rules:** Visual editor to tweak grade boundaries (Min %, Max %, Grade Label, GPA).

---

## 🛠️ How to Use

### 1. First Run & Setup
1. **Launch the App:** Run `studentmanagement.exe`.
2. **Login:** Use the administrator credentials provided during setup (Default: `admin` / `admin123`).
3. **Configure School Profile:** Go to **Settings** -> **School Profile** to set your school name and logo.

### 2. Setting Up Academic Data (Admin)
1. **Create Classes:** Go to **Dashboard** -> **Classes** -> **Add Class**.
2. **Create Subjects:** Go to **Dashboard** -> **Subjects** -> **Add Subject**.
3. **Assign Subjects:** Click on a Class -> **Assign Subjects** to link subjects to that class.
4. **Grading Rules:** Go to **Settings** -> **Grading Rules** to verify or customize the grading scale for your classes.

### 3. Adding Students
1. Go to **Students** tab.
2. Select a Class.
3. Click **Add Student** for single entry or **Bulk Import** for fast entry.

### 4. Entering Marks (Teacher/Admin)
1. Go to **Enter Marks** tab.
2. Select **Class**, **Subject**, and **Term**.
3. Enter `Written` and `Practical` marks for each student.
4. Click **Save** (Dialog confirmation will appear).

### 5. Generating Reports
1. Go to **Reports** tab.
2. Select **Class** and **Term**.
3. **View Report Card:** Click the "Eye" icon next to a student to view their report card instantly.
4. **Download Report Card:** Click the "PDF" icon to save the file.
5. **Class Reports:** Use the "Export Excel" or "Print PDF" buttons at the top for class-wide registers.

---

## 💻 Technical Details
- **Framework:** Flutter (Windows Desktop)
- **Database:** SQLite (sqflite_common_ffi)
- **Architecture:** Provider-based State Management
- **PDF Generation:** `pdf` & `printing` packages
- **Excel:** `excel` package

## 📦 Installation
Installation required. Simply install `studentmanagement.exe`.

---
*Developed for efficient School Management.*
