// Shellcode test loader for macOS x64
// Compile: gcc test-shellcode.c -o loader
// Then insert your shellcode below and run ./loader

#include <stdio.h>
#include <sys/mman.h>
#include <string.h>
#include <stdlib.h>

int (*sc)();

// INSERT YOUR SHELLCODE HERE
char shellcode[] = "";

int main(int argc, char **argv) {
    printf("[>] Shellcode Length: %zd Bytes\n", strlen(shellcode));

    // Allocate executable memory
    void *ptr = mmap(0, 0x1000, PROT_WRITE | PROT_READ, 
                     MAP_ANON | MAP_PRIVATE | MAP_JIT, -1, 0);

    if (ptr == MAP_FAILED) {
        perror("mmap");
        exit(-1);
    }
    printf("[+] SUCCESS: mmap\n");
    printf("    |-> Return = %p\n", ptr);

    // Copy shellcode to executable memory
    void *dst = memcpy(ptr, shellcode, sizeof(shellcode));
    printf("[+] SUCCESS: memcpy\n");
    printf("    |-> Return = %p\n", dst);

    // Make memory executable
    int status = mprotect(ptr, 0x1000, PROT_EXEC | PROT_READ);

    if (status == -1) {
        perror("mprotect");
        exit(-1);
    }
    printf("[+] SUCCESS: mprotect\n");
    printf("    |-> Return = %d\n", status);

    printf("[>] Trying to execute shellcode...\n");

    sc = ptr;
    sc();

    return 0;
}
