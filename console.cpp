#include "console.h"

ConsoleWindow::ConsoleWindow()
        : MAX_CONSOLE_ROWS(5000),
          MAX_CONSOLE_COLUMNS(5000) {
    hStdHandle = INVALID_HANDLE_VALUE;
}

ConsoleWindow::~ConsoleWindow() {
    if (hStdHandle != INVALID_HANDLE_VALUE) {
        FreeConsole();
        fclose(fp);
    }
}

void ConsoleWindow::Open() {
    if (hStdHandle == INVALID_HANDLE_VALUE) {
        CONSOLE_SCREEN_BUFFER_INFO coninfo;
        AllocConsole();
        GetConsoleScreenBufferInfo(GetStdHandle(STD_OUTPUT_HANDLE), &coninfo);
        coninfo.dwSize.Y = MAX_CONSOLE_ROWS;
        SetConsoleScreenBufferSize(GetStdHandle(STD_OUTPUT_HANDLE), coninfo.dwSize);
        SetConsoleTitle("Debug Window");
        hStdHandle = GetStdHandle(STD_OUTPUT_HANDLE);
        hConHandle = _open_osfhandle((long) hStdHandle, _O_TEXT);
        fp = _fdopen(hConHandle, "w");
        *stdout = *fp;
        setvbuf(stdout, NULL, _IONBF, 0);
        hStdHandle = GetStdHandle(STD_INPUT_HANDLE);
        hConHandle = _open_osfhandle((long) hStdHandle, _O_TEXT);
        fp = _fdopen(hConHandle, "r");
        *stdin = *fp;
        setvbuf(stdin, NULL, _IONBF, 0);
        hStdHandle = GetStdHandle(STD_ERROR_HANDLE);
        hConHandle = _open_osfhandle((long) hStdHandle, _O_TEXT);
        fp = _fdopen(hConHandle, "w");
        *stderr = *fp;
        setvbuf(stderr, NULL, _IONBF, 0);
        ios::sync_with_stdio();
    }
};

void ConsoleWindow::Close() {
    if (hStdHandle != INVALID_HANDLE_VALUE) {
        FreeConsole();
        fclose(fp);
        hStdHandle = INVALID_HANDLE_VALUE;
    }
};

