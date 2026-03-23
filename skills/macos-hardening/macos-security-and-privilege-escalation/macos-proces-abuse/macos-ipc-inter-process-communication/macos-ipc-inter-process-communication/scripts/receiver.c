// Mach IPC Receiver Example
// Compile: gcc receiver.c -o receiver
// This registers a port with the bootstrap server and waits for messages

#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;

    // Create a new port with RECEIVE right
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &port);
    if (kr != KERN_SUCCESS) {
        printf("mach_port_allocate() failed with code 0x%x\n", kr);
        return 1;
    }
    printf("Created port with name %d\n", port);

    // Insert a SEND right for this port
    kr = mach_port_insert_right(mach_task_self(), port, port, MACH_MSG_TYPE_MAKE_SEND);
    if (kr != KERN_SUCCESS) {
        printf("mach_port_insert_right() failed with code 0x%x\n", kr);
        return 1;
    }
    printf("Inserted SEND right\n");

    // Register with bootstrap server
    kr = bootstrap_register(bootstrap_port, "org.example.macos-ipc-test", port);
    if (kr != KERN_SUCCESS) {
        printf("bootstrap_register() failed with code 0x%x\n", kr);
        return 1;
    }
    printf("Registered with bootstrap server as 'org.example.macos-ipc-test'\n");
    printf("Waiting for messages...\n");

    // Wait for messages
    struct {
        mach_msg_header_t header;
        char some_text[10];
        int some_number;
        mach_msg_trailer_t trailer;
    } message;

    while (1) {
        kr = mach_msg(
            &message.header,
            MACH_RCV_MSG,
            0,
            sizeof(message),
            port,
            MACH_MSG_TIMEOUT_NONE,
            MACH_PORT_NULL
        );
        
        if (kr != KERN_SUCCESS) {
            printf("mach_msg() failed with code 0x%x\n", kr);
            break;
        }
        
        printf("Received message\n");
        message.some_text[9] = 0;
        printf("  Text: %s\n", message.some_text);
        printf("  Number: %d\n", message.some_number);
    }

    return 0;
}
