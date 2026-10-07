; PEmenu - A GUI version of PEbasic
; Developed by MatQuasar (aka fliermate) - Apr 2025
;
; Dedicated to SherpaSecMy
;
; Version history: v0.01 - Initial release
;                  v0.02 - Bug fix: DOS EXE wrongly reported as PE file after opening a PE file
;
format PE GUI 4.0
include 'win32a.inc'

IDR_MENU = 37
IDM_LOAD   = 101
IDM_EXIT  = 102
IDM_ABOUT = 901
IDD_MAIN = 100
IDC_FILE=200
IDC_BITNESS=201
IDC_SUBSYSTEM=202

PE32 = 0x10b
PE64 = 0x20b
IMAGE_SUBSYSTEM_WINDOWS_GUI = 2
IMAGE_SUBSYSTEM_WINDOWS_CUI = 3
Offset_MagicNumber = 0x98 - 0x80
Offset_Subsystem = 0xDC - 0x80

section '.text' code readable executable

entry $

        invoke  GetModuleHandle,0
        invoke  DialogBoxParam,eax,IDD_MAIN,HWND_DESKTOP,DialogProc,0
        invoke  ExitProcess,0

proc DialogProc hwnd,wmsg,wparam,lparam
        push    ebx esi edi
        mov     eax,[wmsg]
        cmp     eax,WM_INITDIALOG
        je      .wminitdialog
        cmp     eax,WM_COMMAND
        je      .wmcommand
        cmp     eax,WM_CLOSE
        je      .wmclose
        xor     eax,eax
        jmp     .finish
  .wminitdialog:
        jmp     .processed
  .wmcommand:
        mov     eax,[wparam]
        and     eax,0FFFFh
        cmp     eax,IDM_LOAD
        je      .load
        cmp     eax,IDM_ABOUT
        je      .about
        cmp     eax,IDM_EXIT
        je      .wmclose
        jmp     .processed
      .load:
        invoke  GetOpenFileName, _ofn
        or      eax, eax
        jz      .processed

        invoke  CreateFile, _filename, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0
        mov     dword [_handle], eax
        cmp     eax, INVALID_HANDLE_VALUE
        je      .err1

        invoke  ReadFile, dword [_handle], _MZ_ID_r, 2, _dummy, 0
        movzx   ebx, word [_MZ_ID_r]
        cmp     bx, word [_MZ_ID]
        jnz     .err4
        mov     dword [_PE_ID_r], 0
        invoke  SetFilePointer, dword [_handle], 0x3C, 0, FILE_BEGIN
        invoke  ReadFile, dword [_handle], _PE_start, 4, _dummy, 0
        invoke  SetFilePointer, dword [_handle], dword [_PE_start], 0, FILE_BEGIN
        invoke  ReadFile, dword [_handle], _PE_ID_r, 4, _dummy, 0
        mov     ebx, dword [_PE_ID_r]
        cmp     ebx, dword [_PE_ID]
        jnz     .err5
        mov     ebx, dword [_PE_start]
        add     ebx, Offset_MagicNumber
        mov     [_offset], ebx
        invoke  SetFilePointer, dword [_handle], dword [_offset] , 0, FILE_BEGIN
        invoke  ReadFile, dword [_handle], _magic, 2, _dummy, 0
        movzx   ebx, word [_magic]
        cmp     ebx, PE32
        jz      .isPE32
        invoke  SetDlgItemText,[hwnd],IDC_BITNESS,_msg7
        jmp     .continue
  .isPE32:
        invoke  SetDlgItemText,[hwnd],IDC_BITNESS,_msg6
  .continue:
        mov     ebx, dword [_PE_start]
        add     ebx, Offset_Subsystem
        mov     [_offset], ebx
        invoke  SetFilePointer, dword [_handle], dword [_offset] , 0, FILE_BEGIN
        invoke  ReadFile, dword [_handle], _subsystem, 2, _dummy, 0
        movzx   ebx, word [_subsystem]
        cmp     ebx, IMAGE_SUBSYSTEM_WINDOWS_CUI
        jz      .isCUI
        cmp     ebx, IMAGE_SUBSYSTEM_WINDOWS_GUI
        jz      .isGUI
        invoke  SetDlgItemText,[hwnd],IDC_SUBSYSTEM,_msg10
        jmp     .done
  .isCUI:
        invoke  SetDlgItemText,[hwnd],IDC_SUBSYSTEM,_msg8
        jmp     .done
  .isGUI:
        invoke  SetDlgItemText,[hwnd],IDC_SUBSYSTEM,_msg9
  .done:
        invoke  CloseHandle, dword [_handle]
        jmp     .quit
  .err1:
        invoke  MessageBox,[hwnd],_error_text,_about_title,MB_OK
        jmp     .quit
  .err4:
        invoke  CloseHandle, dword [_handle]
        invoke  SetDlgItemText,[hwnd],IDC_BITNESS,_msg4
        invoke  SetDlgItemText,[hwnd],IDC_SUBSYSTEM,_msg4
        jmp     .quit
  .err5:
        invoke  CloseHandle, dword [_handle]
        invoke  SetDlgItemText,[hwnd],IDC_BITNESS,_msg5
        invoke  SetDlgItemText,[hwnd],IDC_SUBSYSTEM,_msg5
        jmp     .quit

  .quit:
        invoke  SetDlgItemText,[hwnd],IDC_FILE,_filename
        jmp     .processed

      .about:
        invoke  MessageBox,[hwnd],_about_text,_about_title,MB_OK
        jmp     .processed
  .wmclose:
        invoke  EndDialog,[hwnd],0
        xor     eax,eax
  .processed:
        mov     eax,1
  .finish:
        pop     edi esi ebx
        ret
