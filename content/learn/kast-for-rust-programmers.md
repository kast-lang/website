+++
title = "Kast for Rust programmers"
weight = 10
+++

# Comments

```kast
# This is a line comment
(# This is a block comment #)
```

**TODO** doc comments?

# Variables and mutability

{% compare_code() %}
```rust
let x: i32 = 5;
// x = 3; // compiler error
let mut x = "hi";
x = "yo";
```
# SPLIT
```kast
let x :: Int32 = 5;
# x = 3; # compiler error
let mut x = "hi";
x = "yo";
```
{% end %}

Compile-time constants and compile time evaluation:

{% compare_code() %}
```rust
const C: u64 = 123;

const fn twice(x: u64) -> u64 {
    x * 2
}

let c_times_two = const { twice(C) };
```
# SPLIT
```kast
const C :: UInt64 = 123;

const twice = (x :: UInt64) -> UInt64 => (
    x * 2
);

let c_times_two = @eval twice(C);
```
{% end %}

Shadowing works same as in rust:

{% compare_code() %}
```rust
let x :: Int32 = 0;
let x = x + 1;
{
    let x = x + 2;
    println!("{x}"); // prints 3
}
println!("{x}"); // prints 1
```
# SPLIT
```kast
let x :: Int32 = 0;
let x = x + 1;
(
    let x = x + 2;
    dbg.print(x); # prints 3
);
dbg.print(x); # prints 1
```
{% end %}

# Data types

Same as Rust, Kast is a statically typed language, with similar inference.

{% compare_code() %}
```rust
let guess: u32 = "42".parse()
    .expect("Not a number!");
```
# SPLIT
```kast
let guess :: UInt32 = "42" |> parse;
# If parse fails it throws a 
# **checked** exception
# It must be handled somewhere,
# but not necessarily immediately
```
{% end %}

To help the inference (or assert the type) any expr/pattern can be type ascribed.
Unlike Rust, type ascription can be used anywhere

```kast
let guess :: UInt32 = ("42" :: &String)
    |> (parse :: &String -> UInt32)
    :: UInt32;
```

Kast is supposed to depend as little as possible on the target platform,
giving you way to specify the types from the target like this:
`const Int128 :: type = @native "int128";`.
The most important target for Kast though is the interpreter,
which allows you to evaluate the code during compile time.
Common types are defined in the interpreter but their availability
on target depends on specific backend.

Same as Rust we have scalar types like integers, floating-point numbers, booleans, and characters.

- Unit type `()`
- `Bool` (`true`/`false`)
- `Int32`/`Int64`
- `Float64`
- `Char`
- `String`

## Default literal type

Unlike Rust, we don't have `{integer}`/`{float}` type for literals.
It is also not required to use `.` for floating point numbers if the type is inferred:
`let x :: Float64 = 123;`.
Type needs to be specified (or inferred).
Default inference can be tweaked with compile time context (more on contexts later),
which basiclly runs a function that returns the default literal type
given literal as a string, at compile time:

```kast
use std.compiler.default_number_type;
(
    @comptime with default_number_type = _ => :None;
    let x = 123; # compiler error: number literal type could not be inferred
);
(
    @comptime with default_number_type = _ => :Some Int32;
    let x = 123; # inferred as Int32
);
(
    @comptime with default_number_type = _ => :Some Int64;
    let x = 123; # inferred as Int64
);
(
    # mimic Rust behavior
    @comptime with default_number_type = s => (
        if String.contains(s, .substring = ".") then (
            :Some Float64
        ) else (
            :Some Int32
        )
    );
    let x = 123;   # inferred as Int32
    let x = 123.0; # inferred as Float64
);
```

**TODO**: not implemented yet, but you also can have number literals be treated as custom types:
`let x :: BigInt = 1238762345761576453124617235476124`;

## Overflow behavior

Overflow behaviour for integers is also working through the context system -
behavior depends on what is currently chosen.
By default it is ~panicking on overflow~(**TODO** figure out what should be default), but you can change it:

```kast
add_int32 :: (a :: Int32, b :: Int32) -> Int32 with potential_overflows;

(
  with saturating_behavior;
  a + (with wrapping_behavior; b + c)
)

# for compiler to optimize the checks away
with undefined_behavior_on_overflow (
  a + b
)
```

