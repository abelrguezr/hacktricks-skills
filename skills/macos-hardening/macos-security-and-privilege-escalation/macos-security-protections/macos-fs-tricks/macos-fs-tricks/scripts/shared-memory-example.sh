#!/bin/bash
# Compile and run POSIX shared memory producer/consumer examples
# Usage: ./shared-memory-example.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="/tmp/shm-example-$$"

# Create working directory
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Create producer.c
cat > producer.c << 'EOF'
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main() {
    const char *name = "/my_shared_memory";
    const int SIZE = 4096;

    // Create the shared memory object
    int shm_fd = shm_open(name, O_CREAT | O_RDWR, 0666);
    if (shm_fd == -1) {
        perror("shm_open");
        return EXIT_FAILURE;
    }

    // Configure the size
    if (ftruncate(shm_fd, SIZE) == -1) {
        perror("ftruncate");
        return EXIT_FAILURE;
    }

    // Memory map the shared memory
    void *ptr = mmap(0, SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
    if (ptr == MAP_FAILED) {
        perror("mmap");
        return EXIT_FAILURE;
    }

    // Write to the shared memory
    sprintf(ptr, "Hello from Producer!");
    printf("Producer wrote: %s\n", (char *)ptr);

    // Unmap and close, but do not unlink
    munmap(ptr, SIZE);
    close(shm_fd);

    printf("Producer done. Shared memory still available.\n");
    return 0;
}
EOF

# Create consumer.c
cat > consumer.c << 'EOF'
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

int main() {
    const char *name = "/my_shared_memory";
    const int SIZE = 4096;

    // Open the shared memory object
    int shm_fd = shm_open(name, O_RDONLY, 0666);
    if (shm_fd == -1) {
        perror("shm_open");
        return EXIT_FAILURE;
    }

    // Memory map the shared memory
    void *ptr = mmap(0, SIZE, PROT_READ, MAP_SHARED, shm_fd, 0);
    if (ptr == MAP_FAILED) {
        perror("mmap");
        return EXIT_FAILURE;
    }

    // Read from the shared memory
    printf("Consumer received: %s\n", (char *)ptr);

    // Cleanup
    munmap(ptr, SIZE);
    close(shm_fd);
    shm_unlink(name);

    return 0;
}
EOF

# Compile
echo "Compiling producer and consumer..."
gcc producer.c -o producer -lrt 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to compile producer. Is gcc installed?"
    rm -rf "$WORK_DIR"
    exit 1
fi

gcc consumer.c -o consumer -lrt 2>&1
if [ $? -ne 0 ]; then
    echo "Failed to compile consumer. Is gcc installed?"
    rm -rf "$WORK_DIR"
    exit 1
fi

# Run producer
echo ""
echo "Running producer..."
./producer

# Run consumer
echo ""
echo "Running consumer..."
./consumer

# Cleanup
echo ""
echo "Cleaning up..."
rm -rf "$WORK_DIR"
echo "Done!"
