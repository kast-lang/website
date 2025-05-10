+++
title = "Kast for Rust programmers"
sort_by = "weight"
+++

# Kast for Rust programmers

## Common programming concepts

### Variables and mutability

{% compare_code() %}
```rust
let x: i32 = 5;
// x = 3; // compiler error
let mut x = "hi";
x = "yo";
```
# SPLIT
```kast
let x :: int32 = 5;
# x = 3; # compiler error
let mut x = "hi";
x = "yo";
```
{% end %}

{% impl_status() %}
[mut is not respected currently](https://github.com/kast-lang/kast/issues/8)
{% end %}

{% compare_code() %}
```rust
const C: u64 = 123;
```
# SPLIT
```kast
comptime let C :: uint64 = 123;
```
{% end %}

{% impl_status() %}
its actually just `const C = 123` same as Rust for now because of
[technical issues](https://github.com/kast-lang/kast/issues/9)
{% end %}

Shadowing works same as in rust:

{% compare_code() %}
```rust
let x: i32 = 0;
let x = x + 1;
{
    let x = x + 2;
    println!("{x}"); // prints 3
}
println!("{x}"); // prints 1
```
# SPLIT
```kast
let x :: int32 = 0;
let x = x + 1;
(
    let x = x + 2;
    dbg x; # prints 3
);
dbg x; # prints 1
```
{% end %}

### Data types

Same as Rust, Kast is a statically typed language, with similar inference.

{% compare_code() %}
```rust
let guess: u32 = "42".parse()
    .expect("Not a number!");
```
# SPLIT
```kast
let guess :: uint32 = "42" |> parse;
# If parse fails it throws a 
# **checked** exception
# (it must be handled somewhere)
```
{% end %}

To help the inference (or assert the type) any expr/pattern can be type ascribed.
Unlike Rust, type ascription can be used anywhere

```kast
let guess :: uint32 = ("42" :: &string)
    |> (parse :: &string -> uint32)
    :: uint32;
```

Kast is supposed to depend as little as possible from the target platform,
giving you way to specify the types from the target like this:
`let int128 :: type = native "int128"`;
The most important target for Kast though is the interpreter,
which allows you to evaluate the code during compile time.
Common types are defined in the interpreter but their availability
on target depends on specific compiler.

Same as Rust we have scalar types like integers, floating-point numbers, booleans, and characters.
At the time of writing, we have these:

- bool (true/false)
- int32/int64
- float64
- char

#### Default literal type

Unlike Rust, we don't have `{integer}`/`{float}` type for literals.
We also don't have a default type for those literals (by default) -
type needs to be specified (or inferred).

```kast
let x = 123; # compiler error: number literal type could not be inferred
```

It is also not required to use `.` for floating point numbers if the type is inferred:
`let x :: float64 = 123;`.
The behaviour of no default can be changed for some sections of code
with compile time context (more on contexts later).
Basically, this runs a function that returns the default literal type
with the literal as a string, at compile time:

```
(
    comptime with (.default_number_type = _ => std.int32) :: std.default_number_type;
    dbg 123; # inferred as int32
);
(
    comptime with (.default_number_type = _ => std.int64) :: std.default_number_type;
    dbg 123; # inferred as float64
);
(
    # mimic Rust behavior
    comptime with (
        .default_number_type = s => (
            if std.contains (.s, .substring=".") then
                std.float64
            else
                std.int32
        ),
    ) :: std.default_number_type;
    dbg 123; # inferred as int32
    dbg 123.0; # inferred as float64
);

if false then (
    # no default - this is going to fail to compile
    std.dbg 123;
);
```

TODO: not implemented yet, but you also can have number literals be treated as custom types:
`let x :: BigInt = 1238762345761576453124617235476124`;

TODO: hex/octal/binary literals not supported yet

#### Overflow behavior

Overflow behaviour for integers is also working through the context system -
behavior depends on what is currently chosen.
By default it is panicking on overflow, but you can change it:

```
with saturating (
  a + with overflowing (b + c)
)

# for compiler to optimize the checks away
with undefined_behavior_on_overflow (
  a + b
)
```

{% impl_status() %}
Not implemented yet
{% end %}

#### Tuples/structs

In Kast, tuples can have both unnamed and named fields at the same time.
Then, custom structs are just newtyped anonymous tuples.

{% compare_code() %}
```rust
type A = (i32, String)
struct B(i32, i32);
struct C { x: f64, y: f64 }
```
# SPLIT
```kast
let A = (int32, string);
let B = newtype (int32, int32);
let C = newtype (.x = float64, .y = float64);

let ImpossibleInRust = (int32, float64, .named = string);
```
{% end %}

As we will see soon, all functions have just a single argument
and this allow to have functions with unnamed/named arguments

TODO: also have optional/repeated/kwargs

#### Lists

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
let x :: list[int32] = list[1, 2, 3];
list_push (&x, 123);
dbg (list_length &x);
```
{% end %}

#### Strings

For now Kast only ha a single type for strings.
But, the string literals can act both as strings and references to strings
(depends on inference, defaults to owned string).

{% compare_code() %}
```rust
let x = "hello"; // x: &str
let x = String::new("world"); // x: String
```
# SPLIT
```kast
let x :: &string = "hello";
let x :: string = "world";
```
{% end %}

### Functions

As said before, all functions is Kast have a single argument.
If you want multiple arguments, you use a tuple as argument.
Also, all functions work as closures in Kast.

{% compare_code() %}
```rust
type F = fn(i32) -> String;
type G = fn(i32, f64) -> bool;

let foo: fn(i32, i32) -> i64 = |x, y| x + y;
fn goo(x: i32, y: i32) -> i32 {
    x + y
}
```
# SPLIT
```kast
let F = int32 -> string;
let G = (int32, float64) -> bool;

let foo :: (i32, i32) -> i64 = (x, y) => x + y;
let goo = fn(x :: int32, y :: int32) {
    x + y
};
```
{% end %}

Unlike rust, Kast supports recursive closures,
but it needs to be declared in a recursive scope.
All the bindings that are introduced in a recursive scope
become the fields of the resulting struct.

```kast
let rec_scope = rec (
  let f = depth => (
    if depth < 3 then (
      print "inside f";
      dbg depth;
      g (depth + 1);
    );
  );
  let g = depth => (
    print "inside g";
    dbg depth;
    f (depth + 1);
  );
);
rec_scope.f (0 :: int32)
```

Calling a function does not require parentheses: `std.print "hello"`.
You can also use pipe operator: `"world" |> std.print`.

#### Context system

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
with (
    .write :: &string -> () = text => launch_the_rocket_with_message text,
) :: output;

std.print "hello, world";
```

In this case `std.print` will not write to the stdout but instead launch a rocket.

{% impl_status() %}
Inference needs to be improved
{% end %}

As we've seen earlier, contexts may also be introduced at comptime.
This can be used to change some compiler behavior.

#### Mutability with contexts

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

{% impl_status() %}
Mutability with context system is not implemented yet

Lifetimes are also planned
{% end %}

### Comments

### Control flow

## Generics

Generics in Kast are implemented as just functions.
A generic type is just a function that takes a type and returns a new type.
A generic function is a function that thats a type and returns a function.

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
let Foo :: type -> type = T => (.field = T);
let foo :: Foo int32 = ( .field = 123 );
let id = (T :: type) => ((x :: T) => x);

# calling a "generic" function
let x = id(int32)(123);
```
{% end %}

Actually, since we want the generic argument to be inferred sometimes,
and not be written explicitly Kast does have a dedicated type for it -
called templates.

Templates are just functions, but calling and defining them needs a different syntax.
We can also omit explicitly calling them and use auto instantiation.
But otherwise they are still just functions.

```kast
let Foo = forall[T :: type] { .field = T };

let foo :: Foo[int32] = ( .field = 123 );
# use _ to infer the argument
let foo :: Foo[_] = ( .field = 123 :: int32 );

let id = forall[T] { (x :: T) => x };
# explicit arg
let x = id[int32](123);
// arg inferred based on result
let x :: int32 = id[_](123);
// auto instantiation
let x :: int32 = id(123);
```

### Traits

{% compare_code() %}
```rust
struct Foo { a: i32, b: i32 }
trait Clone {
    fn clone(&self) -> Self;
}
impl Clone for Foo {
    fn clone(&self) {
        (self.a, self.b)
    }
}
fn duplicate<T: Clone>(x: T) -> (T, T) {
    (
        <T as Clone>::clone(&x),
        <_ as Clone>::clone(&x),
    )
}
let foo: (Foo, Foo) = duplicate(Foo { a: 1, b: 2 });
```
# SPLIT
```kast
const Foo :: type = ( .a = int32, .b = int32);
const Clone = forall[Self] {
    .clone = &Self -> Self,
};
impl Foo as Clone = (
    .clone = self => ( .a = (self^).a, .b = (self^).b),
);
let duplicate = forall[T] {
    fn (x :: T) -> (T, T) {
        (
            (T as Clone).clone(&x),
            (_ as Clone).clone(&x),
        )
    }
};
let foo :: (Foo, Foo) = duplicate ( .a = 1, .b = 2 );
```
{% end %}

In Kast, trait impls are just normal values, and traits are just types (generic types).
Since generic types are functions returning types,
implementing a trait for a type means providing the value with type equal to
applying that function (template) with argument being the type for which you implement the trait.

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
const my_macro = macro (e) => `(
    let x = $e; dbg x
);
my_macro!(2 + 2 :: int32);
```
{% end %}

Macros in Kast are also almost normal functions, but they operate on ASTs.
In the above example `my_macro` has type `macro ast -> ast`,
so its a function that takes ast and returns ast.

`` `(some code) `` is the quoting operator,
similar to `quote!` macro from the quote crate in rust -
it parses the code and produces the ast.
Inside the quote you can use the unquote operator `$` to interpolate expressions.

Kast macro system can be used for extending systax.

```kast
syntax ternary -> 13.1 = condition "?" then_case ":" else_case;
impl syntax ternary = macro (.condition, .then_case, .else_case) => `(
    if $condition then $then_case else $else_case
);

let x :: int32 = true ? 1 : 0;
```

{% impl_status() %}
ast pattern matching is not implemented yet
{% end %}
