# A-DACS - Project Documentation

## 1. Project Overview
**A-DACS** is a high-security, role-based mobile application designed to digitize the fee payment and "No Due Certificate" issuance workflow. The system eliminates manual paperwork, ensures financial transparency, and prevents certificate forgery.

**Core Philosophy:**
*   **Verified Access Only**: No public registration. All accounts require manual Administrative approval.
*   **Algorithmic Verification**: Payment receipts are cross-referenced using OCR, Regex, and Scoring algorithms to detect tampering.
*   **Tamper-Proof Certificates**: Issued certificates are cryptographically unique and publicly verifiable via QR codes.
*   **Automated Communication**: Multichannel notifications (FCM, Email, SMS) keep parents and students informed of deadlines and statuses.

---

## 2. User Roles & Responsibilities

### 🎓 Student
*   **Registration**: Provides legal name, register number, and parent's contact for verification.
*   **Fee Management**: Views personalized fee structures based on Batch, Department, and Quota (e.g., Management/Govt).
*   **Payments**: Executes payments via UPI Intent (GPay/PhonePe), QR Code, or Demand Draft (DD).
*   **Receipt Submission**: Uploads screenshots; uses AI OCR to pre-fill transaction details.
*   **No-Due Generation**: One-tap PDF generation once all mandatory dues are verified.
*   **Wallet**: Manages overpayments which are stored in a digital "Wallet" for future semester use.

### 💼 Staff (Departmental)
*   **Monitoring**: Real-time dashboard of all students within their specific department.
*   **Status Tracking**: Quick-glance indicators for student financial status (PAID, OVERDUE, PENDING).
*   **Reporting**: Downloads "Student Fee Statements" (PDF) containing full audit history for counseling sessions.
*   **Certificate Audit**: Verifies if students in their department have successfully generated their No-Dues.

### 🛡️ Administrator (System Master)
*   **Access Control**: Approves or Rejects all Student and Staff sign-up requests.
*   **Infrastructure Setup**: Defines Academic Years, Semesters, Departments, and active Bank accounts.
*   **Dynamic Fee Engine**: Creates complex fee structures targeted at specific groups (e.g., "Bus User - Batch 2022").
*   **Payment Audit**: Reviews receipts using the **Text Tampering Detection** panel to verify data integrity.
*   **Bulk Reminders**: Triggers automated multichannel reminders (Email + SMS) to all overdue students.
*   **Seeding**: The system includes a self-seeding master admin (`sri17182021@gmail.com`) for bootstrap access.

---

## 3. Deep Dive: Core Algorithms & Security

### 🔍 OCR, Regex & Scoring Algorithm
The system uses a sophisticated engine to ensure the integrity of uploaded receipts:
1.  **Extraction**: Powered by `google_mlkit_text_recognition` on-device.
2.  **Validation Threshold**: The app scans for keywords (e.g., "UPI", "Bank", "Paid"). An image is rejected if it fails to meet a **2-keyword minimum match**, preventing the upload of random photos.
3.  **Regex Identification**:
    *   **Date**: Extracts dates using standard `\b(\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4})\b` patterns.
    *   **Amount**: Scans for price patterns using `(?:(Rs\.?|INR|₹))?\s?(\d+(?:,\d{3})*(?:\.\d{2})?)`.
    *   **TXN ID (UPI)**: Identifies transaction IDs like `order_...`, `pay_...`, or 12-digit UPI reference numbers.
    *   **DD Number (Demand Draft)**: Uses a specialized pattern to find the 6-12 digit draft number:
        *   Primary: `(?:dd\s*no\.?|draft\s*no\.?|d\.d\.?\s*no\.?)[:\s]*(\d{6,12})` (Case Insensitive).
        *   Fallback: `\b(\d{6,12})\b` (Cross-referenced with keywords like "Draft" or "Bank").
    *   **Bank/Branch (DD)**: Scans for lines containing `bank`, `drawn on`, or `payable at` to identify the issuing institution.
4.  **Probability Scoring**:
    *   The system calculates a "Likelihood Score" for extracted amounts.
    *   **+100 Points**: If the extracted amount exactly matches the expected fee for that student.
    *   **+20 Points**: If the amount is found immediately adjacent to a currency symbol or "Total" keyword.
    *   The value with the highest score is automatically pre-filled into the form.

