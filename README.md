# Macropad.ahk
Autohotkey Version 2

I wrote Macropad to more easily build and edit Windows 32 menus and nested submenus in Autohotkey. When I started using Autohotkey, I often found myself going into the editor to either write a shortcut only to discover that it had already been written, look up a shortcuts I had forgotten, or finding a shortcut I thought I had written, but had previously changed. This menu map script provides a visual representation of your shortcuts in one place. You can use the mouse or the keyboard to navigate through these menus, and even call specific menus with hotkeys or hotstrings. I use this to store URLs, programs I open, Autohotkey scripts I edit, the currently running autohotkey scripts, common folder locations, windows settings, snippets of text I often paste, and navigating to specific spotify playlists, to name a few. 


I like the syntax of Macropad because you can put the title of an item, the fuction for it to run, the icon, and the hotkey all in one line, separated by commas. I'll show you an example of a submenu and then explain it, which will make the main menu easier to understand at the end. Here is a sample submenu:
```
        websitesItems := [
            ["Google Calendar", (*) => Run('"https://calendar.google.com/calendar/u/0/r"'), "calendar.ico", ".cal", "!+c"],
            ["Gmail", (*) => Run('"https://mail.google.com/mail/u/0/#inbox"'), "gmail.ico", ".gm", "!+g", "^!g"],
            ["Tasks", (*) => Run('"https://calendar.google.com/calendar/u/0/r/tasks"'), ".task"],
            ["Chat GPT", (*) => Run('"https://chatgpt.com/?temporary-chat=true&model=gpt-4o-mini"'), ".chat", "+!j", ],
            ["Claude", (*) => Run('"https://claude.ai/new"'), ".cl", "!+k"], 
            ["Liner Research", (*) => Run("https://getliner.com/"), ".liner"],
            true, ; adds a separator
     	    ["Other Websites", this.GetMenu("otherwebsites")],  ; 
        ]
        this.AddMenuItems("websites", websitesItems, true, true, true) ; hotkeys, hotstrings, icons
```
Array structure - between the first and last []
- Look at the Array name itself. "websites" is the name of the whole submenu, and each line (an item) represents 
  individual menu items within that submenu. The plural "Items" refers to all of the items in the array together.
- The this.AddMenuItems line at the end of the array loads this submenu macropad when the script runs so it can be called.
- We'll call this specific array from inside the main menu, so when you open the "Websites" option in the main menu, it will open this submenu. More on this in the main menu section.

Structure of a single menu item (each section is divided by a comma). Example:
```
["Google Calendar", (*) => Run('"https://calendar.google.com/calendar/u/0/r"'), "calendar.ico", ".cal", "!+c"]

1. Item Name ["Google Calendar", ...]
   - Each item starts with an opening bracket and display name in quotes: ["Item Name"
   - The text between quotations in this section will be seen on the menu when it is opened

2. Fuctions [... (*) => Run(...), ...]
   - The , (*) => section defines what will happen when the item is selected by the user
   - It executes the code to the right of =>
   - Examples:
     - Run a URL: (*) => Run("https://example.com")
     - Run a program: (*) => Run("C:\Path\To\Program.exe")
     - Call another submenu with this.GetMenu("") (this is how we call the submenu in the main menu)
     - Execute a custom function: (*) => MyFunction(). These can be define in other parts of the code, but typically cannot be within the menu array or the class itself.
   - Always include the () the function before the comma separating this from the next part

3. Icons [... "calendar.ico", ...]
   - The first set of quotes after the function defines the icon
   - Leave as "", if you don't want an icon. Note that you will want to keep the comma or you might get an error. 
   - For simplicity, place icons in an "Icons" folder in the same directory as the script, but you can also use absolute paths to icons as well.
   - Multiple icon paths can be specified, separated by commas WITHIN the same quotes:
     "C:\Path1\icon.exe, C:\Path2\icon.exe, fallback.ico". The script will use the first icon that exists
     - This can be helpful if you use multiple computers and have a difference in path. In general, I prefer .ico files because they are transparent and more reliable than paths. A bit more work to set up though.
     These are the two websites I used change the color of an icon and convert to ico:
     - https://onlinepngtools.com/change-png-color
     - https://redketchup.io/icon-converter
   - Dark mode icon support: If you would like to use a different icon in dark mode, the script can search for that if you name your files similarly. For example, if you specify "chrome.ico", the script will automatically look for "chromedark.ico" when Windows is in dark mode. You will need to reload the script after changing themes to see changes though.

4. Hotkeys and Hotstrings [... ".cal", "!+c"]
   - The final "" sections define hotstrings and hotkeys
   - Include as many as needed, separated by commas
   - Hotstrings use standard AHK syntax:
     - ".cal" will trigger the action when you type ".cal" followed by a space or Enter
     - Currently only hotstrings starting with ".", "," or "\" are supported
   - Hotkeys also use standard AHK syntax:
     - "!+c" represents Alt+Shift+C
     - Standard modifiers (!#+^) and function keys are supported

5. Make sure to add a comma at the end of each line, except the last one in the array. If you get errors with the code after an edit, this is the most likely cause. The next most likely cause is the use of (*) => with GetMenu. See below for more details. 
```
Adding websites to the menu:

