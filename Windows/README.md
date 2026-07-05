# Project

This is autonomous sofware installer of "PHPShift" project for Windows machines;

# Engine Software

- Python & pip;
- XAMPP (8.1.25 / PHP 8.1.25);
- Composer;
- VS Code;
- Git;

> Add required system paths into PATH (Environment Variables);

# Project Software

- pip install clight;
- pip install phpshift;

# VS Code Profile

- Import "vsetup.code-profile" profile into installed VS Code editor;

# Installer

- The "phpshift.iss" should compile the system into single "phpshift-v1.0.0.exe" file;

> & "C:\Users\BABU\AppData\Local\Programs\Inno Setup 6\ISCC.exe" /O"." phpshift.iss

# User Experience

- User downloads the .exe installer;
- Clicks on it, accepts project terms from these URL links:
  - https://github.com/phpshift/PHPShift/blob/main/LICENSE
  - https://github.com/phpshift/PHPShift/blob/main/CODE_OF_CONDUCT.md
  - https://github.com/phpshift/PHPShift/blob/main/TERMS_OF_USE.md
  - https://github.com/phpshift/PHPShift/blob/main/TRADEMARKS.md
  - https://github.com/phpshift/PHPShift/blob/main/DISCLAIMER.md
  - https://github.com/phpshift/PHPShift/blob/main/CONTRIBUTING.md
  - https://github.com/phpshift/PHPShift/blob/main/SECURITY.md
- System displays the project logo "phpshift.ico" with label "PHPShift - World's First AI-Powered Full-Stack Framework" and starts the installation process without any extra confirmation steps;
- Once done, system should display "PHPShift is ready - phpshift start" and the button "Ok" to close the window;
