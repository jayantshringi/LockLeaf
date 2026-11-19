import os
import sys
from reportlab.lib.pagesizes import letter
from reportlab.lib import colors
from reportlab.platypus import (
    SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak, KeepTogether, HRFlowable
)
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

class NumberedCanvas(canvas.Canvas):
    """
    Two-pass canvas to dynamically compute and print total page count 'Page X of Y',
    plus a running header on pages after the cover page.
    """
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_decorations(num_pages)
            super().showPage()
        super().save()

    def draw_page_decorations(self, page_count):
        # Header (Pages 2+)
        if self._pageNumber > 1:
            self.saveState()
            self.setFont('Helvetica-Bold', 8)
            self.setFillColor(colors.HexColor('#0F172A'))
            self.drawString(40, 755, 'LOCKLEAF')
            self.setFont('Helvetica', 8)
            self.setFillColor(colors.HexColor('#64748B'))
            self.drawString(95, 755, '|   Android Production Deployment, Hardware Testing & GitHub Release Guide')
            
            # Subtle header divider rule
            self.setStrokeColor(colors.HexColor('#E2E8F0'))
            self.setLineWidth(0.75)
            self.line(40, 747, 572, 747)
            
            # Footer
            self.line(40, 42, 572, 42)
            self.setFont('Helvetica-Bold', 8)
            self.setFillColor(colors.HexColor('#059669'))
            self.drawString(40, 30, 'LOCKLEAF')
            self.setFont('Helvetica', 8)
            self.setFillColor(colors.HexColor('#64748B'))
            self.drawString(95, 30, '• Zero-Knowledge Password Vault • Version 1.0.0 • Android')
            page_text = f'Page {self._pageNumber} of {page_count}'
            self.drawRightString(572, 30, page_text)
            self.restoreState()
        else:
            # First page footer only
            self.saveState()
            self.setStrokeColor(colors.HexColor('#E2E8F0'))
            self.setLineWidth(0.75)
            self.line(40, 42, 572, 42)
            self.setFont('Helvetica', 8)
            self.setFillColor(colors.HexColor('#64748B'))
            self.drawString(40, 30, 'LockLeaf Android Password Manager — Production Release Documentation')
            page_text = f'Page 1 of {page_count}'
            self.drawRightString(572, 30, page_text)
            self.restoreState()

DOCS_DIR = os.path.dirname(os.path.abspath(__file__))

