// Mach IPC Sender Example
// Compile: gcc sender.c -o sender
// This looks up a port and sends a message to it

#include <stdio.h>
#include <mach/mach.h>
#include <servers/bootstrap.h>

int main() {
    mach_port_t port;
    kern_return_t kr;

    // Look up the receiver port via bootstrap server
    kr = bootstrap_look_up(bootstrap_port, "org.example.macos-ipc-test", &port);
    if (kr != KERN_SUCCESS) {
        printf("bootstrap_look_up() failed with code 0x%x\n", kr);
        printf("Make sure the receiver is running and registered\n");
        return 1;
    }
    printf("Looked up port with name %d\n", port);

    // Construct the message
    struct {
        mach_msg_header_t header;
        char some_text[10];
        int some_number;
    } message;

    // Set up message header
    message.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, 0);
    message.header.msgh_remote_port = port;
    message.header.msgh_local_port = MACH_PORT_NULL;
    message.header.msgh_size = sizeof(message);
    message.header.msgh_id = 0;

    // Fill in message content
    strncpy(message.some_text, "Hello", sizeof(message.some_text));
    message.some_number = 35;

    // Send the message
    kr = mach_msg(
        &message.header,
        MACH_SEND_MSG,
        sizeof(message),
        0,
        MACH_PORT_NULL,
        MACH_MSG_TIMEOUT_NONE,
        MACH_PORT_NULL
    );
    
    if (kr != KERN_SUCCESS) {
        printf("mach_msg() failed with code 0x%x\n", kr);
        return 1;
    }
    
    printf("Sent message successfully\n");
    printf("  Text: %s\n", message.some_text);
    printf("  Number: %d\n", message.some_number);

    return 0;
}
