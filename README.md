# 📋 Attendance Management System (AMS)

<div align="center">

![AMS Banner](https://img.shields.io/badge/AMS-Attendance%20Management%20System-667eea?style=for-the-badge&logo=flutter&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)
![Node.js](https://img.shields.io/badge/Node.js-18+-339933?style=flat-square&logo=node.js)
![MySQL](https://img.shields.io/badge/MySQL-8.0-4479A1?style=flat-square&logo=mysql&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)

**A full-stack attendance tracking system for schools — QR-based scanning, admin control panel, and SF2 reports.**

[📥 Download Latest Release](#-download) · [📖 Documentation](https://your-username.github.io/ams-docs) · [🐛 Report Bug](../../issues) · [💡 Request Feature](../../issues)

</div>

---

## 📥 Download

| Platform | Download | Version |
|----------|----------|---------|
| 🌐 **Web App** (HTML) | [⬇️ Download `ams-web-v1.0.0.zip`](../../releases/latest/download/ams-web-v1.0.0.zip) | v1.0.0 |
| 📱 **Android APK** | [⬇️ Download `ams-v1.0.0.apk`](../../releases/latest/download/ams-v1.0.0.apk) | v1.0.0 |
| 🖥️ **Windows** | [⬇️ Download `ams-windows-v1.0.0.zip`](../../releases/latest/download/ams-windows-v1.0.0.zip) | v1.0.0 |

> 📌 All releases: [github.com/your-username/ams/releases](../../releases)

---

## 📑 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Screenshots](#-screenshots)
- [Getting Started](#-getting-started)
- [Tutorial: Admin](#-tutorial-admin-panel)
- [Tutorial: Teacher](#-tutorial-teacher-app)
- [Tutorial: Student](#-tutorial-student-app)
- [API Reference](#-api-reference)
- [Deployment](#-deployment)
- [Tech Stack](#-tech-stack)

---

## 🧭 Overview

AMS is a school attendance management system with three user roles:

| Role | What they do |
|------|-------------|
| **Admin** | Manage teachers, students, and classes |
| **Teacher** | Open attendance sessions, scan student QR codes |
| **Student** | View their own attendance and enrolled classes |

---

## ✨ Features

- 🔐 JWT-based login for all three roles
- 📷 QR code scanning for fast attendance marking
- 🗂️ Admin CRUD for teachers, students, and classes
- 📊 SF2 attendance report generation
- 📱 Responsive UI — mobile bottom nav, desktop side rail
- 🎂 Birthday date formatting (`yyyy-MM-dd`)
- ♻️ Cascade delete — removing a teacher also removes their classes and records

---

## 📸 Screenshots

| Admin Dashboard (Desktop) | Admin Dashboard (Mobile) |
|---|---|
| ![Desktop](docs/screenshots/admin-desktop.png) | ![Mobile](docs/screenshots/admin-mobile.png) |

| Teacher QR Scan | Student View |
|---|---|
| ![Scan](docs/screenshots/teacher-scan.png) | ![Student](docs/screenshots/student-view.png) |

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.x
- Node.js 18+
- MySQL 8.0+

### 1. Clone the repo

```bash
git clone https://github.com/your-username/ams.git
cd ams
```

### 2. Set up the backend

```bash
cd backend
npm install
```

Create a `.env` file:

```env
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=ams_db
JWT_SECRET=your_jwt_secret
PORT=3000
```

Run the database migration:

```bash
mysql -u root -p ams_db < database/schema.sql
```

Start the server:

```bash
npm start
```

### 3. Set up the Flutter app

```bash
cd flutter_app
flutter pub get
```

Update `lib/config/api_config.dart` with your backend URL:

```dart
static const String _devUrl = 'http://your-backend-url.com';
```

Run the app:

```bash
flutter run
```

---

## 🛠️ Tutorial: Admin Panel

The admin panel is accessible after logging in with an admin account.

### Navigating the Panel

**Desktop (≥ 720px wide):** A persistent left sidebar shows Teachers, Students, and Classes navigation items along with live counts.

**Mobile (< 720px wide):** Use the bottom navigation bar to switch between Teachers, Students, and Classes tabs.

---

### Managing Teachers

#### Adding a Teacher

1. Go to the **Teachers** tab
2. Click/tap **Add Teacher**
3. Fill in the form:
   - **First Name** and **Surname** (required)
   - **Email** (optional)
   - **Username** and **Password** — used for login (required)
4. Click **Save**

> ⚠️ The username must be unique. If it already exists, you'll see a "Username already exists" error.

#### Editing a Teacher

1. Find the teacher in the list (use the search bar to filter by name or username)
2. Click the **✏️ pencil icon** on their card
3. Update First Name, Surname, or Email
4. Click **Save**

#### Deleting a Teacher

1. Click the **🗑️ trash icon** on the teacher's card
2. Confirm the deletion in the dialog

> ⚠️ **Cascade delete:** Deleting a teacher will also delete all their classes, attendance sessions, and attendance records.

---

### Managing Students

#### Adding a Student

1. Go to the **Students** tab
2. Click **Add Student**
3. Fill in:
   - **LRN** — exactly 12 digits (required)
   - **First Name** and **Surname** (required)
   - **Suffix** (e.g., Jr., III) — optional
   - **Sex** — Male or Female
   - **Birthday** — format: `yyyy-MM-dd` (e.g., `2010-03-15`)
4. Optionally create a login account by filling in **Username** and **Password**
5. Click **Save**

#### Editing a Student

1. Find the student by name or LRN using the search bar
2. Click the **✏️ pencil icon**
3. Update any fields (LRN cannot be changed after creation)
4. Click **Save**

#### Deleting a Student

1. Click the **🗑️ trash icon**
2. Confirm — this also removes all enrollment and attendance records for that student

---

### Managing Classes

#### Creating a Class

1. Go to the **Classes** tab
2. Click **Add Class**
3. Fill in:
   - **Class Name** (required)
   - **Grade** — select Grade 1–12 (required)
   - **Section** — optional (e.g., "Sampaguita")
   - **School Year** — e.g., `2025-2026`
   - **Assign Teacher** — select from the dropdown (required)
4. Click **Save**

#### Editing a Class

1. Click the **✏️ pencil icon** on the class card
2. Update the name, grade, section, or school year
3. Click **Save**

#### Deleting a Class

1. Click the **🗑️ trash icon**
2. Confirm — this deletes all attendance sessions and records for that class

#### Viewing and Managing Class Students

1. Click the **👥 people icon** or tap anywhere on the class card
2. A dialog opens showing all enrolled students

**To enroll a student:**
1. Click the **➕ person-add icon** (top right of the dialog)
2. A search panel slides open showing all unenrolled students
3. Type a name or LRN to filter
4. Click **Enroll** next to the student you want to add

**To remove a student:**
1. Click the **➖ remove icon** next to their name
2. Confirm in the dialog

---

## 👨‍🏫 Tutorial: Teacher App

### Logging In

Use the username and password created by the admin.

### Viewing Classes

The home screen lists all your assigned classes with student count and schedule.

### Opening an Attendance Session

1. Tap a class to open it
2. Tap **Start Attendance**
3. The session opens for today's date automatically

### Scanning QR Codes

1. Inside an open session, tap **Scan QR**
2. Point the camera at a student's QR code
3. The system marks them **Present** and shows a confirmation

> QR codes have a **30-second cooldown** — scanning the same student twice within 30 seconds will be rejected.

### Viewing SF2 Report

1. Open a class
2. Tap **SF2 Report**
3. Select the month and year
4. View or export the monthly attendance grid

---

## 🎓 Tutorial: Student App

### Logging In

Use the username and password assigned by your teacher or admin.

### Viewing Your Classes

The home screen shows all classes you're enrolled in.

### Viewing Attendance

1. Tap a class
2. Your attendance history shows with date, status (Present/Absent), and time marked

### Your QR Code

1. Go to **Profile**
2. Your personal QR code is shown — present this to your teacher for scanning

---

## 📡 API Reference

Base URL: `https://your-backend.com`

### Auth

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/api/auth/login` | Login (all roles) |
| `POST` | `/api/auth/register` | Register student with account |

### Admin — Teachers

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/admin/teachers` | List all teachers |
| `POST` | `/api/admin/teachers` | Create teacher |
| `PUT` | `/api/admin/teachers/:id` | Update teacher |
| `DELETE` | `/api/admin/teachers/:id` | Delete teacher (cascade) |

### Admin — Students

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/admin/students` | List all students (supports `?search=`) |
| `POST` | `/api/admin/students` | Create student |
| `PUT` | `/api/admin/students/:lrn` | Update student |
| `DELETE` | `/api/admin/students/:lrn` | Delete student (cascade) |

### Admin — Classes

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/admin/classes` | List all classes |
| `POST` | `/api/admin/classes` | Create class |
| `PUT` | `/api/admin/classes/:id` | Update class |
| `DELETE` | `/api/admin/classes/:id` | Delete class (cascade) |
| `GET` | `/api/admin/classes/:id/students` | List enrolled students |
| `POST` | `/api/admin/classes/:id/students` | Enroll student |
| `DELETE` | `/api/admin/classes/:id/students/:lrn` | Remove student from class |

### Teacher

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/teacher/classes` | My classes |
| `POST` | `/api/teacher/record-scan` | Mark attendance via QR |
| `GET` | `/api/teacher/classes/:id/students` | Class student list |
| `GET` | `/api/teacher/classes/:id/sf2-attendance` | SF2 report data |

### Student

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/student/profile` | My profile |
| `GET` | `/api/student/classes` | My enrolled classes |
| `GET` | `/api/student/attendance` | My attendance records |

---

## 🌐 Deployment

### Backend (Render / Railway / VPS)

1. Push your `backend/` folder to a repo
2. Set environment variables in your hosting dashboard
3. Deploy — the app starts with `npm start`

### Flutter Web (GitHub Pages)

```bash
flutter build web --release
```

Copy the `build/web/` folder contents to your GitHub Pages branch (`gh-pages`).

### Flutter Web (Self-hosted)

Serve the `build/web/` folder from any static file server (Nginx, Apache, Netlify, Vercel).

---

## 🧱 Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter 3.x (Dart) |
| Backend | Node.js + Express |
| Database | MySQL 8.0 |
| Auth | JWT (jsonwebtoken) |
| Password | bcryptjs |
| HTTP | http (Flutter), axios (optional) |
| State | setState / SharedPreferences |

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

---

<div align="center">
Made with ❤️ for Philippine schools
</div>