def build_pdf(filename=None):
    if filename is None:
        filename = os.path.join(DOCS_DIR, 'LockLeaf_Production_And_Publishing_Guide.pdf')
    pdf_path = os.path.abspath(filename)
    
    # 0.75 inch (54 pt) margins on 612 x 792 pt Letter page. Printable width = 504 pt.
    doc = SimpleDocTemplate(
        pdf_path,
        pagesize=letter,
        leftMargin=40,
        rightMargin=40,
        topMargin=54,
        bottomMargin=54
    )
    
    styles = getSampleStyleSheet()
    
    # Custom Palette
    PRIMARY = colors.HexColor('#0F172A')   # Slate 900
    SECONDARY = colors.HexColor('#334155') # Slate 700
    ACCENT = colors.HexColor('#059669')    # Emerald 600
    MUTED = colors.HexColor('#64748B')     # Slate 500
    BORDER = colors.HexColor('#CBD5E1')    # Slate 300
    
    # Typography Styles
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=24,
        leading=28,
        textColor=PRIMARY,
        spaceAfter=6
    )
    
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=12,
        leading=16,
        textColor=ACCENT,
        spaceAfter=14
    )
    
    meta_style = ParagraphStyle(
        'DocMeta',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        leading=13,
        textColor=MUTED,
        spaceAfter=15
    )
    
    h1_style = ParagraphStyle(
        'SectionH1',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=15,
        leading=19,
        textColor=PRIMARY,
        spaceBefore=14,
        spaceAfter=6,
        keepWithNext=True
    )
    
    h2_style = ParagraphStyle(
        'SectionH2',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=12,
        leading=16,
        textColor=ACCENT,
        spaceBefore=10,
        spaceAfter=4,
        keepWithNext=True
    )
    
    body_style = ParagraphStyle(
        'BodyDark',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9.5,
        leading=14,
        textColor=SECONDARY,
        spaceAfter=6
    )

    body_bold = ParagraphStyle(
        'BodyBold',
        parent=body_style,
        fontName='Helvetica-Bold'
    )
    
    bullet_style = ParagraphStyle(
        'BulletText',
        parent=body_style,
        leftIndent=14,
        firstLineIndent=-10,
        spaceAfter=4
    )
    
    code_inline_style = ParagraphStyle(
        'CodeInline',
        parent=styles['Normal'],
        fontName='Courier',
        fontSize=8.5,
        leading=11,
        textColor=colors.HexColor('#0F172A')
    )

    tbl_header = ParagraphStyle(
        'TblHdr',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8.5,
        leading=11,
        textColor=colors.white
    )

    tbl_cell = ParagraphStyle(
        'TblCell',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=8,
        leading=11,
        textColor=PRIMARY
    )

    tbl_cell_bold = ParagraphStyle(
        'TblCellBold',
        parent=tbl_cell,
        fontName='Helvetica-Bold'
    )

    story = []
    
    def add_callout(title, text, kind='tip'):
        bg_color = colors.HexColor('#ECFDF5') if kind == 'tip' else (colors.HexColor('#EFF6FF') if kind == 'note' else colors.HexColor('#FFFBEB'))
        border_color = colors.HexColor('#10B981') if kind == 'tip' else (colors.HexColor('#3B82F6') if kind == 'note' else colors.HexColor('#F59E0B'))
        title_color = colors.HexColor('#065F46') if kind == 'tip' else (colors.HexColor('#1E40AF') if kind == 'note' else colors.HexColor('#92400E'))
        
        c_title = Paragraph(f"<b>{title.upper()}</b>", ParagraphStyle('CTitle', parent=styles['Normal'], fontName='Helvetica-Bold', fontSize=8.5, leading=11, textColor=title_color))
        c_text = Paragraph(text, ParagraphStyle('CText', parent=body_style, fontSize=8.5, leading=12, textColor=PRIMARY, spaceAfter=0))
        
        t = Table([[c_title], [c_text]], colWidths=[532])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), bg_color),
            ('BOX', (0,0), (-1,-1), 1, border_color),
            ('TOPPADDING', (0,0), (-1,-1), 6),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
            ('LEFTPADDING', (0,0), (-1,-1), 10),
            ('RIGHTPADDING', (0,0), (-1,-1), 10),
        ]))
        story.append(Spacer(1, 4))
        story.append(t)
        story.append(Spacer(1, 6))

    def add_code(code_str):
        p = Paragraph(code_str.replace('\n', '<br/>').replace(' ', '&nbsp;'), code_inline_style)
        t = Table([[p]], colWidths=[532])
        t.setStyle(TableStyle([
            ('BACKGROUND', (0,0), (-1,-1), colors.HexColor('#F8FAFC')),
            ('BOX', (0,0), (-1,-1), 0.75, colors.HexColor('#CBD5E1')),
            ('TOPPADDING', (0,0), (-1,-1), 6),
            ('BOTTOMPADDING', (0,0), (-1,-1), 6),
            ('LEFTPADDING', (0,0), (-1,-1), 10),
            ('RIGHTPADDING', (0,0), (-1,-1), 10),
        ]))
        story.append(Spacer(1, 3))
        story.append(t)
        story.append(Spacer(1, 5))

    # =========================================================================
    # DOCUMENT COVER / HEADER
    # =========================================================================
    story.append(Paragraph("LockLeaf Android Password Manager", title_style))
    story.append(Paragraph("Android Production Deployment, Hardware Testing & GitHub Release Guide", subtitle_style))
    story.append(Paragraph("<b>Version:</b> 1.0.0 &nbsp;|&nbsp; <b>Status:</b> Production Ready &nbsp;|&nbsp; <b>Automated Tests:</b> 193 Passing (100% Green) &nbsp;|&nbsp; <b>Platform:</b> Android Exclusively", meta_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=ACCENT, spaceBefore=0, spaceAfter=12))

    # =========================================================================
    # SECTION 1: EXECUTIVE SUMMARY & CURRENT ARCHITECTURE
    # =========================================================================
    story.append(Paragraph("1. Executive Overview & Completed Development", h1_style))
    story.append(Paragraph(
        "<b>What is LockLeaf?</b> LockLeaf is an open-source, client-side encrypted password manager and 2FA authenticator built specifically for Android. "
        "It operates on a strict <b>Zero-Knowledge Architecture</b>: all encryption keys and master secrets are derived directly on your Android device using "
        "Argon2id and XChaCha20-Poly1305. The cloud backend only ever stores unreadable cryptographic ciphertexts; neither servers, developers, nor network eavesdroppers can ever read your vault records.",
        body_style
    ))
    story.append(Paragraph(
        "<b>Current Status:</b> All 10 architectural phases have been fully implemented, reviewed, tested, and merged into the <code>main</code> branch of the repository. "
        "A total of 193 automated unit, integration, widget, and security audit tests run in GitHub Actions CI with zero errors and zero warnings. "
        "The project has now transitioned from coding into <b>Physical Device Validation and Release Distribution</b>. <i>(Note: iOS native support is placed on hold for future expansion; LockLeaf is currently targeted exclusively for Android).</i>",
        body_style
    ))

    # Completed Phases Summary Table
    phase_data = [
        [Paragraph("Phase", tbl_header), Paragraph("Component", tbl_header), Paragraph("Key Security & Architecture Features", tbl_header), Paragraph("Status", tbl_header)],
        [Paragraph("Phase 1", tbl_cell_bold), Paragraph("Project Foundation", tbl_cell), Paragraph("Flutter 3 setup, strict linter rules, GitHub Actions CI workflow", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 2", tbl_cell_bold), Paragraph("Cryptographic Core", tbl_cell), Paragraph("Argon2id KDF (memory-hard), XChaCha20-Poly1305 AEAD, HKDF subkeys", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 3", tbl_cell_bold), Paragraph("Encrypted Vault Logic", tbl_cell), Paragraph("Local SQLite database enclave, zero-knowledge CRUD, domain entities", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 4", tbl_cell_bold), Paragraph("Auth & User Interface", tbl_cell), Paragraph("Master password onboarding, unlock flow, vault cards, search, themes", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 5", tbl_cell_bold), Paragraph("Device Enclave Security", tbl_cell), Paragraph("Hardware Keystore, Biometrics, Screen Shield, 30s clipboard wipe", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 6", tbl_cell_bold), Paragraph("Security Tools", tbl_cell), Paragraph("CSPRNG Password generator, Diceware passphrase, local vault health analyzer", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 7", tbl_cell_bold), Paragraph("Backup & Disaster Recovery", tbl_cell), Paragraph("Password-protected .llbak files, Crockford Base32 recovery keys with checksum", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 8", tbl_cell_bold), Paragraph("Zero-Knowledge Cloud Sync", tbl_cell), Paragraph("Ciphertext REST transport, Last-Write-Wins (LWW) resolver, deletion tombstones", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 9", tbl_cell_bold), Paragraph("Hardening & Security Audit", tbl_cell), Paragraph("Anti-brute force exponential lockout, RFC 6238 TOTP 2FA engine, memory zeroing", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
        [Paragraph("Phase 10", tbl_cell_bold), Paragraph("Production Release Assets", tbl_cell), Paragraph("ProGuard/R8 rules, native launch screens, SVG launcher icons, version 1.0.0", tbl_cell), Paragraph("Completed", tbl_cell_bold)],
    ]
    t_phase = Table(phase_data, colWidths=[55, 95, 310, 72])
    t_phase.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')]),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_phase)
    story.append(Spacer(1, 10))

    # =========================================================================
    # SECTION 2: STEP-BY-STEP PUBLISHING ROADMAP
    # =========================================================================
    story.append(PageBreak())
    story.append(Paragraph("2. Step-by-Step Production Roadmap (Step 1 to End)", h1_style))
    story.append(Paragraph(
        "This section explains in plain, easy-to-understand language every single step required to take the LockLeaf code from your computer, "
        "compile the production Android APK, test it on physical hardware, and distribute it via GitHub Releases and the Google Play Store.",
        body_style
    ))
    story.append(Spacer(1, 4))

    # --- STEP 1 ---
    story.append(Paragraph("Step 1: Setting Up the Local Build Environment", h2_style))
    story.append(Paragraph(
        "<b>What is this step?</b> Before your computer can turn source code into an installable mobile app, you must install the official programming tools (SDKs and compilers). "
        "Think of this as setting up your digital workshop before building the physical product.",
        body_style
    ))
    story.append(Paragraph("<b>Required Actions:</b>", body_bold))
    story.append(Paragraph("• <b>Install Flutter SDK:</b> Download Flutter (stable channel) and extract it to your system (e.g. <code>C:\\src\\flutter</code> on Windows). Add its <code>bin</code> folder to your system PATH.", bullet_style))
    story.append(Paragraph("• <b>Install Java JDK 17:</b> Android build systems require Java. Install Eclipse Temurin JDK 17 or OpenJDK 17.", bullet_style))
    story.append(Paragraph("• <b>Install Android Studio:</b> Install Android Studio to get the Android SDK, platform-tools (ADB), and SDK build-tools (version 34+).", bullet_style))
    story.append(Paragraph("• <b>Verify Your Environment:</b> Open your terminal / command prompt and run:", bullet_style))
    add_code("flutter doctor -v\nflutter pub get\nflutter test")
    story.append(Paragraph(
        "<b>What to expect:</b> <code>flutter doctor</code> will display green checkmarks for Flutter and Android toolchain. "
        "<code>flutter test</code> will run all 193 unit and widget tests, concluding with: <i>'All tests passed!'</i>.",
        body_style
    ))
    add_callout("Tip", "Always run 'flutter test' before generating release builds. This gives you mathematical proof that no encryption logic or rate limiting features were accidentally altered.", "tip")

    # --- STEP 2 ---
    story.append(Spacer(1, 6))
    story.append(Paragraph("Step 2: Android Cryptographic Signing & Keystore Setup", h2_style))
    story.append(Paragraph(
        "<b>What is this step?</b> Android requires every app to be digitally signed with a private cryptographic certificate called a <b>Keystore</b>. "
        "This certificate acts as your digital wax seal. It guarantees to Android phones that the app was genuinely created by you, and prevents any unauthorized person from releasing a fake update.",
        body_style
    ))
    story.append(Paragraph("<b>Action A: Generate Your Private Keystore</b>", body_bold))
    story.append(Paragraph("Open terminal in the project root directory and run the standard key generation tool (included with Java):", body_style))
    add_code("keytool -genkey -v -keystore android/upload-keystore.jks \\\n        -keyalg RSA -keysize 2048 -validity 10000 -alias upload")
    story.append(Paragraph(
        "The command will ask you a few questions: choose a strong password (at least 16 characters), enter your name or organization name, and confirm. "
        "This creates a file named <code>android/upload-keystore.jks</code>.",
        body_style
    ))
    story.append(Paragraph("<b>Action B: Configure Secret Gradle Properties</b>", body_bold))
    story.append(Paragraph(
        "Create a text file at <code>android/key.properties</code>. This tells the Android compiler where your key is and what passwords to use without putting secrets in your code. "
        "<i>(Note: This file is already configured in <code>.gitignore</code> so it will NEVER be uploaded to git!)</i>",
        body_style
    ))
    add_code("storePassword=YOUR_KEYSTORE_PASSWORD_HERE\nkeyPassword=YOUR_KEY_PASSWORD_HERE\nkeyAlias=upload\nstoreFile=../upload-keystore.jks")
    add_callout(
        "Critical Warning: Protect Your Keystore",
        "Save a secure backup of 'upload-keystore.jks' in a safe location (e.g. an offline encrypted USB drive or secure cloud backup). "
        "If you lose this keystore file, Google Play will permanently reject all future app updates, and you would be forced to publish under a completely new app identifier!",
        "warning"
    )

    # --- STEP 3 ---
    story.append(Spacer(1, 8))
    story.append(Paragraph("Step 3: Direct Android Distribution (GitHub Releases) vs. Google Play", h2_style))
    story.append(Paragraph(
        "LockLeaf gives you two flexible ways to distribute your app to Android users:",
        body_style
    ))
    story.append(Paragraph("<b>Option A: Direct GitHub Releases (100% Free & Immediate):</b>", body_bold))
    story.append(Paragraph("• No $25 Google Play registration fee and zero review delays.", bullet_style))
    story.append(Paragraph("• Users download <b>Lock Leaf.apk</b> directly from your GitHub Releases page and install with 1 tap.", bullet_style))
    story.append(Paragraph("• Highly popular for open-source privacy and security apps (like Aegis, Signal, and KeePassDX).", bullet_style))
    story.append(Paragraph("<b>Option B: Google Play Store Publication:</b>", body_bold))
    story.append(Paragraph("• Publish the Android App Bundle (<code>app-release.aab</code>) via the Google Play Console ($25 one-time fee).", bullet_style))
    story.append(Paragraph("• Provides automated updates and discovery directly within the Google Play Store.", bullet_style))
    story.append(Paragraph("<i>(Note: iOS native distribution is placed on hold; current release targets Android users exclusively).</i>", body_style))

    # --- STEP 4 ---
    story.append(Spacer(1, 6))
    story.append(Paragraph("Step 4: Physical Device Testing (The 6 Field Tests)", h2_style))
    story.append(Paragraph(
        "<b>Why Test on Real Android Phones?</b> Software emulators running on a PC only simulate screen pixels—they <i>cannot</i> simulate physical hardware security chips "
        "(such as the Android Titan M Keystore). Because LockLeaf is a high-security vault, you must test on actual physical devices.",
        body_style
    ))
    
    test_checklist = [
        [Paragraph("Field Test", tbl_header), Paragraph("Procedure", tbl_header), Paragraph("Expected Result (Pass Criteria)", tbl_header)],
        [
            Paragraph("1. Biometric Unlock", tbl_cell_bold),
            Paragraph("Enable biometrics in LockLeaf Settings. Lock the app or kill it from memory. Reopen the app.", tbl_cell),
            Paragraph("The native fingerprint/Face prompt appears. Authenticating unlocks the vault instantly without typing master password.", tbl_cell)
        ],
        [
            Paragraph("2. Screen Obscuring (Privacy Shield)", tbl_cell_bold),
            Paragraph("With the vault open to sensitive passwords, swipe up to the phone's recent apps / multitasking switcher.", tbl_cell),
            Paragraph("The app window thumbnail appears completely blank/obscured. No passwords or usernames can be seen or screen-captured.", tbl_cell)
        ],
        [
            Paragraph("3. 30s Clipboard Auto-Scrub", tbl_cell_bold),
            Paragraph("Tap 'Copy Password' on any entry. Paste it into a text note. Wait exactly 35 seconds and try pasting again.", tbl_cell),
            Paragraph("The clipboard is automatically cleared by the background timer. The second paste attempt is blank, preventing credential theft.", tbl_cell)
        ],
        [
            Paragraph("4. RFC 6238 2FA Authenticator", tbl_cell_bold),
            Paragraph("Add a real two-factor authentication key (from GitHub, Google, etc.). Check the rolling 6-digit code.", tbl_cell),
            Paragraph("The animated circular progress timer updates every 30 seconds. Entering the code into the website logs in successfully.", tbl_cell)
        ],
        [
            Paragraph("5. Offline-First & Cloud Sync", tbl_cell_bold),
            Paragraph("Enable Airplane Mode. Create and edit vault entries. Turn Airplane Mode off and trigger cloud sync.", tbl_cell),
            Paragraph("Entries persist immediately in local SQLite while offline, and seamlessly upload as encrypted AEAD envelopes once online.", tbl_cell)
        ],
        [
            Paragraph("6. Backup & Recovery Key", tbl_cell_bold),
            Paragraph("Export a password-protected .llbak backup file. Clear app data. Restore from backup and enter recovery key.", tbl_cell),
            Paragraph("All vault records, 2FA tokens, and custom fields restore with 100% mathematical integrity.", tbl_cell)
        ],
    ]
    t_test = Table(test_checklist, colWidths=[95, 205, 232])
    t_test.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')]),
        ('TOPPADDING', (0,0), (-1,-1), 5),
        ('BOTTOMPADDING', (0,0), (-1,-1), 5),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_test)
    story.append(Spacer(1, 8))

    # --- STEP 5 ---
    story.append(Spacer(1, 8))
    story.append(Paragraph("Step 5: Compiling Official Android Release Binaries", h2_style))
    story.append(Paragraph(
        "<b>What is this step?</b> This is where your code is compiled into the final, compressed, optimized files ready to be installed on Android devices or uploaded to app stores.",
        body_style
    ))
    story.append(Paragraph("<b>Building the Standalone Android APK (Lock Leaf.apk)</b>", body_bold))
    story.append(Paragraph(
        "GitHub Actions automatically compiles this on every commit and packages it as <b>Lock Leaf.apk</b> inside the release artifact zip. "
        "You can also compile it locally with the following command:",
        body_style
    ))
    add_code("flutter build apk --release --android-skip-build-dependency-validation")
    story.append(Paragraph(
        "<b>Output location:</b> <code>build/app/outputs/flutter-apk/app-release.apk</code> (renamed to <b>Lock Leaf.apk</b> for release distribution).",
        body_style
    ))
    story.append(Spacer(1, 4))
    story.append(Paragraph("<b>Building the Android App Bundle (.aab) for Google Play</b>", body_bold))
    story.append(Paragraph("If publishing through the Google Play Console, compile the optimized App Bundle:", body_style))
    add_code("flutter build appbundle --release --android-skip-build-dependency-validation")
    story.append(Paragraph(
        "<b>Output location:</b> <code>build/app/outputs/bundle/release/app-release.aab</code>.",
        body_style
    ))

    # --- STEP 6 ---
    story.append(Spacer(1, 6))
    story.append(Paragraph("Step 6: Setting Up GitHub Releases & Google Play Listings", h2_style))
    story.append(Paragraph("<b>A. Publishing to GitHub Releases (Recommended for Immediate Launch):</b>", body_bold))
    story.append(Paragraph("1. Navigate to <b>https://github.com/jayantshringi/LockLeaf/releases</b>.", bullet_style))
    story.append(Paragraph("2. Click <b>Draft a new release</b>, set tag to <code>v1.0.0</code>, title to <b>LockLeaf v1.0.0 Production Release</b>.", bullet_style))
    story.append(Paragraph("3. Attach <b>Lock Leaf.apk</b> and publish. Users can download and install directly on their phones immediately.", bullet_style))
    story.append(Spacer(1, 4))
    story.append(Paragraph("<b>B. Google Play Console Setup (Optional):</b>", body_bold))
    story.append(Paragraph("1. Register at <b>play.google.com/console</b> ($25 one-time fee).", bullet_style))
    story.append(Paragraph("2. Create App: <i>LockLeaf: Password Manager</i>, Category: Tools / Productivity, Free.", bullet_style))
    story.append(Paragraph("3. Complete Data Safety Form: Declare that all vault data is encrypted in transit and at rest, and encryption keys never leave the device.", bullet_style))
    story.append(Paragraph("4. Upload 512x512 app icon (generated from <code>assets/lockleaf-icon.svg</code>), feature graphic, and phone screenshots.", bullet_style))

    # --- STEP 7 & 8 ---
    story.append(Spacer(1, 8))
    story.append(Paragraph("Step 7: Publishing Tracks & Rollout Strategy", h2_style))
    story.append(Paragraph("• <b>Internal Testing:</b> Download <b>Lock Leaf.apk</b> directly and test across multiple Android devices (Samsung, Google Pixel, Xiaomi, OnePlus).", bullet_style))
    story.append(Paragraph("• <b>Public Launch:</b> Publish the verified <b>Lock Leaf.apk</b> on GitHub Releases along with cryptographic SHA-256 checksums.", bullet_style))
    story.append(Spacer(1, 6))

    story.append(Paragraph("Step 8: Post-Launch Monitoring & Maintenance", h2_style))
    story.append(Paragraph("• <b>Crash Monitoring:</b> Verify error logs and handle user feedback via GitHub Issues.", bullet_style))
    story.append(Paragraph("• <b>Security Disclosures:</b> Maintain the security reporting email in <code>SECURITY.md</code>.", bullet_style))
    story.append(Paragraph("• <b>Dependency Updates:</b> Routinely verify dependencies with <code>flutter pub outdated</code>.", bullet_style))
    story.append(Spacer(1, 10))

    # =========================================================================
    # SECTION 3: COMPLETE REQUIREMENTS LIST (WHAT YOU NEED)
    # =========================================================================
    story.append(PageBreak())
    story.append(Paragraph("3. Complete Android Requirements Checklist", h1_style))
    story.append(HRFlowable(width="100%", thickness=1.5, color=ACCENT, spaceBefore=4, spaceAfter=10))
    story.append(Paragraph(
        "Here is the transparent checklist of everything needed to build, test, and release LockLeaf for Android. "
        "Notice that because LockLeaf is currently focused exclusively on Android and GitHub Releases, the entire development and release workflow is <b>100% FREE ($0)</b>.",
        body_style
    ))
    story.append(Spacer(1, 4))

    req_data = [
        [Paragraph("Category", tbl_header), Paragraph("Item / Tool", tbl_header), Paragraph("Why It Is Needed & Specific Role", tbl_header), Paragraph("Cost", tbl_header), Paragraph("Requirement", tbl_header)],
        
        # Hardware
        [Paragraph("Hardware", tbl_cell_bold), Paragraph("PC or Laptop<br/>(Windows, Linux or Mac)", tbl_cell), Paragraph("Primary workstation to edit code, run Flutter CLI, run local tests, and manage GitHub releases. (8GB+ RAM required, 16GB recommended).", tbl_cell), Paragraph("Already Own", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
        [Paragraph("Hardware", tbl_cell_bold), Paragraph("Physical Android Device<br/>(Phone or Tablet)", tbl_cell), Paragraph("Running Android 10 or higher with a hardware fingerprint scanner or biometric sensor. Needed to test BiometricPrompt, Secure Keystore, and Screen Obscuring.", tbl_cell), Paragraph("Already Own", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
        [Paragraph("Hardware", tbl_cell_bold), Paragraph("High-Speed USB Cable", tbl_cell), Paragraph("USB-C or micro-USB data cable to connect your Android phone to your PC for ADB debugging or transferring the APK.", tbl_cell), Paragraph("Already Own", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],

        # Software
        [Paragraph("Software", tbl_cell_bold), Paragraph("Flutter SDK (v3.24+)", tbl_cell), Paragraph("The core cross-platform framework that compiles your Dart code into native ARM64 machine code for Android.", tbl_cell), Paragraph("Free / Open Source", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
        [Paragraph("Software", tbl_cell_bold), Paragraph("Java JDK 17", tbl_cell), Paragraph("Required by Android Gradle build plugin to compile Java/Kotlin wrappers and run the 'keytool' keystore generator.", tbl_cell), Paragraph("Free / Open Source", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
        [Paragraph("Software", tbl_cell_bold), Paragraph("Android Studio & SDK", tbl_cell), Paragraph("Provides Android SDK platform-tools (ADB), build-tools (version 34+), and Android platform components.", tbl_cell), Paragraph("Free", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
        [Paragraph("Software", tbl_cell_bold), Paragraph("VS Code / Cursor IDE", tbl_cell), Paragraph("Lightweight source code editor with Flutter & Dart extensions for day-to-day coding and terminal task execution.", tbl_cell), Paragraph("Free", tbl_cell), Paragraph("Recommended", tbl_cell_bold)],

        # Accounts
        [Paragraph("Accounts", tbl_cell_bold), Paragraph("GitHub Account", tbl_cell), Paragraph("Hosts your source code repository, runs GitHub Actions CI/CD automated test workflows, and distributes the release APK.", tbl_cell), Paragraph("Free ($0)", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
        [Paragraph("Accounts", tbl_cell_bold), Paragraph("Google Play Developer Account", tbl_cell), Paragraph("Only required if you choose to list LockLeaf on the Google Play Store (optional; GitHub Releases is free).", tbl_cell), Paragraph("$25 USD<br/>(One-time, optional)", tbl_cell), Paragraph("Optional", tbl_cell_bold)],
        [Paragraph("Web Hosting", tbl_cell_bold), Paragraph("Privacy Policy Webpage", tbl_cell), Paragraph("Public webpage detailing zero-knowledge client-side encryption (hosted for free via GitHub Pages).", tbl_cell), Paragraph("Free ($0)", tbl_cell), Paragraph("Mandatory", tbl_cell_bold)],
    ]

    t_req = Table(req_data, colWidths=[65, 100, 222, 65, 80])
    t_req.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'TOP'),
        ('GRID', (0,0), (-1,-1), 0.5, BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')]),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 5),
        ('RIGHTPADDING', (0,0), (-1,-1), 5),
    ]))
    story.append(t_req)
    story.append(Spacer(1, 10))

    # Final summary box & FAQ
    story.append(Paragraph("4. Essential Command Cheat Sheet", h1_style))
    story.append(Paragraph("Keep these core terminal commands handy during your Android release workflow:", body_style))
    
    cmd_data = [
        [Paragraph("Task / Goal", tbl_header), Paragraph("Terminal Command", tbl_header), Paragraph("Purpose", tbl_header)],
        [Paragraph("Health Check", tbl_cell_bold), Paragraph("<code>flutter doctor -v</code>", tbl_cell), Paragraph("Verifies Flutter, Java, and Android SDK setups.", tbl_cell)],
        [Paragraph("Run All Tests", tbl_cell_bold), Paragraph("<code>flutter test</code>", tbl_cell), Paragraph("Executes all 193 tests ensuring zero regressions.", tbl_cell)],
        [Paragraph("Create Keystore", tbl_cell_bold), Paragraph("<code>keytool -genkey -v ...</code>", tbl_cell), Paragraph("Generates Android release signing certificate.", tbl_cell)],
        [Paragraph("Build Release APK", tbl_cell_bold), Paragraph("<code>flutter build apk --release</code>", tbl_cell), Paragraph("Generates standalone APK for GitHub Releases.", tbl_cell)],
        [Paragraph("Build Android AAB", tbl_cell_bold), Paragraph("<code>flutter build appbundle --release</code>", tbl_cell), Paragraph("Generates store-ready bundle for Google Play.", tbl_cell)],
        [Paragraph("Clean Build Cache", tbl_cell_bold), Paragraph("<code>flutter clean &amp;&amp; flutter pub get</code>", tbl_cell), Paragraph("Resets temporary caches if a build ever fails.", tbl_cell)],
    ]
    t_cmd = Table(cmd_data, colWidths=[95, 195, 242])
    t_cmd.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,0), PRIMARY),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('GRID', (0,0), (-1,-1), 0.5, BORDER),
        ('ROWBACKGROUNDS', (0,1), (-1,-1), [colors.white, colors.HexColor('#F8FAFC')]),
        ('TOPPADDING', (0,0), (-1,-1), 4),
        ('BOTTOMPADDING', (0,0), (-1,-1), 4),
        ('LEFTPADDING', (0,0), (-1,-1), 6),
        ('RIGHTPADDING', (0,0), (-1,-1), 6),
    ]))
    story.append(t_cmd)
    story.append(Spacer(1, 10))

    story.append(Paragraph("5. Summary: What You Can Do Right Now", h2_style))
    story.append(Paragraph(
        "1. <b>Download and Test on Phone:</b> Download <b>LockLeaf-Android-Release-APK.zip</b> from GitHub Actions. Extract <b>Lock Leaf.apk</b> and install it on your Android phone.<br/>"
        "2. <b>Verify App Icon & Branding:</b> Confirm that the custom launcher icon (generated from <code>assets/lockleaf-icon.svg</code>) displays beautifully on your Android home screen.<br/>"
        "3. <b>Zero Cost ($0):</b> Releasing directly on GitHub requires no developer subscription, no Apple hardware, and no store approval delays.<br/>"
        "4. <b>Version Locked at 1.0.0:</b> The version is preserved at 1.0.0 with 100% test coverage ready for launch.",
        body_style
    ))
    add_callout("Ready for Launch", "LockLeaf is an enterprise-grade, zero-knowledge Android password manager. Follow the steps in this guide to test on your phone and publish to GitHub Releases!", "tip")

    # Build the document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Successfully generated PDF: {pdf_path}")
    print(f"File size: {os.path.getsize(pdf_path):,} bytes")

if __name__ == '__main__':
    build_pdf()
