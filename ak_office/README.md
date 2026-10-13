# DocuCraft — Offline Microsoft Word Alternative with Integrated AI Agent

[![Flutter](https://img.shields.io/badge/Flutter-3.47.7-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.5-00b4ab.svg)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-Windows%20%7C%20Android%20%7C%20iPad-success.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-Proprietary-orange.svg)]()
[![Offline First](https://img.shields.io/badge/Network-100%25%20Offline-green.svg)]()

**DocuCraft** is a high-performance, offline-first desktop and tablet word processor inspired by Microsoft Word, engineered in Flutter and Dart. It delivers rich typography, multi-page paper simulation, full `.docx` and `.pdf` interoperability, crash-recovery drafts, revision histories, and an **on-device, permission-controlled AI Assistant** that operates with zero internet connectivity and zero cloud telemetry.

---

## 1. Key Architectural Highlights

```
┌──────────────────────────────────────────────────────────────────┐
│                   DocuCraft Presentation Layer                   │
│  [Ribbon Toolbar]  [Paper Canvas]  [Outline Panel]  [AI Sidebar]  │
└────────────────────────────────┬─────────────────────────────────┘
                                 │
┌────────────────────────────────▼─────────────────────────────────┐
│                      State & Logic Layer                         │
│   Riverpod Providers  •  QuillController  •  EditorController    │
└───────────────┬───────────────────────────────┬──────────────────┘
                │                               │
┌───────────────▼───────────────┐ ┌─────────────▼──────────────────┐
│   Document & Storage Engine   │ │     Offline AI Copilot         │
│ • Local SQLite (Mobile/FFI)   │ │ • On-Device Heuristic Engine   │
│ • Atomic Disk Replacement     │ │ • GGUF Local Model Importer    │
│ • Crash Recovery Drafts       │ │ • Permission-Gated Diff Tools  │
│ • OPC DOCX & Paginated PDF    │ │ • Activity & Audit QA Engine   │
└───────────────────────────────┘ └────────────────────────────────┘
```

- **Strictly Offline-First**: Zero mandatory cloud APIs, zero analytics/telemetry, and zero external tracking. All document files, revision histories, activity logs, and AI conversations reside strictly on the user's local disk.
- **Office Ribbon Interface**: Categorized into `Home`, `Insert`, `Layout`, `View`, and `File` tabs, mirroring Microsoft Word desktop UX.
- **Physical Paper Simulation**: A4, Letter, and Legal aspect-ratio canvas with live margins, portrait/landscape orientation toggling, page breaks, realistic drop shadows, and adjustable zoom controls (50% – 200%).
- **Crash Recovery & Atomic Saves**: Automatic draft checkpoints and atomic file replacement (`.tmp` -> rename) prevent data loss during power outages or unexpected application termination.
- **OPC DOCX & PDF Engine**: Native Open Packaging Conventions ZIP reader and writer (`word/document.xml`) for bidirectional Word exchange, plus multi-page paginated PDF export and OS print preview.
- **Permission-Gated AI Copilot**: The AI assistant inspects local document structure and audit logs, generating visual word-level diff cards with explicit **Accept** and **Reject** buttons. It never modifies user content silently.

---

## 2. Feature Walkthrough

### 2.1 Microsoft Word-Inspired Editor
- **Rich Formatting Toolbar**:
  - Font styling: Bold (`Ctrl+B`), Italic (`Ctrl+I`), Underline (`Ctrl+U`), Strikethrough.
  - Font family dropdown (Calibri, Segoe UI, Roboto, Times New Roman, Georgia, Courier New).
  - Font size selector (8pt to 72pt).
  - Foreground color and highlight color picker palettes.
  - Paragraph alignment: Left, Center, Right, Justify.
  - Heading styles: Normal Text, Heading 1, Heading 2, Heading 3.
  - Lists: Numbered lists, Bulleted lists, Checklists.
  - Indentation: Indent right, Outdent left.
  - Hyperlink insertions and interactive URL navigation.
  - History: Full Undo (`Ctrl+Z`) and Redo (`Ctrl+Y`).
- **Document Elements**:
  - Page Breaks: Insert manual visual page breaks with standard page boundaries.
  - Tables & Callouts: Insert formatted tabular blocks and quote callouts.
  - Page Layout Configurator: Switch between A4 (210×297mm), Letter (8.5×11in), and Legal (8.5×14in); custom margin controls (Narrow, Normal, Wide); Header, Footer, and Page Number toggles.
- **Navigation & Search**:
  - **Dynamic Outline Panel**: Auto-indexes H1, H2, and H3 headers across the document with one-click jump-to-section.
  - **Find & Replace**: Real-time text search bar with match count indicator, Previous/Next navigation, single-match replacement, and Replace-All.
  - **Live Status Bar**: Real-time word count, character count, zoom level, save state badge (Saved / Saving... / Unsaved Changes), and AI Copilot drawer toggle.

### 2.2 Document Management & Crash Recovery
- **Templates**: Start instantly with **Blank Document**, **Project Report**, **Meeting Notes**, or **Business Proposal**.
- **File System Organization**: Documents are saved to the platform's app documents directory under `DocuCraft/Documents/` as `.docucraft` Delta files.
- **Safe Atomic Writes**: Saves write to `[filename].tmp` before renaming to target path, preventing partial corruption.
- **Crash Draft Checkpoints**: Debounced background drafts stored in SQLite. If the app is terminated abruptly, a prominent recovery banner appears on the home screen allowing one-click draft recovery.
- **Revision History**: Snapshots saved on demand or automatically during major edits. Revisions can be inspected, compared, and restored at any time.
- **Activity Audit Log**: Tracks document creation, open, edit, save, DOCX import/export, and AI proposal acceptance with timestamps.

### 2.3 File Interoperability
- **Microsoft Word (.docx) Import**:
  - Parses Open Packaging Conventions (OPC) ZIP packages.
  - Reads `word/document.xml`, extracting paragraphs, headings (`w:pStyle`), bold (`w:b`), italic (`w:i`), underline (`w:u`), and alignments.
  - Displays a detailed **Import Summary & Compatibility Report** informing the user of preserved vs. unsupported Word elements (e.g. complex macros or drawing canvases).
- **Microsoft Word (.docx) Export**:
  - Packages valid WordprocessingML into standard `.docx` ZIP packages containing `[Content_Types].xml`, `_rels/.rels`, and `word/document.xml`.
  - Produces files that open natively in Microsoft Word, LibreOffice, and Google Docs.
- **PDF Export & Printing**:
  - Formats rich text, headings, lists, quotes, and page settings into multi-page PDFs using the `pdf` package.
  - Built-in OS Print Preview dialog with direct printer selection using `printing`.
- **Plain Text (.txt) Import & Export**:
  - High-speed bidirectional plain text conversion.

### 2.4 Integrated Offline AI Copilot
- **Document Analysis**:
  - Summarize documents or highlighted sections.
  - Proofread and identify grammar, spelling, and punctuation errors.
  - Extract salient bullet points and action items.
  - Rewrite sections in Professional, Academic, Casual, or Concise tone.
- **Audit & Activity Question Answering**:
  - Natural-language queries on local application logs:
    - *"What did I do in this application today?"*
    - *"When was this document last saved?"*
    - *"Which AI suggestions have I accepted?"*
    - *"What changes have been made to this document?"*
- **Permission-Gated Tool Proposals**:
  - Whenever the AI proposes document edits, it emits a `propose_text_replacement` or `insert_text_at_cursor` proposal.
  - The UI displays an interactive **Visual Diff Card** showing deletions in red strike-through and additions in green highlight.
  - The document is **never mutated** until the user explicitly clicks the **Accept** button. Clicking **Reject** safely dismisses the proposal.

---

## 3. Project Structure

```
d:/AK-Office/ak_office/
├── lib/
│   ├── main.dart                       # App entry point, FFI initialization, ProviderScope
│   ├── app.dart                        # GoRouter configuration & Fluent theme binding
│   ├── core/
│   │   ├── constants/                  # App constants, Office Blue palette, dimensions
│   │   ├── theme/                      # Fluent Office-inspired light & dark themes
│   │   └── utilities/                  # File utils, atomic file replacement, diff algorithms
│   ├── models/
│   │   ├── document_model.dart         # Document metadata, word counts, timestamps
│   │   ├── page_settings_model.dart    # A4/Letter/Legal, margins, orientation, headers
│   │   ├── activity_model.dart         # Audit log records with EventType
│   │   ├── revision_model.dart         # Document version snapshots
│   │   ├── ai_message_model.dart       # Chat messages and tool associations
│   │   └── ai_tool_model.dart          # Permission-gated tool definitions & proposals
│   ├── database/
│   │   └── database_service.dart       # SQLite database initialization & migrations
│   ├── repositories/
│   │   ├── document_repository.dart    # SQLite document metadata & search queries
│   │   ├── activity_repository.dart    # Activity audit log persistence
│   │   ├── revision_repository.dart    # Document revision history storage
│   │   └── recovery_repository.dart    # Crash recovery draft management
│   ├── services/
│   │   ├── document_service.dart       # High-level coordinator (disk, DB, autosave)
│   │   ├── docx_service.dart           # OPC DOCX import/export engine & XML processor
│   │   ├── pdf_service.dart            # Multi-page PDF layout and print preview
│   │   └── recovery_service.dart       # Crash detection and draft recovery
│   ├── editor/
│   │   ├── editor_controller.dart      # QuillController wrapper, counts, debounced drafts
│   │   ├── editor_toolbar.dart         # Microsoft Word Ribbon toolbar (5 tabs)
│   │   ├── document_canvas.dart        # Paper canvas layout, margins, status bar
│   │   ├── outline_panel.dart          # Real-time heading outline navigation
│   │   └── find_replace_bar.dart       # Find & replace floating widget
│   ├── ai/
│   │   ├── ai_context_models.dart      # Context extraction container
│   │   ├── document_context_service.dart # Extraction of headings, word frequency, summary
│   │   ├── activity_context_service.dart # Natural language query handler for audit logs
│   │   ├── local_model_service.dart    # On-device heuristic engine & GGUF runtime hooks
│   │   ├── ai_service.dart             # AI coordinator, prompt dispatch, tool handling
│   │   └── agent_tools.dart            # Permission-controlled tool declarations
│   └── screens/
│       ├── home_screen.dart            # Templates, recent files, crash recovery banner
│       ├── editor_screen.dart          # Full editor workspace (canvas + ribbon + AI sidebar)
│       ├── assistant_panel.dart        # AI sidebar with quick chips & visual diff cards
│       ├── history_screen.dart         # Revision history & activity audit viewer
│       └── settings_screen.dart        # Model management, privacy disclosures, cache tools
└── test/
    ├── models/document_model_test.dart # Page settings, dimensions, serialization tests
    ├── repositories/repository_test.dart # SQLite database CRUD, audit, revisions tests
    ├── services/docx_service_test.dart # DOCX ZIP & XML generation/parsing tests
    ├── services/pdf_service_test.dart  # Multi-page PDF binary generation tests
    ├── ai/ai_service_test.dart         # Local AI engine, summarizer, audit Q&A tests
    └── widget_test.dart                # App launch, Home screen rendering, templates tests
```

---

## 4. Local AI Engine Architecture & Setup

DocuCraft operates with a two-tiered offline AI architecture:

### 4.1 Tier 1: Built-in Heuristic NLP Engine (Immediate & Zero-Resource)
- Out of the box, DocuCraft includes an offline semantic engine that requires **0MB of downloads** and **0MB of VRAM**.
- Handles:
  - Salient extractive summarization via sentence ranking and frequency scoring.
  - Grammar and spelling proofreading with automatic punctuation/casing fixes.
  - Natural language querying of local SQLite audit logs and revision histories.
  - Generation of structured tool proposals with word-level visual diffs.

### 4.2 Tier 2: Local GGUF Model Runtime (Quantized LLMs)
For deeper generative writing, DocuCraft supports importing quantized GGUF language models (e.g. `Llama-3.2-1B-Instruct-Q4_K_M.gguf` or `Phi-3.5-mini-instruct-Q4_K_M.gguf`):
1. Navigate to **Settings** -> **Local AI Model Settings**.
2. Click **Import Model (.gguf)**.
3. Select your local `.gguf` file from your device storage.
4. DocuCraft validates the file signature, copies it to the sandboxed `DocuCraft/Models/` folder, and activates local inference.
5. In the event of an incompatible or corrupted model, DocuCraft gracefully falls back to Tier 1 without interrupting document editing.

---

## 5. Security & Privacy Guarantees

1. **No External Network Calls**: The app makes zero HTTP/HTTPS network requests. Normal document editing, PDF export, DOCX processing, and AI features operate completely air-gapped.
2. **Untrusted Input Protection**: Document contents passed to the AI prompt builder are strictly isolated in user context blocks. Documents cannot override system instructions or trigger unpermitted tools.
3. **No Silent Modifications**: Destructive actions (text replacement, file deletion, draft restoration) require explicit user confirmation.
4. **Data Ownership**: Document files, SQLite databases, and AI logs can be backed up, inspected, or deleted directly by the user from their native file explorer.

---

## 6. Build & Setup Instructions

### 6.1 Prerequisites
- **Flutter SDK**: 3.27.0 or newer (tested on Flutter 3.47.7, Dart 3.13.5).
- **Windows**: Windows 10/11 64-bit with Visual Studio 2022/2026 (Desktop development with C++).
- **Android**: Android Studio with Android SDK API 34+ and NDK.
- **macOS / iOS (iPad)**: Xcode 15+ and CocoaPods (for building iPad packages).

### 6.2 Getting Started
```bash
# Clone the repository
cd d:/AK-Office/ak_office

# Fetch dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run the automated test suite
flutter test
```

### 6.3 Windows Desktop Build
```bash
# Debug run on Windows
flutter run -d windows

# Compile optimized release executable
flutter build windows --release
```
The compiled Windows binary and runtime assets will be located in:
`build/windows/x64/runner/Release/`
- Executable: `ak_office.exe`
- Distribute the entire folder containing `ak_office.exe`, `flutter_windows.dll`, and `data/`.

### 6.4 Android Tablet Build
```bash
# Build optimized APKs split by architecture
flutter build apk --split-per-abi --release

# Or build an Android App Bundle
flutter build appbundle --release
```
The release APKs will be located in:
`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`

### 6.5 iPad (iOS) Build & Code Signing
```bash
# Generate iOS release bundle
flutter build ipa --release
```
Open `ios/Runner.xcworkspace` in Xcode:
1. Select your Apple Developer Team in **Signing & Capabilities**.
2. Configure tablet orientation support (`UIInterfaceOrientationPortrait`, `UIInterfaceOrientationLandscapeLeft`, `UIInterfaceOrientationLandscapeRight`).
3. Build and deploy to connected iPad or distribute via TestFlight / Ad-Hoc.

---

## 7. Platform Compatibility & Known Limitations

| Feature | Windows Desktop | Android Tablet | iPad |
|:---|:---:|:---:|:---:|
| Rich Text Editing | Full | Full (Touch-optimized) | Full (Touch-optimized) |
| Ribbon Toolbar | Full Desktop Ribbon | Responsive / Scrollable | Responsive / Scrollable |
| Keyboard Shortcuts | Full (Ctrl+S/B/I/U/Z/Y/P) | Supported with external keyboard | Supported with external keyboard |
| SQLite Engine | `sqflite_common_ffi` | `sqflite` | `sqflite` |
| Native File Picker | Windows Open/Save Dialog | Storage Access Framework | UIDocumentPickerViewController |
| DOCX Import / Export | Full | Full | Full |
| PDF Export & Print | Native Print Spooler | Android Print Service | AirPrint |
| Local AI (Tier 1 Heuristic) | 100% Offline | 100% Offline | 100% Offline |
| Local AI (Tier 2 GGUF) | Supported (Direct File) | Supported (Scoped Storage) | Subject to iOS memory limits (2GB+) |

### Known Limitations
- **Complex DOCX Shapes & Macros**: Word shapes, SmartArt, and VBA macros in imported `.docx` files are safely skipped, and reported in the compatibility summary dialog.
- **Embedded Fonts**: PDF export utilizes standard TrueType/Type-1 metrics (Helvetica/Times); custom non-Unicode glyphs fall back to ASCII equivalents.

---

## 8. Verification & Test Results

The project includes automated test suites covering all architectural layers:

```
00:00 +0: Local AI Service & Safety Permission Gate Tests Offline Model status declares 100% on-device operation
00:00 +1: Local AI Service & Safety Permission Gate Tests Summarization extracts salient content from document
00:00 +2: Local AI Service & Safety Permission Gate Tests Grammar check identifies typos and produces permission-gated proposals
00:00 +3: Local AI Service & Safety Permission Gate Tests Activity query retrieves document save and event history
00:00 +4: DocumentModel & PageSettingsModel Tests Default page settings have standard A4 dimensions
00:00 +5: DocumentModel & PageSettingsModel Tests Landscape orientation adjusts width and height
00:00 +6: DocumentModel & PageSettingsModel Tests DocumentModel serialization roundtrip
00:00 +7: SQLite Database & Repositories Tests Create, retrieve, search, and delete document
00:00 +8: SQLite Database & Repositories Tests Audit log records activity and queries today activities
00:00 +9: SQLite Database & Repositories Tests Save and query document revisions
00:00 +10: DocxService Tests Generate DOCX bytes produces valid ZIP with word/document.xml
00:03 +11: PdfService Tests Generate PDF from delta JSON returns valid PDF binary data
00:09 +12: DocuCraft App launches successfully to Home Screen
00:11 +13: All tests passed!
```
- `flutter analyze`: **0 issues found** (No errors, no warnings, no linter hints).
- Automated test coverage: **13/13 passing tests**.