{% impl_status() %}
Not implemented yet
{% end %}

## Tuples/structs

In Kast, tuples can have both unnamed and named fields at the same time.
Then, custom structs are just newtyped anonymous tuples.
In any case you use `{}` to group data.

{% compare_code() %}
```rust
type A = (i32, String)
struct B(i32, i32);
struct C { x: f64, y: f64 }
```
# SPLIT
```kast
const A = { Int32, String };
const B = newtype { Int32, Int32 };
const C = newtype { .x :: Float64, .y :: Float64 };

const ImpossibleInRust = {
    Int32,
    Float64,
    .named :: String,
};
```
{% end %}

This behavior is shared with function args and allows to have functions with unnamed/named arguments.

**TODO**: also have optional/repeated/kwargs

## Lists

For now Kast just has lists as alternative to Rust's `Vec`.
Lists will most likely be changed.

{% compare_code() %}
```rust
let mut x: Vec<i32> = vec![1, 2, 3];
x.push(123);
dbg!(x.len());
```
# SPLIT
```kast
let mut x :: [Int32] = [1, 2, 3];
&mut x |> List.push_back(123);
dbg.print(&x |> List.length);
```
{% end %}

## Strings

For now Kast only has a single type for strings.
But, the string literals can act both as strings and references to strings
(depends on inference, ~defaults to owned string~).

{% compare_code() %}
```rust
let x = "hello"; // x: &str
let x = String::new("world"); // x: String
```
# SPLIT
```kast
let x :: &String = "hello";
let x :: String = "world";
```
{% end %}

# Functions

All functions work as closures in Kast.

{% compare_code() %}
```rust
type F = fn(i32) -> String;
type G = fn(i32, f64) -> bool;

let foo: fn(i32, i32) -> i32 = |x, y| x + y;
fn goo(x: i32, y: i32) -> i32 {
    x + y
}
```
# SPLIT
```kast
const F = Int32 -> String;
const G = (Int32, Float64) -> Bool;

let foo :: (Int32, Int32) -> Int32 = (x, y) => x + y;
let goo = (x :: Int32, y :: Int32) -> Int32 => (
    x + y
);
```
{% end %}

Unlike rust, Kast supports recursive closures,
but it needs to be declared in a recursive scope (module).
All the bindings that are introduced in a module
become the fields of the resulting struct.

```kast
let rec_scope = module (
  let f = depth => (
    if depth < 3 then (
      print("inside f");
      dbg.print(depth);
      g (depth + 1);
    );
  );
  let g = depth => (
    print("inside g");
    dbg.print(depth);
    f (depth + 1);
  );
);
rec_scope.f(0 :: Int32)
```

Function args share syntax and behavior of tuples, and can have both unnamed and named args:

```kast
const sort_by_key :: (&mut [Item], .key :: &Item -> Int32) -> () = _;
sort_by_key(&mut items, .key = item => calculate_key(item));
```

You can also use pipe operator: `"hello" |> print`.

## Context system

Another key feature for Kast in the context system.
It is similar to effect systems/capabilities/implicit arguments.

Examples of contexts would be:

- access to io
- exception handlers
- loggers
- unsafe
- async runtime

Basically, functions in Kast are also having context types
as another part of function type specification -
`std.print :: &string -> () with output`.
This says that `std.print` needs access to output in order to be able to be called.

When calling a function, it is required that the context is available.
Otherwise there will be a compilation error.

Contexts can be of any type, and you can introduce a context by providing a value:

```kast
# In std:
const output = @context {
    .write :: String -> (),
};

with output = {
    .write = text => launch_the_rocket_with_message(text),
};

print("hello, world");
```

In this case `print` will not write to the stdout but instead launch a rocket.

{% impl_status() %}
Inference needs to be improved
{% end %}

As we've seen earlier, contexts are also used at compile time
in order to change some compiler behavior.

## Mutability with contexts

Mutability in Kast is also done with the context system -
if a function needs to mutate a variable it means
that it requires mutable access to the variable.

```kast
let mut x = 0;
let inc = () => x += 1;
let dec = () => x -= 1;
inc(); inc(); dec();
dbg x; # prints 1
```

