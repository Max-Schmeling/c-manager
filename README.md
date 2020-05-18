# C-Manager

a simple tool I wrote some time ago using PowerShell to (partially) automate creating C-projects on Windows for my fellow students. You can also search in project files and open them without having to rely on other applications for that.

## How does it work?
The idea is that you have one root folder for all your C-programming-projects. Creating a new project basically means you create a new folder within your root folder. In that new folder you create your c files. C-Manager creates that project folder, the .c-file and a `gcc2exe.bat`-file which compiles assembles and links your source code in one click. You can supply your favourite editor in the settings. It will be launched upon creation of the project and a `Launch Editor.bat`-file can be created to launch the editor from the project folder.  (The latter I implemented to bypass the fact that we did not have admin-privileges and thus no default texteditor mapping)

## Future
This was a one-time thing and my first PowerShell-project (as you can tell from the code :grin:). I'm not going to put any more effort into it. Just be careful with spaces in the names.
