#!/usr/bin/env python3
"""Multiprocessing bruteforce for loose comparison attacks (0e prefix)."""

import hashlib
import argparse
import sys
from multiprocessing import Process, Queue, cpu_count


def loose_comparison(queue: Queue, num: int, prefix: str, suffix: str, target: str = '0e'):
    """
    Check if a candidate produces a hash suitable for loose comparison attack.
    
    Args:
        queue: Multiprocessing queue for signaling completion
        num: The number to test
        prefix: String prefix to add before the number
        suffix: String suffix to add after the number
        target: Target prefix for the hash (default: '0e')
    """
    plaintext = f"{prefix}{str(num)}{suffix}"
    hash_value = hashlib.md5(plaintext.encode('ascii')).hexdigest()
    
    # Check if hash starts with target and has no hex characters after
    if hash_value[:len(target)] == target and not any(x in "abcdef" for x in hash_value[len(target):]):
        print(f'plaintext: {plaintext}, md5: {hash_value}')
        queue.put("done")  # Signal all workers to exit


def worker(queue: Queue, thread_i: int, threads: int, prefix: str, suffix: str, target: str):
    """
    Worker process that tests candidates in parallel.
    
    Args:
        queue: Multiprocessing queue for signaling
        thread_i: This worker's thread ID
        threads: Total number of threads
        prefix: String prefix for plaintext
        suffix: String suffix for plaintext
        target: Target hash prefix
    """
    # Each worker handles every Nth number (where N = number of threads)
    for num in range(thread_i, 10**50, threads):
        if not queue.empty():
            break
        loose_comparison(queue, num, prefix, suffix, target)


def main():
    parser = argparse.ArgumentParser(
        description='Multiprocessing bruteforce for loose comparison attacks'
    )
    parser.add_argument(
        '--prefix', '-p',
        default='a_prefix',
        help='String prefix to add before the number (default: a_prefix)'
    )
    parser.add_argument(
        '--suffix', '-s',
        default='a_suffix',
        help='String suffix to add after the number (default: a_suffix)'
    )
    parser.add_argument(
        '--threads', '-t',
        type=int,
        default=cpu_count(),
        help=f'Number of threads (default: {cpu_count()})'
    )
    parser.add_argument(
        '--target', '-T',
        default='0e',
        help='Target hash prefix (default: 0e)'
    )
    
    args = parser.parse_args()
    
    procs = []
    queue = Queue()
    threads = args.threads
    
    print(f"Starting {threads} worker threads...")
    print(f"Prefix: {args.prefix}, Suffix: {args.suffix}, Target: {args.target}")
    
    for thread_i in range(threads):
        proc = Process(
            target=worker,
            args=(queue, thread_i, threads, args.prefix, args.suffix, args.target)
        )
        proc.daemon = True  # Kill all subprocesses when main process exits
        procs.append(proc)
        proc.start()
    
    # Wait until a worker signals completion
    while queue.empty():
        pass
    
    print("Match found! Shutting down workers...")
    
    # Give workers a moment to clean up
    import time
    time.sleep(0.1)
    
    return 0


if __name__ == '__main__':
    sys.exit(main())