### 🛡️ Text Tampering Detection
To prevent students from digitally altering screenshots:
*   The system stores the **Original OCR Values** (raw data) separately from the **User Submitted Values**.
*   If a student manually changes a pre-filled field (e.g., changes an "Amount" from 500 to 5000), the system flags the field as `edited: true`.
*   Admins see a red **"⚠️ Manual Entry (Possible Tampering)"** warning in the audit portal, ensuring every payment is manually cross-checked against the image proof.

### 🔏 No-Due Certificate Security
Certificates are protected against forgery through three layers of security:
1.  **Unique Cryptographic ID**: Every certificate is assigned a unique UUID in Firestore.
2.  **Public Verification Portal**: Each certificate includes a QR code linking to a public web page (`/verify?id=...`).
3.  **Cross-Reference**: When scanned, the portal pulls the *live* student data directly from the database. If the paper details do not match the digital record, the certificate is rejected as fake.

---

## 4. Communication & SMS System

### 📱 Twilio SMS Integration
The application uses Firebase Cloud Functions (V2) integrated with Twilio to reach parents directly:
*   **Automated Reminders**: Sent 7 days, 3 days, and 1 day before the fee deadline.
*   **Registration Welcome**: New students receive a personalized SMS including the College name (**Adhiparasakthi Engineering College**), their full fee breakdown, and a signature from their **Department HOD**.
*   **Payment Updates**: Parents are notified as soon as a payment is verified or rejected by an admin.

### 🇮🇳 DLT Compliance (India)
For production use in India, the system is designed to comply with TRAI's DLT regulations:
*   **Sender ID**: Uses a 6-letter approved Header (e.g., `ADACSN`).
*   **Templates**: All messages are registered as bilingual (English & Tamil) templates with fixed variables `{#var#}` for security.

### 📧 Reminder Automation
*   **Trigger**: Manual Admin Action (Safety switch) or Scheduled Job.
*   **Process**:
    1.  Fetch all active Fee Structures.
    2.  Filter for `deadline < today`.
    3.  Query students with unpaid status.
    4.  **Action**: Dispatch emails and SMS to the filtered list.

---

## 5. Cloud Automation & Serverless Workflows
The backend logic is powered by **Firebase Cloud Functions (V2)**, which provides 24/7 automated monitoring and communication without requiring the app to be open:

### 🕒 Scheduled Tasks
*   **Daily Payment Reminders**: A cron-job (`sendPaymentReminders`) runs every day at 10:00 AM IST. It automatically identifies students who are 7 days, 3 days, or 1 day away from their fee deadline and sends a "Urgency Alert" via SMS and Email.

### ⚡ Real-Time Event Triggers (Firestore)
*   **Smart Registration (`onNewRegistration`)**: When a student signs up, the cloud automatically identifies their department's fee structure and welcomes the parent with a personalized SMS containing total dues and the HOD's signature.
*   **Fee Change Alerts (`onFeeStructureChanged`)**: If an Admin updates the Tuition or Bus fee mid-semester, the system instantly notifies all affected students/parents of the change and new deadline.
*   **Payment Confirmation (`onPaymentStatusChangeV2`)**: As soon as an Admin clicks "Verify", a background function triggers a congratulatory SMS to the parent, clearing the student's dues in real-time.

### 🛡️ Administrative Callables
*   **Manual Overdue Trigger (`triggerManualOverdueSMS`)**: Admins can bypass the schedule and manually "nudge" a specific student with an urgent overdue SMS directly from the dashboard.

---

## 6. Technical Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Logic** | **Flutter (Dart) 3.x** | Cross-platform frontend logic. |
| **Backend** | **Firebase** | Firestore (DB), Storage (Files), Auth (Users). |
| **Serverless** | **Node.js Cloud Functions** | Automated scheduling and SMS triggering. |
| **SMS** | **Twilio API** | Global SMS gateway for parent alerts. |
| **OCR** | **Google ML Kit** | High-speed on-device text recognition. |
| **Verification** | **UUID & QR Code** | Forgery-proof certificate system. |

---
**A-DACS Development Team | 2026**
