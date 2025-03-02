# fortea
Forth-like stack programming language interpreter written in M4 arm assembly.

Currently WIP with more features and freedoms planned.

## Features
- Reads in positive 64 bit integers and strings
- Gives access to memory (quad-aligned), through forth-like `!` and `@`
- Can use `b!` and `b@` for bytes
- Local variables can be accessed by using the address
- Can reserve (malloc) and free memory with `#` and `$`
- Can use open(), close(), write(), read(), through `#f`, `$f`, `.f`, and `,f` commands
- Also provides `s,f` and `s.f` for strings
- Can use number and `%` to convert a number to a local variable address
- Is able to perform `+`, `-`, `*`, `/` operations
- Also has `,` for a raw char input and `.` for a number output (signed), `x.` for hex/pointers, `s.` for string
- Comments are opened and closed with`(` and `)`
- Can use `if` with truth being defined C-style (0 = false, else true)
- `dup` and `swap` are also provided
- Can define new words, which also enables recursion

## Examples
```forth
123 123 + . (-- prints 246)

: get1num , 48 - ; (gets 1 char from stdin and converts it to a number)

55 0% ! (space does not matter)
45 0% @ + . (-- prints 100)

(input 6) get1num . (prints 6)

2048 # $ (malloc and free)
```

You can also see the example files.

## Compile and Run
Makefile should provide everything essential to get this on Mac, 
so in that case just run `make`. 

For other platforms, using assembler and linker as usual should suffice, 
but changes may be required due to architecture differences.

Current implementation takes in one string input, 
which would then be run. For example `./fortea '1 1 + .'`

## Implementation Details
Stack is used for most things.
It is the stack for operations, 
and it also reserves space for local variables and definitions.

Local variables are just an 8 byte array using some stack space.

Definitions are the 8 byte reference to string (`: x 1 ; (...)` would be `x 1 ; (...)`), 
2 byte length of id, and 6 byte length of everything until `;` for some potential uses. 
These are also stored at dedicated stack space. 
Using direct strings has its benefits and negatives, 
but it is efficient and effective without being annoying to implement.

Words are looked up in the definitions, and if not, found from builtins.

Currently Array and Definitions are reserved for 256 and 1792 bytes respectively, 
which is 32 local variables and 224 definitions.

Strings are references to file. 
Printing them with printf utilizes the fact that they end with `"` 
which can be replaced by null. 
At the moment with minimal checking, this can be abused.
