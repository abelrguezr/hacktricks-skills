---
name: rust-basics
description: Rust programming reference covering ownership, generics, Option/Result, macros, iteration, conditionals, traits, testing, threading, and security. Use this skill whenever the user asks about Rust programming concepts, needs help writing Rust code, wants to understand Rust patterns, is debugging Rust code, or needs guidance on Rust best practices. Trigger for any Rust-related questions including memory management, error handling, concurrency, or security reviews.
---

# Rust Basics Reference

A comprehensive guide to Rust programming concepts, patterns, and security considerations.

## Ownership and Memory Management

Rust manages memory through ownership rules checked at compile time:

1. Each value has exactly one owner variable
2. Only one owner exists at a time
3. When the owner goes out of scope, the value is dropped

```rust
fn main() {
    let student_age: u32 = 20;
    {
        let teacher_age: u32 = 41;
        println!("Student: {}, Teacher: {}", student_age, teacher_age);
    } // teacher_age dropped here
    
    // println!("Teacher: {}", teacher_age); // ERROR: teacher_age dropped
}
```

**Key insight**: Variable scope is defined by curly braces `{}`. When a variable leaves scope, its memory is automatically freed.

## Generic Types

Create structs that work with any type using type parameters:

```rust
struct Wrapper<T> {
    value: T,
}

impl<T> Wrapper<T> {
    pub fn new(value: T) -> Self {
        Wrapper { value }
    }
}

// Usage
let num = Wrapper::new(42);
let str = Wrapper::new("Foo");
```

## Option and Result Enums

### Option<T>

Use `Option` when a value might not exist:

```rust
pub enum Option<T> {
    None,
    Some(T),
}

// Check the value
if value.is_some() { /* exists */ }
if value.is_none() { /* doesn't exist */ }
```

### Result<T, E>

Use `Result` for operations that might fail:

```rust
pub enum Result<T, E> {
    Ok(T),
    Err(E),
}

// Check the result
if result.is_ok() { /* succeeded */ }
if result.is_err() { /* failed */ }
```

**When to use which**:
- `Option`: Value might not exist (e.g., searching for an item)
- `Result`: Operation might fail with an error (e.g., file I/O, parsing)

## Macros

Macros expand at compile time and are more powerful than functions:

```rust
macro_rules! my_macro {
    () => {
        println!("Check out my macro!");
    };
    ($val:expr) => {
        println!("Value: {}", $val);
    }
}

fn main() {
    my_macro!();
    my_macro!(7777);
}

// Export from a module
mod macros {
    #[macro_export]
    macro_rules! exported_macro {
        () => { println!("Exported!"); };
    }
}
```

**Why macros matter**: They can take variable arguments and implement traits at compile time, which functions cannot do.

## Iteration Patterns

### Vector iteration

```rust
let fruits = vec!["banana", "raspberry"];

// Manual iteration
let mut iter = fruits.iter();
assert_eq!(iter.next(), Some(&"banana"));
assert_eq!(iter.next(), Some(&"raspberry"));
assert_eq!(iter.next(), None); // End of iterator

// Functional style
fruits.iter().map(|x| capitalize_first(x)).collect();
```

### Hashmap iteration

```rust
for (key, value) in &*map { /* both */ }
for key in map.keys() { /* keys only */ }
for value in map.values() { /* values only */ }
```

### Iterator types

```rust
let names = vec!["Bob", "Frank", "Ferris"];

// iter() - borrows immutably, doesn't consume
for name in names.iter() {
    println!("{}", name);
}

// into_iter() - consumes the collection
for name in names.into_iter() {
    println!("{}", name);
}

// iter_mut() - borrows mutably
for name in names.iter_mut() {
    *name = "Hello";
}
```

## Recursive Data Structures

Use `Box` for recursive types:

```rust
enum List {
    Cons(i32, Box<List>),
    Nil,
}

let list = List::Cons(1, Box::new(
    List::Cons(2, Box::new(
        List::Cons(3, Box::new(List::Nil))
    ))
));
```

## Conditionals

### if/else

```rust
let n = 5;
if n < 0 {
    println!("{} is negative", n);
} else if n > 0 {
    println!("{} is positive", n);
} else {
    println!("{} is zero", n);
}
```

### match

```rust
match number {
    1 => println!("One!"),
    2 | 3 | 5 | 7 | 11 => println!("Prime!"),
    13..=19 => println!("A teen"),
    _ => println!("Not special"),
}

// Match is an expression
let binary = match boolean {
    false => 0,
    true => 1,
};
```

### loop (infinite)

```rust
let mut count = 0;
loop {
    count += 1;
    if count == 3 {
        continue; // Skip to next iteration
    }
    println!("{}", count);
    if count == 5 {
        break; // Exit loop
    }
}
```

