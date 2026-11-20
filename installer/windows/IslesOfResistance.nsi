; Isles of Resistance: Windows installer (NSIS 3)
;
; Built by installer/build_windows.sh. To build by hand:
;   makensis -DARCH=x64|arm64 -DVERSION=1.1.0 -DSRCDIR=/abs/build/windows-x64 \
;            -DOUTFILE=/abs/dist/IslesOfResistance-Setup-x64.exe IslesOfResistance.nsi
;
; SRCDIR must contain IslesOfResistance.exe, IslesOfResistance.pck,
; LICENSE.txt and THIRD-PARTY-NOTICES.txt.
;
; Installs for the current user (no administrator prompt) into
; %LOCALAPPDATA%\Programs\Isles of Resistance, adds Start menu and desktop
; shortcuts and an entry in Settings > Apps. Silent install: /S, and /D=<dir>
; to choose the folder.

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma
RequestExecutionLevel user

!ifndef ARCH | VERSION | SRCDIR | OUTFILE
  !error "Define ARCH (x64 or arm64), VERSION, SRCDIR and OUTFILE."
!endif

!define APPNAME "Isles of Resistance"
!define APPEXE "IslesOfResistance.exe"
!define APPPCK "IslesOfResistance.pck"
!define PUBLISHER "JonathanJiWu"
!define URL "https://github.com/JonathanJiWu/Isles-of-Resistance"
!define RELEASES "https://github.com/JonathanJiWu/Isles-of-Resistance/releases/latest"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\IslesOfResistance"
!define REGKEY "Software\IslesOfResistance"
; Godot keeps saves and settings here (application/config/custom_user_dir_name).
!define USERDATA "$APPDATA\Isles of Resistance"

!if "${ARCH}" == "arm64"
  !define ARCHNAME "ARM64"
  !define ARCHDESC "Windows on ARM (ARM64)"
!else if "${ARCH}" == "x64"
  !define ARCHNAME "x64"
  !define ARCHDESC "64-bit Windows (x64)"
!else
  !error "ARCH must be x64 or arm64"
!endif

Name "${APPNAME}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\${APPNAME}"
InstallDirRegKey HKCU "${REGKEY}" "InstallDir"
BrandingText "${APPNAME} ${VERSION} for ${ARCHDESC}"

VIProductVersion "${VERSION}.0"
VIAddVersionKey "ProductName" "${APPNAME}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}"
VIAddVersionKey "FileDescription" "${APPNAME} Setup (${ARCHNAME})"
VIAddVersionKey "CompanyName" "${PUBLISHER}"
VIAddVersionKey "LegalCopyright" "Copyright (c) 2025 ${PUBLISHER}. MIT License."

!include MUI2.nsh
!include LogicLib.nsh
!include x64.nsh
!include FileFunc.nsh

; ----------------------------------------------------------------- look
!define MUI_ICON "icon.ico"
!define MUI_UNICON "icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "header.bmp"
!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_NODESC

; ----------------------------------------------------------------- pages
!define MUI_WELCOMEPAGE_TITLE "Welcome to ${APPNAME}"
!define MUI_WELCOMEPAGE_TEXT "The Lantern Strait is closed, a carrier group is holding station in the deep, and Tessera's Air Defense Command needs a commander.$\r$\n$\r$\nThis will install ${APPNAME} ${VERSION} for ${ARCHDESC}. It installs for your account only, so no administrator rights are needed.$\r$\n$\r$\nClick Next to continue."
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_TITLE "Ready for duty"
!define MUI_FINISHPAGE_TEXT "${APPNAME} is installed. Captain Ardent has the coffee on.$\r$\n$\r$\nYour saved campaign, Hall of Fame and settings are kept in %APPDATA%\Isles of Resistance."
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APPEXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APPNAME}"
!define MUI_FINISHPAGE_LINK "Project page and updates"
!define MUI_FINISHPAGE_LINK_LOCATION "${URL}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_COMPONENTS
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

