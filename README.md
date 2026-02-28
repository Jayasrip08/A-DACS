# A-DACS

A high-security, role-based Flutter + Firebase application designed for digital fee clearance. This system digitizes the "No-Due Certificate" process through automated payment tracking, AI-powered OCR verification, and tamper-proof digital certificates.

## 🎯 Project Goals

- **Zero Paperwork**: Move the entire clearance process to a secure digital workflow.
- **Financial Integrity**: Algorithmic verification of payments to prevent fraud.
- **Forgery Prevention**: Publicly verifiable certificates using unique cryptographic IDs and QR codes.
- **Automated Communication**: Multichannel alerts (FCM, Email, SMS) for parents and students.

---

## 👥 User Roles & Access Control

### 🎓 Students
- **Smart Registration**: Verify identity and provide parent contact details.
- **Fee Management**: View personalized fee structures based on Department, Batch, and Quota.
- **Flexible Payments**: Pay via UPI, QR Code, or Demand Draft (DD).
- **AI Receipt Submission**: Upload screenshots with automatic OCR detail extraction.
- **Digital No-Dues**: Generate and download secure PDFs once all dues are cleared.

### 💼 Staff / HODs
- **Departmental Dashboard**: Monitor all students within their specific department.
- **Live Status Tracking**: View real-time payment progress (PAID, OVERDUE, PENDING).
- **Audit Reports**: Download comprehensive Student Fee Statements as PDFs.
- **Departmental Approval**: Tracking clearance status for departmental records.

### 🛡️ Admin (Accounts/Office)
- **User Governance**: Approve or reject Student and Staff registration requests.
- **Dynamic Fee Engine**: Configure targeted fees for specific batches or quotas.
- **Payment Verification**: Dual-view audit panel (Original Receipt vs. Extracted Data).
- **Cloud Automation**: Trigger bulk reminders and manage system-wide settings.

---

## 🔍 Core Technologies & Algorithms

### 🤖 AI-Powered OCR (Google ML Kit)
The system uses on-device machine learning to scan receipts:
- **Regex Extraction**: Specialized patterns for Transaction IDs, Dates, and Amounts.
- **DD Support**: Native support for extracting Demand Draft numbers and issuing Bank/Branch details.
- **Probability Scoring**: An algorithm that calculates a 1-100 score for extracted amounts. Amounts matching the expected fee receive a **+100 boost** for automatic pre-filling.

### 🛡️ Text Tampering Detection
To ensure absolute data integrity:
- The system captures **Original OCR Data** and compares it with **Student Submitted Data**.
- Any discrepancy flags the payment for Admin review with a **"⚠️ Manual Entry"** alert, preventing digital forgery of screenshots.

### 🔏 Tamper-Proof Certificates
- **UUID Security**: Every certificate has a mathematically unique ID.
- **QR Verification**: A scannable QR code allows anyone (Public) to verify the document against the live database.

### 📱 Cloud Automation (Firebase V2)
- **Scheduled Reminders**: Daily at 10:00 AM IST for upcoming deadlines (7/3/1 days).
- **Registration Welcome**: Automatic SMS to parents with full fee breakdown and **HOD Signature**.
- **Instant Alerts**: SMS and Push notifications for fee changes and payment approvals.

---

## 🏗️ Technical Stack

| Layer | Technology |
|---|---|
| **Frontend** | Flutter 3.x (Android & Web) |
| **Backend** | Firebase (Firestore, Auth, Storage) |
| **Serverless** | Node.js Cloud Functions (V2) |
| **SMS Gateway** | Twilio API (Bilingual Support) |
| **OCR** | Google ML Kit Text Recognition |
| **Architecture** | Provider State Management |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.x)
- Firebase CLI
- Twilio Account (for SMS)

### Installation
```bash
# 1. Clone the repository
git clone https://github.com/Jayasrip08/a_dacs.git

# 2. Setup Firebase
flutterfire configure

# 3. Setup Secrets (Functions)
firebase functions:secrets:set TWILIO_ACCOUNT_SID
firebase functions:secrets:set TWILIO_AUTH_TOKEN
firebase functions:secrets:set TWILIO_PHONE_NUMBER

# 4. Deploy
firebase deploy
```

---

## 🔐 Initial Access (Master Admin)
The system automatically creates a master administrator account on the first run:
- **Email**: `sri17182021@gmail.com`
- **Password**: `ApecAdmin@2026`

---
**A-DACS Development Team | 2026**