This example doesn't compile in Rust but it does in Kast.
Both functions here only capture the *pointer* to x, without capturing the access.
Instead, access is going to be required when calling these functions.
The full type of `inc` and `dec` is `() -> () with mutable_access[x]`.
Mutable access context is introduced automatically when declaring a mutable variable.

The idea of separating data from persission comes from the
[GhostCell](https://plv.mpi-sws.org/rustbelt/ghostcell/),
but is made ergonomic by combining it with context system
and having it a language feature instead of a library.

{% impl_status() %}
Not implemented yet

Lifetimes are also planned
{% end %}

# Control flow

# Generics

Generics in Kast are very similar to regular functions.
A generic type is just a function that takes a type and returns a new type.
A generic function is a function that thats a type and returns a function.

The only difference is that generic arguments can be omitted and be fully inferred.

{% compare_code() %}
```rust
struct Foo<T> { field: T }
let foo: Foo<i32> = Foo { field: 123 };
fn id<T>(x: T) { x }

// explicit generic arg with turbofish
let x = id::<i32>(123);
// generic arg inferred based on result
let x: i32 = id::<_>(123);
// generic auto instantiation
let x: i32 = id(123);
```
# SPLIT
```kast
const Foo = [T] newtype { .field :: T };
let foo :: Foo[Int32] = { .field = 123 };
let id = [T :: type] (x :: T) => x;

# explicit generic arg
let x = id[Int32](123);
# generic arg inferred based on result
let x :: Int32 = id[_](123);
# generic auto instantiation
let x :: Int32 = id(123);
```
{% end %}

# Traits

{% compare_code() %}
```rust
struct Foo { a: i32, b: i32 }
trait Clone {
    fn clone(&self) -> Self;
}
impl Clone for Foo {
    fn clone(&self) {
        Self {
            a: self.a,
            b: self.b,
        }
    }
}
fn duplicate<T>(x: T) -> (T, T)
where T: Clone {
    (
        <T as Clone>::clone(&x),
        <_ as Clone>::clone(&x),
    )
}
let foos: (Foo, Foo) = duplicate(Foo { a: 1, b: 2 });
```
# SPLIT
```kast
const Foo = newtype { .a :: Int32, .b :: Int32 };
const Clone = [Self] newtype {
    .clone = &Self -> Self,
};
impl Foo as Clone = {
    .clone = self => {
        .a = self^.a,
        .b = self^.b,
    },
};
let duplicate = [T] (x :: T) -> { T, T }
with (T as Clone) => {
    (T as Clone).clone(&x),
    (_ as Clone).clone(&x),
};
let foos :: { Foo, Foo } = duplicate({ .a = 1, .b = 2 });
```
{% end %}

In Kast, trait impls are just normal values, and traits are just types (generic types).
Since generic types are functions returning types,
implementing a trait for a type means providing the value with type equal to
applying that function (generic) with argument being the type for which you implement the trait.

`T as Trait :: Trait[T]` is an expression that retieves the implementation.
`impl T as Trait = Impl :: Trait[T]` is how you implement a trait.

{% impl_status() %}
Can only implement for concrete types - no generic implementations yet

Trait bounds are not implemented yet
{% end %}

## Macros

{% compare_code() %}
```rust
macro_rules! my_macro {
    ($e:expr) => (
        let x = $e;
        dbg!(x);
    )
}
my_macro!(2 + 2);
```
# SPLIT
```kast
const my_macro = e => `(
    let x = $e; dbg x
);
my_macro!(2 + 2 :: Int32);
```
{% end %}

Macros in Kast are also almost normal functions, but they operate on ASTs.
In the above example `my_macro` has type `Ast -> Ast`,
so its a function that takes ast and returns ast.

`` `(some code) `` is the quoting operator,
similar to `quote!` macro from the quote crate in rust -
it parses the code and produces the ast.
Inside the quote you can use the unquote operator `$` to interpolate expressions.

Kast macro system can be used for extending systax.

```kast
@syntax ternary 13.1 = condition "?" then_case ":" else_case ->;
impl syntax ternary = (.condition, .then_case, .else_case) => `(
    if $condition then $then_case else $else_case
);

let x :: Int32 = true ? 1 : 0;
```

{% impl_status() %}
could have ways to inspect asts given to macros,
like ast pattern matching is not implemented yet
{% end %}
