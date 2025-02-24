# fortea
Forth-like stack programming language interpreter written in M4 arm assembly.

Currently WIP with more features and freedoms planned.

## Features
- Takes in positive 64 bit integers, though displays signed
- Gives access to "local" variables, through forth-like `!` and `@`, but using index instead of address
- Is able to perform `+`, `-`, `*`, `/` operations
- Also has `,` for a raw char input and `.` for a number output
- Comments are opened and closed with`(` and `)`
- Can use `if` with truth being defined C-style (0 = false, else true)
- Can define new words, which also enables recursion.

## Examples
```forth
123 123 + . (-- prints 246)
: get1num , 48 - ; (get 1 char from stdin and converts it to a number)
55 0 ! 45 0 @ + . (-- prints 100)
(input 6) get1num . (prints 6)
```

## Compile and Run
Makefile should provide everything essential to get this on Mac, 
so in that case just run `make`. 

For other platforms, using assembler and linker as usual should suffice, 
but changes may be required due to architecture differences.

Current implementation takes in one string input, 
which would then be run. For example `./fortea '1 1 + .'`

## Implementation Details
Stack is used for everything.
It is the stack for operations, 
and it also reserves space for local variables and definitions.

Local variables are just an array using some stack space.

Definitions are the 8 byte reference to string (`: x 1 ; (...)` would be `x 1 ; (...)`), 
2 byte length of id, and 6 byte length of everything until `;` for some potential uses. 
These are also stored at dedicated stack space. 
Using direct strings has its benefits and negatives, 
but it is efficient and effective without being annoying to implement.

Words are looked up in the definitions, and if not, found from builtins.

Currently Array and Definitions are reserved for 1024 bytes each, 
which is 128 definitions and 256 local variables.