endp

section '.data' data readable writeable

  struct OPENFILENAME
    SizeOf     dd  sizeof.OPENFILENAME
    Res0       rd  2
    Filter     dd  _filter
    Res1       rd  3
    FileName   dd  _filename
    MaxFile    dd  512
    Res2       rd  4
    ofnFlags   dd  OFN_EXPLORER
    Res3       rd  5
  ends

  _ofn          OPENFILENAME
  _filter       db  'Executables (exe, dll, sys, ocx, scr)',0
                db  '*.exe;*.dll;*.sys;*.ocx;*.scr',0,0
  _subsystem    dd ?
  _handle       dd ?
  _dummy        dd ?
  _offset       dd 0
  _PE_start     dd ?
  _PE_ID_r      rb 4
  _PE_ID        db 'P','E',0,0
  _MZ_ID_r      rb 2
  _MZ_ID        db 'M','Z'
  _magic        dw ?

  _msg4         db 'Invalid executable file.',0
  _msg5         db 'PE header not found.',0
  _msg6         db '32-bit',0
  _msg7         db '64-bit',0
  _msg8         db 'Console App',0
  _msg9         db 'GUI App',0
  _msg10        db 'PE file',0

  _about_title  TCHAR 'PEmenu',0
  _error_text   TCHAR 'Error opening file.',0
  _about_text   TCHAR 'This is a GUI version of PEbasic developed by MatQuasar (aka fliermate) - Apr 2025',0
  _filename     rb  MAX_PATH

section '.idata' import data readable writeable

  library kernel,'KERNEL32.DLL',\
          user,'USER32.DLL',\
          comdlg32, 'COMDLG32.DLL'

  import kernel,\
         GetModuleHandle,'GetModuleHandleA',\
         CreateFile, 'CreateFileA', \
         ReadFile, 'ReadFile', \
         CloseHandle, 'CloseHandle', \
         SetFilePointer, 'SetFilePointer', \
         ExitProcess,'ExitProcess'

  import user,\
         DialogBoxParam,'DialogBoxParamA',\
         EndDialog,'EndDialog' ,\
         SetDlgItemText,'SetDlgItemTextA',\
         GetDlgItemText,'GetDlgItemTextA',\
         GetDlgItem,'GetDlgItem',\
         SendMessage,'SendMessageA',\
         MessageBox,'MessageBoxA'

  import comdlg32, GetOpenFileName,'GetOpenFileNameA'

section '.rsrc' resource data readable

  directory RT_DIALOG,dialogs,\
            RT_MENU,menus, \
            RT_VERSION,versions, \
            24,manifest

  resource dialogs,\
           IDD_MAIN,LANG_ENGLISH+SUBLANG_DEFAULT,main_dialog

  resource menus,\
           IDR_MENU,LANG_ENGLISH+SUBLANG_DEFAULT,main_menu

  resource versions,\
           1,LANG_NEUTRAL,version

  resource  manifest,\
            1, LANG_NEUTRAL, winxp

  dialog main_dialog,'PEmenu',100,100,400,80,WS_CAPTION+WS_POPUP+WS_SYSMENU+DS_MODALFRAME,0,IDR_MENU
     dialogitem 'STATIC','File: ',-1,10,10,70,15,WS_VISIBLE
     dialogitem 'EDIT','',IDC_FILE,80,10,300,15,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_AUTOHSCROLL+ES_READONLY
     dialogitem 'STATIC','Program Bitness',-1,10,30,70,15,WS_VISIBLE
     dialogitem 'EDIT','',IDC_BITNESS,80,30,150,15,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_AUTOHSCROLL+ES_READONLY
     dialogitem 'STATIC','Program Subsystem',-1,10,50,70,15,WS_VISIBLE
     dialogitem 'EDIT','',IDC_SUBSYSTEM,80,50,150,15,WS_VISIBLE+WS_BORDER+WS_TABSTOP+ES_AUTOHSCROLL+ES_READONLY
  enddialog

  menu main_menu
       menuitem '&File',0,MFR_POPUP
                menuitem '&Load PE...',IDM_LOAD
                menuseparator
                menuitem 'E&xit',IDM_EXIT,MFR_END
       menuitem '&Help',0,MFR_POPUP + MFR_END
                menuitem '&About...',IDM_ABOUT,MFR_END

  versioninfo version,VOS__WINDOWS32,VFT_APP,VFT2_UNKNOWN,LANG_ENGLISH+SUBLANG_DEFAULT,0,\
              'FileDescription','PEmenu',\
              'LegalCopyright','No rights reserved.',\
              'FileVersion','1.0',\
              'ProductVersion','1.0',\
              'OriginalFilename','PEMENU.EXE'

resdata winxp
      ;  file 'manifest.xml'
db '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',13,10
db '<assembly xmlns="urn:schemas-microsoft-com:asm.v1" manifestVersion="1.0">',13,10
db '<assemblyIdentity',13,10
    db 'version="1.0.0.0"',13,10
    db 'processorArchitecture="X86"',13,10
    db 'name="CompanyName.ProductName.Application"',13,10
    db 'type="win32"',13,10
db  '/>',13,10
db '<description>Your application description here.</description>',13,10
db '<dependency>',13,10
    db '<dependentAssembly>',13,10
        db '<assemblyIdentity',13,10
            db 'type="win32"',13,10
            db  'name="Microsoft.Windows.Common-Controls"',13,10
            db 'version="6.0.0.0"',13,10
            db 'processorArchitecture="X86"',13,10
            db 'publicKeyToken="6595b64144ccf1df"',13,10
            db 'language="*"',13,10
       db  '/>',13,10
    db '</dependentAssembly>',13,10
db '</dependency>',13,10
db '</assembly>'
endres