### while

```rust
let mut n = 1;
while n < 101 {
    if n % 15 == 0 {
        println!("fizzbuzz");
    } else if n % 5 == 0 {
        println!("buzz");
    } else {
        println!("{}", n);
    }
    n += 1;
}
```

### for

```rust
// Range (exclusive end)
for n in 1..101 {
    println!("{}", n);
}

// Range (inclusive end)
for n in 1..=100 {
    println!("{}", n);
}
```

### if let

```rust
let optional = Some(String::from("rustlings"));
if let Some(word) = optional {
    println!("The word is: {}", word);
} else {
    println!("No value");
}
```

### while let

```rust
let mut optional = Some(0);
while let Some(i) = optional {
    if i > 9 {
        println!("Greater than 9, quit!");
        optional = None;
    } else {
        println!("i is {:?}. Try again.", i);
        optional = Some(i + 1);
    }
}
```

## Traits

Add methods to types:

```rust
trait AppendBar {
    fn append_bar(self) -> Self;
}

impl AppendBar for String {
    fn append_bar(self) -> Self {
        format!("{}Bar", self)
    }
}

let s = String::from("Foo");
let s = s.append_bar(); // "FooBar"
```

## Testing

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_assertions() {
        assert!(true);
        assert_eq!(true, true);
        assert_ne!(true, false);
    }
}
```

## Threading and Concurrency

### Arc (Atomic Reference Counting)

Share data across threads:

```rust
use std::sync::Arc;
use std::thread;

let apple = Arc::new("the same apple");
for _ in 0..10 {
    let apple = Arc::clone(&apple);
    thread::spawn(move || {
        println!("{:?}", apple);
    });
}
```

### Mutex for shared mutable state

```rust
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

#[derive(Debug)]
struct JobStatus {
    jobs_completed: u32,
}

fn main() {
    let status = Arc::new(Mutex::new(JobStatus { jobs_completed: 0 }));
    let status_shared = Arc::clone(&status);
    
    thread::spawn(move || {
        for _ in 0..10 {
            thread::sleep(Duration::from_millis(250));
            let mut status = status_shared.lock().unwrap();
            status.jobs_completed += 1;
        }
    });
    
    while status.lock().unwrap().jobs_completed < 10 {
        println!("waiting...");
        thread::sleep(Duration::from_millis(500));
    }
}
```

## Security Essentials

### Unsafe Code Audit Checklist

`unsafe` blocks bypass Rust's safety guarantees. Look for:

- `unsafe` blocks
- `extern "C"` functions
- `ptr::copy*`, `std::mem::transmute`
- `MaybeUninit`, raw pointers, `ffi` modules

**Example vulnerability** (buffer overflow):

```rust
use std::ptr;

fn vuln_copy(src: &[u8]) -> Vec<u8> {
    let mut dst = Vec::with_capacity(4);
    unsafe {
        // ❌ Copies src.len() bytes to 4-byte buffer
        ptr::copy_nonoverlapping(src.as_ptr(), dst.as_mut_ptr(), src.len());
        dst.set_len(src.len());
    }
    dst
}
```

**Prevention**:
- Use `#![forbid(unsafe_code)]` crate-wide
- Use `#[deny(unsafe_op_in_unsafe_fn)]` (Rust 1.68+)
- Run Miri: `rustup component add miri && cargo miri test`

### Dependency Auditing

```bash
cargo install cargo-audit
cargo audit              # Check Cargo.lock for vulnerabilities
cargo audit --deny warnings  # Fail CI on warnings
```

### Code Coverage

```bash
cargo binstall cargo-tarpaulin
cargo tarpaulin          # Generate coverage report
```

### Supply Chain Verification

```bash
cargo install cargo-vet
cargo vet init           # Create vet.toml
cargo vet --locked       # Verify Cargo.lock
```

### Fuzzing

```bash
cargo install cargo-fuzz
cargo fuzz init          # Create fuzz_targets/
cargo fuzz run fuzz_target_1  # Run with libFuzzer
```

## Quick Reference

| Concept | Use When |
|---------|----------|
| `Option<T>` | Value might not exist |
| `Result<T, E>` | Operation might fail |
| `iter()` | Read-only iteration |
| `iter_mut()` | Mutable iteration |
| `into_iter()` | Consume collection |
| `Arc<T>` | Share data across threads |
| `Mutex<T>` | Shared mutable state |
| `unsafe` | FFI, raw pointers (audit carefully) |

## References

- RustSec Advisory Database: https://rustsec.org
- Cargo-vet: https://mozilla.github.io/cargo-vet/
