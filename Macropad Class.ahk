
; /////////////////////////////////////////Configuration////////////////////////////////////////////////////////

; Reload 
^!r::Reload()     


; //////////Primary/Main Menu Hotkeys////////////
; Use the backtick key, Control Right Click, or Capslock to open the main menu.
`::
{    
    Macropad.ShowMenu()
}
^RButton::{
    Macropad.ShowMenu()
}

~Capslock::
{
    Macropad.ShowMenu()
}

;; Use this version if you want to still have capslock work as a key and/or as a modifier in other scripts. This version will only show the menu if you hit capslock and release it within 200ms. I have a capslock modifier script that I use, so I use this version. 
; ~CapsLock::{
;     KeyWait "CapsLock"  ; Wait for CapsLock to be released
;     if (A_PriorKey = "CapsLock" && A_TimeSinceThisHotkey < 200) {
;         try {
;             Macropad.ShowMenu()
;         }
;     }
;     Else
;     {
;         return ; change this here if you want to do something else when capslock is released. 
;     }
; }


;//////////////////////////////////////////////////////Secondary Menu Hotkeys////////////////////////  
; I use this when I want to show a specific menu for each program, kind of like a personal context menu for each app. You can ignore this if you like. See details in Macropad Class.ahk

+RButton:: ; shift and right click
{
    Secondarymenus()
}


~LShift & CapsLock up:: ; shift and capslock. 
{
    Secondarymenus()
}


Secondarymenus()  
; my personal had a few more programs, but this is the basic idea. 

{    
    If WinActive("ahk_exe chrome.exe") || WinActive("ahk_exe chrome.exe") || WinActive("ahk_exe thorium.exe") || WinActive("ahk_exe firefox.exe")
        {
           Macropad.GetMenu("websites").Show()
           return
        }
     If WinActive("ahk_class CabinetWClass") 
        {
            Macropad.GetMenu("folders").Show()
            return
        }
else
{
    Macropad.ShowMenu() ; if not specified, show the main menu.
}
}


; /////////////////////////////////////////Helper functions//////////////////////////////////////////////////////// 
; This section is where you can add your own functions in the script. I find these few useful, but feel free to delete them.

runApp(appName) { 
	For app in ComObject('Shell.Application').NameSpace('shell:AppsFolder').Items
		(app.Name = appName) && RunWait('explorer shell:appsFolder\' app.Path)
}

SendAsPaste(text) {
    ClipSave := ClipboardAll()
    A_Clipboard := ""
    A_Clipboard := text
    Send("^v")
    Sleep(150)
    A_Clipboard := ClipSave
    return true
}







; ////////////////////////Macropad Class //////////////////////////////////////////

class Macropad {
    static runningScripts := Map()
    static scriptStates := Map()  ; New map to track script states between refreshes
    static trayMenu := A_TrayMenu
    static WM_COMMAND := 0x111
    static WM_ENTERMENULOOP := 0x211
    static WM_EXITMENULOOP := 0x212
    static WM_RBUTTONDOWN := 0x204
    static WM_RBUTTONUP := 0x205
    static editAction := ""
    static excludedScripts := [ ; Here you can list the scripts you don't want to see in your 'Running Ahk Scripts' if you want to hide them. I've commented them out for now so you can see everything, but feel free to add your own here. 
    "launcher.ahk",
    "AutoHotkeyUX.exe",
    "Ahk2Exe.exe", 
    ]
    static commands := Map(
        "Open", 65300,
        "Help", 65301,
        "Spy", 65302,
        "Reload", 65303,
        "Edit", 65304,
        "Suspend", 65305,
        "Pause", 65306,
        "Exit", 65307
    )
    static menus := Map()
    static menuVisible := false
    static keyMap := Map()
    static activeMenu := ""
    static submenuHotkeys := Map()
    static GetMenu(menuName) {
        if (!this.menus.Has(menuName)) {
            this.menus[menuName] := Menu()
        }
        return this.menus[menuName]
    }

    static AddMenuItems(menuName, items, showHotkeys := true, showHotstrings := true, showIcons := true) { ; attemting to get rid of separators
        menu := this.GetMenu(menuName)
        nonSeparatorCount := 0
        lastWasSeparator := false
    
        for index, item in items {
            ; Check for separator
            if (item == true) {
                if (!lastWasSeparator) {
                    menu.Add()
                    lastWasSeparator := true
                }
                continue
            }
            
            lastWasSeparator := false
            
            if (Type(item) != "Array") {
                continue
            }
            nonSeparatorCount++
            label := item[1]
            callback := item[2]
            icon := (item.Length > 2 && Type(item[3]) = "String") ? this.GetFirstValidIcon(item[3]) : ""
            options := []
            if (item.Length > 3) {
                Loop item.Length - 3 {
                    options.Push(item[A_Index + 3])
                }
            }
            this.AddNumberedItem(menu, nonSeparatorCount, label, callback, icon, showHotkeys, showHotstrings, showIcons, options*)
        }
        return menu
    }

    static GetFirstValidIcon(iconPaths) {
    if (Type(iconPaths) != "String")
        return ""


    if (globaldarkmodeoverride = 0) { ; don't change this. this will only allow the script to try to set light/dark theme context if global darkmodeoveride is off (set to 0)
        try {
            this.forceDarkModeIcons := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme") = 0
        } 
    }
    if (globaldarkmodeoverride = 1) { ; 
        try {
            this.forceDarkModeIcons := true
        } 
    }
    if (globaldarkmodeoverride = 2) {
        try {
            this.forceDarkModeIcons := false
        } 

    }



    paths := StrSplit(iconPaths, ",")
    for index, path in paths {
        path := Trim(path)
        
        if (this.forceDarkModeIcons) {  ; Now use the class property we just set
            SplitPath(path, &fileName, &dirPath, &extension)
            if (extension != "") {
                darkVariant := RegExReplace(path, "\." extension "$", "dark." extension)
                if (FileExist(darkVariant))
                    return darkVariant
            }
        }

        if (FileExist(path))
            return path 
    }
    
    return ""  
}

    static AddNumberedItem(menu, itemNum, label, callback, icon := "", showHotkeys := true, showHotstrings := true, showIcons := true, options*) { ;  ; hotkeys, hotstrings, icons are changed in individual submenus
        shortcutTexts := []
        processedCallback := callback
        if (Type(callback) = "Menu") {
            submenuShortcuts := []
            if (options.Length > 0) {
                for option in options {
                    if (!option || option = "")
                        continue
                    ; Support normal modifier hotkeys and custom combinations such as
                    ; "~CapsLock & c". This lets CapsLock act as an additional
                    ; modifier without hard-coding individual shortcuts here.
                    if (showHotkeys && (InStr(option, " & ") || RegExMatch(option, "i)^([\^\!\+\#]*F?[1-9]|[\^\!\+\#]*F1[0-2]|[\^\!\+\#]+.)"))) {
                        try {
                            Hotkey(option, (*) => this.ShowSubmenu(callback))
                            submenuShortcuts.Push(option)
                        }
                    }

                    if (showHotstrings && RegExMatch(option, "^[.,\\]")) {
                        try {
                            if (option = ".") {
                                Hotstring(":C:." . SubStr(option, 2), processedCallback)
                            } else {
                                Hotstring(":C:" . option, processedCallback)
                            }
                            shortcutTexts.Push(option)
                        }
                    }

                }
            }
            menuLabel := Format("{1}. {2}", this.GetMenuLabel(itemNum), label)
            if (submenuShortcuts.Length > 0) {
                shortcutString := ""
                for index, text in submenuShortcuts {
                    shortcutString .= "[" . text . "]" . (index < submenuShortcuts.Length ? ", " : "")
                }
                menuLabel .= " `t" . shortcutString
            }
            menu.Add(menuLabel, callback)
            if (icon && showIcons) {
                try {
                    menu.SetIcon(menuLabel, icon)
                }
            }
            return
        }

        for option in options {
            if (!option || option = "")
                continue
                ; A custom combination uses AutoHotkey's "prefix & key" syntax.
                if (showHotkeys && (InStr(option, " & ") || RegExMatch(option, "i)^([\^\!\+\#]*F?[1-9]|[\^\!\+\#]*F1[0-2]|[\^\!\+\#]+.)"))) {
                try {
                    Hotkey(option, processedCallback)
                    shortcutTexts.Push(option)
                }
            }
            if (showHotstrings && RegExMatch(option, "^[.,\\]")) { ; debug adding ,is 
                try {
                    if (option = ".") {
                        Hotstring(":C:." . SubStr(option, 2), processedCallback)
                    } else {
                        Hotstring(":C:" . option, processedCallback)
                    }
                    shortcutTexts.Push(option)
                }
            }
        }
        menuLabel := Format("{1}. {2}", this.GetMenuLabel(itemNum), label)
        if (shortcutTexts.Length > 0) {
            shortcutString := ""
            for index, text in shortcutTexts {
                shortcutString .= "[" . text . "]" . (index < shortcutTexts.Length ? ", " : "")
            }
            menuLabel .= " `t" . shortcutString
        }
        try {
            menu.Add(menuLabel, processedCallback)
            if (icon && showIcons) {
                menu.SetIcon(menuLabel, icon)
            }
        }
        if (itemNum <= 9)
            this.keyMap[itemNum] := processedCallback
        else if (itemNum = 10)
            this.keyMap["0"] := processedCallback
        else if (itemNum <= 35)
            this.keyMap[Chr(itemNum + 54)] := processedCallback
    }

    static ShowSubmenu(submenu) {
        if (Type(submenu) = "Menu") {
            this.activeMenu := submenu
            submenu.Show()
        } else if (Type(submenu) = "String" && this.menus.Has(submenu)) {
            this.activeMenu := this.menus[submenu]
            this.menus[submenu].Show()
        }
        this.SetSubmenuHotkeys()
    }
    static SetSubmenuHotkeys() {
        this.DisableHotkeys()
        for key, callback in this.keyMap {
            try {
                Hotkey(key, (*)=> this.HandleKeyPress(key), "On")
            }
        }
        SetTimer(() => this.DisableHotkeys(), -50)
    }
    static HandleKeyPress(key) {
        if (this.activeMenu && this.keyMap.Has(key)) {
            callback := this.keyMap[key]
            if (callback)
                callback()
        }
    }
    static DisableHotkeys() {
        for key, callback in this.keyMap {
            try {
                Hotkey(key, "Off")
            }
        }
    }
    static GetMenuLabel(index) {
        if (index <= 9)
            return index
        if (index = 10)
            return "0"
        return Chr(index + 54)
    }

    static ShowMenu() {
        this.AddAHKControlSubmenu()  ; Refresh the AHKControl submenu before showing the menu
        this.menuVisible := true
        this.activeMenu := this.menus["default"]
        try {
            this.menus["default"].Show()
        }
        this.SetSubmenuHotkeys()
    }

    

