; Instalador do GoLiveBypass para Windows.
;
; O app oficial so sai como portable (electron-builder "portable"). Este instalador
; NAO recompila o app: ele instala o MESMO exe portable da release oficial num lugar
; fixo (%LOCALAPPDATA%\Programs\GoLiveBypass\GoLiveBypass.exe), com atalhos, entrada em
; "Aplicativos instalados" e inicializacao com o Windows por tarefa agendada.
;
; Como o exe continua sendo o portable oficial, o atualizador embutido continua
; funcionando: ele troca o exe no proprio lugar (PORTABLE_EXECUTABLE_FILE), entao a
; instalacao recebe as versoes novas sozinha e o caminho da tarefa nunca muda.
;
; Build: makensis /DAPP_EXE=<GoLiveBypass-x.y.z.exe> /DAPP_VERSION=x.y.z /DOUT_FILE=<saida> GoLiveBypass-Setup.nsi
; (o build-setup.ps1 ao lado baixa a release, confere o SHA-256 e chama o makensis).

Unicode true
ManifestDPIAware true
SetCompressor /SOLID lzma

!ifndef APP_EXE
  !error "Defina /DAPP_EXE=<caminho do GoLiveBypass-x.y.z.exe>"
!endif
!ifndef APP_VERSION
  !error "Defina /DAPP_VERSION=x.y.z"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "GoLiveBypass-Setup-${APP_VERSION}.exe"
!endif

!define APP_NAME "GoLiveBypass"
!define EXE_NAME "GoLiveBypass.exe"
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\GoLiveBypass"
!define ICON "..\..\golive-gui\build\icon.ico"

Name "${APP_NAME}"
OutFile "${OUT_FILE}"
; Por usuario, sem administrador: o updater do app precisa escrever na pasta.
RequestExecutionLevel user
InstallDir "$LOCALAPPDATA\Programs\GoLiveBypass"
InstallDirRegKey HKCU "${UNINST_KEY}" "InstallLocation"
BrandingText "${APP_NAME} ${APP_VERSION}"

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey "ProductName" "${APP_NAME}"
VIAddVersionKey "FileDescription" "Instalador do ${APP_NAME}"
VIAddVersionKey "FileVersion" "${APP_VERSION}"
VIAddVersionKey "ProductVersion" "${APP_VERSION}"
VIAddVersionKey "LegalCopyright" "GPL-3.0"

!include "MUI2.nsh"
!include "LogicLib.nsh"

!define MUI_ICON "${ICON}"
!define MUI_UNICON "${ICON}"
!define MUI_ABORTWARNING
!define MUI_COMPONENTSPAGE_SMALLDESC
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXE_NAME}"
!define MUI_FINISHPAGE_RUN_TEXT "Abrir o GoLiveBypass agora"
!define MUI_FINISHPAGE_TEXT "O GoLiveBypass foi instalado e vai se atualizar sozinho pelas releases oficiais.$\r$\n$\r$\nSe você marcou Iniciar com o Windows, não precisa ligar a mesma opção dentro do app: o instalador já cuida disso. O Discord abre sozinho no boot quando o bypass estava ligado."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "PortugueseBR"

; Fecha o caminho enquanto o app esta aberto: o exe em uso nao pode ser trocado, e
; matar o processo deixaria o tunel do WireSock e o Discord num estado pela metade.
!macro EsperarAppFechado UN
Function ${UN}EsperarAppFechado
  retry:
    ; O portable sobe como "<nome do exe>" (o stub) e "GoLiveBypass.exe" (o app extraido
    ; no %TEMP%): qualquer processo GoLiveBypass* conta, inclusive um portable antigo.
    nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -Command "if (Get-Process -Name GoLiveBypass* -ErrorAction SilentlyContinue) { exit 10 } else { exit 0 }"'
    Pop $0
    Pop $1
    ${If} $0 == 10
      MessageBox MB_RETRYCANCEL|MB_ICONEXCLAMATION "O GoLiveBypass está aberto.$\r$\n$\r$\nFeche pelo ícone da bandeja (botão direito > Sair) e clique em Repetir." /SD IDCANCEL IDRETRY retry
      Abort
    ${EndIf}