```
Main menu:
        mainItems := [
        ["URL", this.GetMenu("websites"), "chrome.ico", "!+u",], 
        ["Programs", this.GetMenu("programs"), "windows.ico", "#+p"],
        true,
        ["Autohotkey Scripts", this.GetMenu("script"), "ahkdark.ico", "^+s"],  
        ["Running Scripts", this.AddAHKControlSubmenu(), "ahkcontroldark.ico", "#s"],
        true,
        ["Folders", this.GetMenu("folders"), "folder.ico", "!+f"],
        true,  
        ["Windows Settings", this.GetMenu("windowssettings"),"settings.ico", "^+!d"],         
        ]
        defaultMenu := this.AddMenuItems("default", mainItems, true, true, true) ; hotkeys, hotstrings, icons
        this.menus["default"] := defaultMenu
```
This is a great place to explain the syntax of the main menu, as it is a bit different than the submenus. Note how it is similar to the submenus.
Key differences:
1. Note the difference in how the defaultMenu is defined at the end of the array with the last two lines. This is how the script knows which part of the menu to show when it calls Macropad.Showmenu()
2. I would probably say that most items in the main menu will be calling submenus, and the syntax is slightly different:
This is our Google Calendar example:
```
["Google Calendar", (*) => Run('"https://calendar.google.com/calendar/u/0/r"'), "calendar.ico", ".cal", "!+c"],
```
and our main menu item which calls the websites submenu:
```
["URL", this.GetMenu("websites"), "chrome.ico", "!+u",],
```
Note the disappearance of (*) =>> from the syntax. Instaed, we use this.getmenu("websites"). If the array was programItems, we would use this.getmenu("programs").
If you notice syntax errors after editing the code, commas and (*) =>> are the most likely culprits.

A few other notes:
Separators:
placing "true," (without quotations, but with a comma) in the array will add a separator (a horizontal line) between menu items in both the main and submenus. This can be helpful to visually distinguish between groups of menu items. 
Turning off showing hotkeys, hotstrings, and icons in the menu:
- Example:
```
this.AddMenuItems("websites", websitesItems, true, true, true) ; hotkeys, hotstrings, icons
```
If I wanted to not show the shortcut keys in this specific the menu, I would change the first true to false:
```
- this.AddMenuItems("websites", websitesItems, false, true, true) ; hotkeys, hotstrings, icons
```
This could be helpful if you have a lot of hotkeys and want to make the menu cleaner. You can also do this for hotstrings or to hide icons for a cleaner look. It's very easy to mass replace true, true, true in an editor with false, false, flase if you want to do this for all menus at the same time. I personally like to show the hotkeys in case I forget what they are, however, if I am on a new computer with different paths to programs and the icons aren't showing, I'll turn them off. 

 I demonstrated this script briefly in the first few minutes of this video here:
 https://www.youtube.com/watch?v=Kz6WmbeyU_I
# Using CapsLock as an additional modifier

CapsLock combinations can be assigned directly in a menu item by using
AutoHotkey's custom-combination syntax in the item's hotkey field:

```ahk
["Calculator", (*) => Run("calc.exe"), "windows.ico", "CapsLock & c"]
```

The `AddMenuItems` helper recognizes options containing ` & ` and registers
them with `Hotkey()`. This is opt-in: existing CapsLock menu behavior is not
changed unless you add a CapsLock combination to a menu item. If CapsLock is
already handled by another script, avoid assigning the same combination in
both scripts.