; //////////////////////////// AddAHKControlSubmenu Methods


static AddAHKControlSubmenu() {
    ahkControlMenu := Macropad.GetMenu("AHKControl")
    
    ahkControlMenu.Delete()  ; Clear the menu before refreshing

    scripts := this.GetRunningAHKScripts()

    ; If no scripts are running, show "No Running Scripts"
    if (scripts.Length = 0) {
        ; ahkControlMenu.Add("No Running Scripts")
        ahkControlMenu.Add()
        ahkControlMenu.Add(Format("{1}. Reload", this.GetMenuLabel(1)), (*) => Reload())
        ahkControlMenu.Add(Format("{1}. Window Spy", this.GetMenuLabel(2)), (*) => SendMessage(0x111, 65402,, A_ScriptHwnd))
        return ahkControlMenu
    }

    ; Sort scripts alphabetically by name
    sortedScripts := []
    for script in scripts
        sortedScripts.Push(script)

    ; Bubble sort scripts
    for i, item1 in sortedScripts {
        for j, item2 in sortedScripts {
            if (j <= i)
                continue
            if (StrCompare(sortedScripts[i].name, sortedScripts[j].name, true) > 0) {
                temp := sortedScripts[i]
                sortedScripts[i] := sortedScripts[j]
                sortedScripts[j] := temp
            }
        }
    }

    ; Add each script to the menu with its corresponding submenu
    mainIndex := 0
    for script in sortedScripts {
        mainIndex++
        
        scriptSubMenu := Menu()
        subItemNum := 0
        
        scriptSubMenu.Add(Format("{1}. Tray Menu", this.GetMenuLabel(++subItemNum)), 
            this.CreateShowTrayMenuCallback(script.pid))
        scriptSubMenu.Add()
        scriptSubMenu.Add(Format("{1}. Open File Location", this.GetMenuLabel(++subItemNum)), 
            this.CreateOpenFileLocationCallback(script.path))
        scriptSubMenu.Add(Format("{1}. Reload", this.GetMenuLabel(++subItemNum)), 
            this.CreateCommandCallback(script.pid, "Reload"))

        
        includes := this.GetIncludeFiles(script.path)
        if (includes.Length > 0) {
            editSubMenu := Menu()
            editItemNum := 0
            
            ; Add main script first
            editSubMenu.Add(Format("{1}. {2}", this.GetMenuLabel(++editItemNum), script.name), 
                this.CreateEditCallback(script.path))
            editSubMenu.Add()  ; Add separator line
            
            ; Sort only the includes
            sortedIncludes := []
            for includePath in includes {
                SplitPath(includePath,, &dir, &ext, &name)
                sortedIncludes.Push({
                    name: name "." ext,
                    path: includePath
                })
            }
            
            ; Sort includes alphabetically
            for i, item1 in sortedIncludes {
                for j, item2 in sortedIncludes {
                    if (j <= i)
                        continue
                    if (StrCompare(sortedIncludes[i].name, sortedIncludes[j].name, true) > 0) {
                        temp := sortedIncludes[i]
                        sortedIncludes[i] := sortedIncludes[j]
                        sortedIncludes[j] := temp
                    }
                }
            }
            
            ; Add sorted includes to menu
            for item in sortedIncludes {
                editSubMenu.Add(Format("{1}. {2}", this.GetMenuLabel(++editItemNum), item.name), 
                    this.CreateEditCallback(item.path))
            }
            
            scriptSubMenu.Add(Format("{1}. Edit", this.GetMenuLabel(++subItemNum)), editSubMenu)
        } else {
            scriptSubMenu.Add(Format("{1}. Edit", this.GetMenuLabel(++subItemNum)), 
                this.CreateEditCallback(script.path))
        }

        scriptSubMenu.Add(Format("{1}. Pause", this.GetMenuLabel(++subItemNum)), 
            this.CreateCommandCallback(script.pid, "Pause"))
        scriptSubMenu.Add(Format("{1}. Suspend", this.GetMenuLabel(++subItemNum)), 
            this.CreateCommandCallback(script.pid, "Suspend"))

        ; Get current state directly from the script window
        state := this.GetScriptState(script.hwnd)
        if (state.paused)
            scriptSubMenu.Check(Format("{1}. Pause", this.GetMenuLabel(subItemNum - 1)))
        if (state.suspended)
            scriptSubMenu.Check(Format("{1}. Suspend", this.GetMenuLabel(subItemNum)))

        scriptSubMenu.Add()
        scriptSubMenu.Add(Format("{1}. Exit", this.GetMenuLabel(++subItemNum)), 
            this.CreateCommandCallback(script.pid, "Exit"))

        mainMenuLabel := Format("{1}. {2}", this.GetMenuLabel(mainIndex), script.name)
        ahkControlMenu.Add(mainMenuLabel, scriptSubMenu)

        if (state.paused)
            ahkControlMenu.Check(mainMenuLabel)
        if (state.suspended)
            ahkControlMenu.Check(mainMenuLabel)
    }

    ahkControlMenu.Add()
    globalIndex := sortedScripts.Length + 1
    ; ahkControlMenu.Add(Format("{1}. Reload All", this.GetMenuLabel(globalIndex)), 
    ;     ; (*) => Run('"C:\Users\' A_Username '\OneDrive\Desktop\AHK Scripts.ahk"'))

            ahkControlMenu.Add(Format("{1}. Reload", this.GetMenuLabel(globalIndex)), 
        (*) => Reload())
    ; ahkControlMenu.Add(Format("{1}. Window Spy", this.GetMenuLabel(globalIndex + 1)), 
    ;     (*) => SendMessage(0x111, 65402,, A_ScriptHwnd))
    ; ahkControlMenu.Add()
    ahkControlMenu.Add(Format("{1}. Exit All", this.GetMenuLabel(globalIndex + 1)), 
        (*) => this.ExitAllScripts())
    
    return ahkControlMenu
}

static GetRunningAHKScripts() {
    scripts := []
    DetectHiddenWindows(true)
    
    ; Get all windows with the AutoHotkey class (both .ahk and .exe)
    winList := WinGetList("ahk_class AutoHotkey")
    
    for hwnd in winList {
        try {
            ; Get the full window title which contains the script path
            fullTitle := WinGetTitle(hwnd)
            
            ; Get the process path for the window
            pid := WinGetPID(hwnd)
            processPath := ProcessGetPath(pid)
            
            ; Skip if the process path is empty or doesn't exist
            if (!processPath || !FileExist(processPath))
                continue
            
            scriptPath := ""
            scriptName := ""
            foundName := false
            
            ; Check if the process is an AutoHotkey interpreter (v1 or v2)
            if (InStr(processPath, "AutoHotkey") && (InStr(processPath, "AutoHotkeyU64.exe") || 
                InStr(processPath, "AutoHotkeyU32.exe") || InStr(processPath, "AutoHotkey64.exe") || 
                InStr(processPath, "AutoHotkey32.exe") || InStr(processPath, "AutoHotkey64_UIA.exe"))) {
                ; Extract the script path from the window title
                if (RegExMatch(fullTitle, "^(.*) - AutoHotkey(?: v[0-9\.]+)?$", &match)) {
                    scriptPath := match[1]
                    
                    ; Skip if the script path doesn't exist
                    if (FileExist(scriptPath)) {
                        SplitPath(scriptPath, &scriptName)
                        foundName := true
                    }
                }
                ; Special handling for UIA if no valid .ahk found
                if (!foundName && InStr(processPath, "AutoHotkey64_UIA.exe")) {
                    if (RegExMatch(fullTitle, "^(.*\.ahk)", &match)) {
                        possiblePath := match[1]
                        if (FileExist(possiblePath)) {
                            scriptPath := possiblePath
                            SplitPath(scriptPath, &scriptName)
                            foundName := true
                        }
                    }
                    if (!foundName) {
                        scriptName := "UIA_Script_" pid
                        scriptPath := processPath
                    }
                }
            }
            
            ; Handle compiled .exe scripts (not interpreters)
            if (!foundName && InStr(processPath, ".exe")) {
                ; For compiled scripts, extract just the filename for display
                SplitPath(processPath, &scriptName)
                scriptPath := processPath
                
                ; Try to get a better name from the window title
                if (RegExMatch(fullTitle, "^(.*?)(?:\s*-\s*.*)?$", &match)) {
                    ; If the title has a name, use it
                    if (match[1] && match[1] != processPath) {
                        ; If title is just a filename without path, use that
                        if (!InStr(match[1], "\")) {
                            scriptName := match[1]
                        } else {
                            ; Otherwise extract the filename from the path in the title
                            SplitPath(match[1], &titleName)
                            if (titleName)
                                scriptName := titleName
                        }
                    }
                }
                
                foundName := true
            }
            
            ; Fallback if no name found
            if (!foundName) {
                scriptName := "AHK_Script_" pid
                scriptPath := processPath
            }
            
            ; Ensure the filename has the correct extension
            if (!InStr(scriptName, ".")) {
                SplitPath(scriptPath, , , &ext)
                if (ext)
                    scriptName := scriptName "." ext
            }
            
            ; Exclude unwanted scripts
            if (this.ShouldExcludeScript(scriptName))
                continue
            
            ; Get the script state
            state := this.GetScriptState(hwnd)
            
            scripts.Push({
                pid: pid,
                name: scriptName,
                path: scriptPath,
                hwnd: hwnd,
                paused: state.paused,
                suspended: state.suspended
            })
        }
    }
    return scripts
}


static GetScriptState(hwnd) {
    static MF_CHECKED := 0x0008
    
    if (!hwnd || !WinExist("ahk_id " hwnd))
        return { paused: false, suspended: false }
        
    ; Force menu state updates first
    try SendMessage(0x211, 0, 0,, "ahk_id " hwnd)  ; WM_ENTERMENULOOP
    try SendMessage(0x212, 0, 0,, "ahk_id " hwnd)  ; WM_EXITMENULOOP
        
    mainMenu := DllCall("GetMenu", "Ptr", hwnd, "Ptr")
    if (!mainMenu)
        return { paused: false, suspended: false }
        
    fileMenu := DllCall("GetSubMenu", "Ptr", mainMenu, "Int", 0, "Ptr")
    if (!fileMenu) {
        DllCall("CloseHandle", "Ptr", mainMenu)
        return { paused: false, suspended: false }
    }
    
    ; Use bit shifting for state detection
    pauseState := DllCall("GetMenuState", "Ptr", fileMenu, "UInt", 4, "UInt", 0x400) >> 3 & 1
    suspendState := DllCall("GetMenuState", "Ptr", fileMenu, "UInt", 5, "UInt", 0x400) >> 3 & 1
    
    DllCall("CloseHandle", "Ptr", fileMenu)
    DllCall("CloseHandle", "Ptr", mainMenu)
    
    return { 
        paused: pauseState = 1,
        suspended: suspendState = 1
    }
}


    static UpdateScriptState(pid, command) {
        if (!this.scriptStates.Has(pid))
            this.scriptStates[pid] := { paused: false, suspended: false }
            
        if (command = "Pause")
            this.scriptStates[pid].paused := !this.scriptStates[pid].paused
        else if (command = "Suspend")
            this.scriptStates[pid].suspended := !this.scriptStates[pid].suspended
    }

    static RefreshMenu() {
        scripts := this.GetRunningAHKScripts()
    
        this.runningScripts.Clear()
        for script in scripts
            this.runningScripts[script.pid] := script
        this.trayMenu.Delete()
    
        ; Collect scripts into an array
        sortedScripts := []
        for pid, script in this.runningScripts
            sortedScripts.Push({pid: pid, script: script})
    
                ; Sort scripts alphabetically by name
        for i, item1 in sortedScripts {
            for j, item2 in sortedScripts {
                if (j <= i)
                    continue

                if (StrCompare(sortedScripts[i].script.name, sortedScripts[j].script.name, true) > 0) {
                    temp := sortedScripts[i]
                    sortedScripts[i] := sortedScripts[j]
                    sortedScripts[j] := temp
                }
            }
        }

        

        ; Add scripts to the tray menu
        for entry in sortedScripts {
            pid := entry.pid
            script := entry.script
    
            scriptSubMenu := Menu()
           
            scriptSubMenu.Add()
            
            scriptSubMenu.Add("Reload", this.CreateCommandCallback(pid, "Reload"))
    
            includes := this.GetIncludeFiles(script.path)
            if (includes.Length > 0) {
                editSubMenu := Menu()
                editSubMenu.Add(script.name, this.CreateEditCallback(script.path))
                editSubMenu.Add()
    
                for includePath in includes {
                    SplitPath(includePath,, &dir, &ext, &name)
                    menuName := name "." ext
                    editSubMenu.Add(menuName, this.CreateEditCallback(includePath))
                }
                scriptSubMenu.Add("Edit", editSubMenu)
            } else {
                scriptSubMenu.Add("Edit", this.CreateEditCallback(script.path))
            }
    
            scriptSubMenu.Add("Pause", this.CreateCommandCallback(pid, "Pause"))
            scriptSubMenu.Add("Suspend", this.CreateCommandCallback(pid, "Suspend"))
    
            if (script.paused)
                scriptSubMenu.Check("Pause")
            if (script.suspended)
                scriptSubMenu.Check("Suspend")
    
            scriptSubMenu.Add()
            scriptSubMenu.Add("Exit", this.CreateCommandCallback(pid, "Exit"))
    
            this.trayMenu.Add(script.name, scriptSubMenu)
        }

        this.trayMenu.Add()
        this.trayMenu.Add("Reload", (*) => (this.RefreshMenu(), Reload())) ; Sleep(500), Reload()))

        this.trayMenu.Add("Window Spy", (*) => SendMessage(0x111, 65402,, A_ScriptHwnd)) ; open Window Spy

        this.trayMenu.Add()
        this.trayMenu.Add("Exit All", (*) => this.ExitAllScripts())
    }
    




    static CreateOpenFileLocationCallback(pid) {
        return (*) => this.OpenFileLocation(pid)
    }
          
    static OpenFileLocation(pid) {
            ; Debug verification
            if (pid = "") {
                return
            }
            ; Verify the path exists
            if (!FileExist(pid)) {
                return
            }
            SplitPath(pid,, &dir)

            ; Verify directory exists
            if (!DirExist(dir)) {
                MsgBox("Error: Directory not found: " dir)
                return
            }
        
            ; Attempt to open directory
            try {
                Run('explorer.exe /select,"' pid '"')
    
            } catch as err {
                MsgBox("Failed to open directory: " err.Message "`nPath: " pid "`nDirectory: " dir)
            }
        }
    

  

    static ShouldExcludeScript(scriptName) {
        for excludedScript in this.excludedScripts {
            if (scriptName = excludedScript)
                return true
        }
        return false
    }
    
    static CreateEditCallback(scriptPath) {
        return (*) => this.EditScriptFile(scriptPath)
    }


    static ShowEditMenu(script) {
        includes := this.GetIncludeFiles(script.path)
        
        if (includes.Length = 0) {
            this.EditScriptFile(script.path)
            return
        }
        
        editMenu := Menu()
        editMenu.Add(script.name, (*) => this.EditScriptFile(script.path))
        editMenu.Add()
        
        for includePath in includes {
            SplitPath(includePath,, &dir, &ext, &name)
            menuName := name "." ext
            editMenu.Add(menuName, this.CreateIncludeCallback(includePath))
        }
        
        MouseGetPos(&mouseX, &mouseY)
        editMenu.Show(mouseX, mouseY)
    }

    static GetIncludeFiles(scriptPath) {
        includes := []
        
        if !FileExist(scriptPath)
            return includes
            
        SplitPath(scriptPath,, &scriptDir)
        
        try {
            fileContent := FileRead(scriptPath)
            
            loop parse, fileContent, "`n", "`r" {
                if RegExMatch(A_LoopField, "i)^\s*#Include\s+(.+)$", &match) {
                    includePath := match[1]
                    includePath := Trim(includePath, " `t`"'")
                    
                    if !RegExMatch(includePath, "^[A-Za-z]:\\") {
                        includePath := scriptDir "\" includePath
                    }
                    
                    if FileExist(includePath) {
                        includes.Push(includePath)
                    }
                    else if FileExist(A_MyDocuments "\AutoHotkey\Lib\" includePath) {
                        includes.Push(A_MyDocuments "\AutoHotkey\Lib\" includePath)
                    }
                }
            }
        }
        return includes
    }

    static CreateIncludeCallback(path) {
        return (*) => this.EditScriptFile(path)
    }

    static CreateShowTrayMenuCallback(pid) {
        return (*) => this.ShowOriginalTrayMenu(pid)
    }

    static CreateCommandCallback(pid, command) {
        if (command = "Reload") {
            return (*) => (
                this.SendCommand(pid, command),
                ; this.scriptStates.Delete(pid),
                SetTimer(() => this.RefreshMenu(), -500)
            )
        }
        return (*) => (
            this.SendCommand(pid, command),
            this.UpdateScriptState(pid, command),
            this.RefreshMenu()
        )
    }

    static GetScriptNameFromPath(path) {
    SplitPath(path,, &dir, &ext, &name)
    return name "." ext
} ; first thing we updated

    static GetScriptPathFromCmd(cmdLine) {
        ; MsgBox("Command Line: " cmdLine) ; Debug
    
        ; Match quoted .ahk paths
        if RegExMatch(cmdLine, '"([^"]*\.ahk)"', &match) {
            ; MsgBox("Matched Script Path (Quoted): " match[1]) ; Debug
            return match[1]
        }
    
        ; Match unquoted .ahk paths
        if RegExMatch(cmdLine, '([^\s]*\.ahk)', &match) {
            ; MsgBox("Matched Script Path (Unquoted): " match[1]) ; Debug
            return match[1]
        }
    
        ; MsgBox("No Match Found in Command Line: " cmdLine) ; Debug
        return ""
    }

    static EditScriptFile(scriptPath) {
        if (scriptPath = "")
            return
            
        ; Check if this is an .exe file and look for a corresponding .ahk file
        SplitPath(scriptPath, &fileName, &scriptDir, &fileExt, &fileNameNoExt)
        
        ; If it's an .exe file, check if there's a matching .ahk file in the same directory
        if (fileExt = "exe") {
            ahkPath := scriptDir "\" fileNameNoExt ".ahk"
            if (FileExist(ahkPath))
                scriptPath := ahkPath  ; Use the .ahk file instead
        }
            
        try {
            editorpath := A_AppData "\..\Local\Programs\Microsoft VS Code\Code.exe"
            if FileExist(editorpath) {
                Run('"' editorpath '" "' scriptPath '"')
                return
            }
        }
    
        try {
            editorpath := "B:\Users\Micha\AppData\Local\Programs\Microsoft VS Code\Code.exe"
            if FileExist(editorpath) {
                Run('"' editorpath '" "' scriptPath '"')
                return
            }
        }
            
        if (this.editAction != "") {
            action := StrReplace(this.editAction, "$SCRIPT_PATH", scriptPath)
            try {
                Run(action)
                return
            }
        }
        
        try {
            Run("edit " scriptPath)
            return
        }
        
        try {
            Run('notepad.exe "' scriptPath '"')
        }
    }

    static ShowOriginalTrayMenu(targetPID) {
        DetectHiddenWindows(true)
        if (hwnd := WinExist("ahk_pid " targetPID " ahk_class AutoHotkey")) {
            PostMessage(0x404, 0, this.WM_RBUTTONDOWN,, "ahk_id " hwnd)
            PostMessage(0x404, 0, this.WM_RBUTTONUP,, "ahk_id " hwnd)
        }
    }

    static SendCommand(targetPID, command) {
        DetectHiddenWindows(true)
        if (hwnd := WinExist("ahk_pid " targetPID " ahk_class AutoHotkey")) {
            PostMessage(this.WM_COMMAND, this.commands[command], 0,, "ahk_id " hwnd)
            if (command = "Reload") {
                Sleep(200)  ; Give some time for the reload to complete
            }
        }
    }

    static ExitAllScripts() {
        Result := MsgBox("Are you sure you want to exit all AutoHotkey scripts?",, "YesNo")
        if Result = "No"
            return
            
        DetectHiddenWindows(true)
        winList := WinGetList("ahk_class AutoHotkey")
        this_pid := ProcessExist()
        exitedPids := Map()
        
        ; First pass: Graceful exit
        for hwnd in winList {
            try {
                pid := WinGetPID(hwnd)
                if (pid != this_pid && !exitedPids.Has(pid)) {
                    PostMessage(0x111, 65307, 0,, "ahk_id " hwnd)  ; WM_COMMAND for Exit
                    exitedPids[pid] := true
                }
            }
        }
        
        ; Give scripts a moment to exit gracefully
        Sleep(500)
        
        ; Second pass: Force close remaining scripts
        remainingScripts := false
        for hwnd in WinGetList("ahk_class AutoHotkey") {
            try {
                pid := WinGetPID(hwnd)
                if (pid != this_pid) {
                    remainingScripts := true
                    ProcessClose(pid)
                }
            }
        }
        
        ; Third pass: Use taskkill as last resort if scripts remain
        if (remainingScripts) {
            try {
                RunWait('taskkill.exe /F /FI "IMAGENAME eq AutoHotkey*" /FI "PID ne ' this_pid '"',, "Hide")
            }
        }
        
        ; Final check
        for hwnd in WinGetList("ahk_class AutoHotkey") {
            try {
                pid := WinGetPID(hwnd)
                if (pid != this_pid) {
                    MsgBox("Some scripts haven't exited.")
                    return
                }
            }
        }
        
        ExitApp
    }
}