; ----------------------------------------------------------------- checks
Function .onInit
  System::Call 'kernel32::CreateMutex(p 0, i 0, t "IslesOfResistanceSetup") p .r1 ?e'
  Pop $R0
  ${If} $R0 = 183
    MessageBox MB_OK|MB_ICONEXCLAMATION "The ${APPNAME} installer is already running." /SD IDOK
    Abort
  ${EndIf}

!if "${ARCH}" == "arm64"
  ${IfNot} ${IsNativeARM64}
    MessageBox MB_OK|MB_ICONSTOP "This is the Windows on ARM (ARM64) installer, but this PC has an Intel or AMD (x64) processor.$\r$\n$\r$\nPlease download IslesOfResistance-Setup-x64.exe from:$\r$\n${RELEASES}" /SD IDOK
    Abort
  ${EndIf}
!else
  ${If} ${IsNativeARM64}
    MessageBox MB_YESNO|MB_ICONINFORMATION "This PC has an ARM processor. The ARM64 installer (IslesOfResistance-Setup-ARM64.exe) runs the game natively and faster:$\r$\n${RELEASES}$\r$\n$\r$\nInstall the x64 version anyway? It will run under emulation." /SD IDYES IDYES arch_ok
    Abort
    arch_ok:
  ${ElseIfNot} ${IsNativeAMD64}
    MessageBox MB_OK|MB_ICONSTOP "${APPNAME} needs 64-bit Windows." /SD IDOK
    Abort
  ${EndIf}
!endif
FunctionEnd

; ----------------------------------------------------------------- install
Section "${APPNAME} (required)" SecGame
  SectionIn RO
  SetOutPath "$INSTDIR"
  File "${SRCDIR}/${APPEXE}"
  File "${SRCDIR}/${APPPCK}"
  File "${SRCDIR}/LICENSE.txt"
  File "${SRCDIR}/THIRD-PARTY-NOTICES.txt"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "${REGKEY}" "InstallDir" "$INSTDIR"
  WriteRegStr HKCU "${REGKEY}" "Architecture" "${ARCHNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTKEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTKEY}" "DisplayIcon" "$INSTDIR\${APPEXE},0"
  WriteRegStr HKCU "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINSTKEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegStr HKCU "${UNINSTKEY}" "URLInfoAbout" "${URL}"
  WriteRegStr HKCU "${UNINSTKEY}" "URLUpdateInfo" "${RELEASES}"
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTKEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "${UNINSTKEY}" "EstimatedSize" "$0"
SectionEnd

Section "Start menu shortcut" SecStartMenu
  CreateShortcut "$SMPROGRAMS\${APPNAME}.lnk" "$INSTDIR\${APPEXE}" "" "$INSTDIR\${APPEXE}" 0 SW_SHOWNORMAL "" "Turn-based air defense in the Lantern Strait"
SectionEnd

Section "Desktop shortcut" SecDesktop
  CreateShortcut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\${APPEXE}" "" "$INSTDIR\${APPEXE}" 0 SW_SHOWNORMAL "" "Turn-based air defense in the Lantern Strait"
SectionEnd

; ----------------------------------------------------------------- uninstall
Section "un.${APPNAME}" UnSecGame
  SectionIn RO
  Delete "$INSTDIR\${APPEXE}"
  Delete "$INSTDIR\${APPPCK}"
  Delete "$INSTDIR\LICENSE.txt"
  Delete "$INSTDIR\THIRD-PARTY-NOTICES.txt"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
  Delete "$SMPROGRAMS\${APPNAME}.lnk"
  Delete "$DESKTOP\${APPNAME}.lnk"
  DeleteRegKey HKCU "${UNINSTKEY}"
  DeleteRegKey HKCU "${REGKEY}"
SectionEnd

Section /o "un.Saved campaign, Hall of Fame and settings" UnSecData
  RMDir /r "${USERDATA}"
SectionEnd