FunctionEnd
!macroend
!insertmacro EsperarAppFechado ""
!insertmacro EsperarAppFechado "un."

Function .onInit
  ; Instalacao anterior: reaproveita a pasta escolhida antes.
  ReadRegStr $0 HKCU "${UNINST_KEY}" "InstallLocation"
  ${If} $0 != ""
    StrCpy $INSTDIR $0
  ${EndIf}
FunctionEnd

Section "GoLiveBypass (obrigatório)" SecApp
  SectionIn RO
  Call EsperarAppFechado
  SetOutPath "$INSTDIR"
  ; Sobra de update anterior do updater portable.
  Delete "$INSTDIR\${EXE_NAME}.old"
  File "/oname=${EXE_NAME}" "${APP_EXE}"
  File "autostart-task.ps1"
  WriteUninstaller "$INSTDIR\Desinstalar.exe"

  CreateShortcut "$SMPROGRAMS\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${EXE_NAME}" 0

  WriteRegStr HKCU "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\${EXE_NAME}"
  ; A versao instalada e a do instalador; o updater do app sobe a versao sozinho.
  WriteRegStr HKCU "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "${UNINST_KEY}" "Publisher" "GoLiveBypass"
  WriteRegStr HKCU "${UNINST_KEY}" "URLInfoAbout" "https://github.com/bezumiya/GoLiveBypass"
  WriteRegStr HKCU "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Desinstalar.exe"'
  WriteRegStr HKCU "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Desinstalar.exe" /S'
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINST_KEY}" "NoRepair" 1
SectionEnd

Section "Iniciar com o Windows (abre o Discord sozinho)" SecAuto
  nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\autostart-task.ps1" -Action install -Exe "$INSTDIR\${EXE_NAME}"'
  Pop $0
  Pop $1
  ${If} $0 != 0
    MessageBox MB_OK|MB_ICONEXCLAMATION "Não consegui criar a inicialização com o Windows:$\r$\n$1$\r$\nO app foi instalado; dá para tentar de novo rodando o instalador outra vez." /SD IDOK
  ${EndIf}
SectionEnd

Section "Atalho na área de trabalho" SecDesk
  CreateShortcut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${EXE_NAME}" "" "$INSTDIR\${EXE_NAME}" 0
SectionEnd

; Reinstalar sem marcar a inicializacao remove a tarefa de uma instalacao anterior.
Section "-SemAutostart"
  ${IfNot} ${SectionIsSelected} ${SecAuto}
    nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\autostart-task.ps1" -Action remove'
    Pop $0
    Pop $1
  ${EndIf}
  ${IfNot} ${SectionIsSelected} ${SecDesk}
    Delete "$DESKTOP\${APP_NAME}.lnk"
  ${EndIf}
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "Instala o app em $LOCALAPPDATA\Programs\GoLiveBypass. Ele se atualiza sozinho pelas releases oficiais."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAuto} "Abre o app na bandeja ao entrar no Windows. Se o bypass estava ligado, ele religa e abre o Discord."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesk} "Cria um atalho na área de trabalho."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

Section "Uninstall"
  Call un.EsperarAppFechado
  nsExec::ExecToStack '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$INSTDIR\autostart-task.ps1" -Action remove'
  Pop $0
  Pop $1
  Delete "$SMPROGRAMS\${APP_NAME}.lnk"
  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$INSTDIR\${EXE_NAME}"
  Delete "$INSTDIR\${EXE_NAME}.old"
  Delete "$INSTDIR\autostart-task.ps1"
  Delete "$INSTDIR\Desinstalar.exe"
  ; Sem /r: so remove a pasta se ficou vazia (nunca apaga o que nao e nosso).
  RMDir "$INSTDIR"
  DeleteRegKey HKCU "${UNINST_KEY}"
  ; Configuracoes, sessao Proton e logs (%LOCALAPPDATA%\GoLiveBypass) ficam: reinstalar
  ; volta com tudo como estava.
SectionEnd
