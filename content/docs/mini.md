+++
title = "MiniKast"
description = "MiniKast"
weight = 5
+++

<img style="width:10%" src="/minikast.png"/>

MiniKast is a simple language used as intermediate compilation step when compiling Kast code.

Not really intended to be written by humans.

## Compared to Kast

- no anonymous types (tuples/variant)
- no distinction between mutable/non mutable variables/references
- no variant types with associated data (no ADTs),
  instead enum for tag + union for data inside a struct is used
- no RAII
- context system is present, but no context type safety
- no memory safety
- no macros
- no compile time evaluation
- no types as values
- no generics - but there are templates instead -
  type checked at instantiation instead of at definition, always monomorphized
  (Kast's generics are supposed to be existentializable/monomorphized based on compilation setting)
- closures are still present
- no operators (math needs to be done with fn calls)
- no type inference, only type checking
- some other things...

## Overview

MiniKast program has following top-level items:

- Types
- Functions
- Constants
- Contexts
- Templates

Unlike Kast, in MiniKast these **must** be specified at top level.

The order should not matter.

## Builtin types

- `()` - unit type (no data)
- `Bool` - booleans with `true` and `false` values
- `Char` - unicode code point. `'a'`, `''`
- `String` - strings (data pointer + length in C). `"Hello, world"`
- Integers - `Int`/`UInt`, and with specified bit widths: `Int8`/`UInt64`/...
- Floats: `Float32` & `Float64`
- References: `&Type`
- Functions: `(Arg1Type, Arg2Type) -> ResultType`. Functions can also specify calling convention (default call convention uses implicit context argument passing) like `@call "C" () -> Int`.
- Target specific types:
  `@native "<some target-specific type>"`.
  Meaning depends on the target.
  For transpiling basically inlines string as type, like `@native "size_t"`.
- `List[ElementType]` - list of `ElementType` (pointer + length in C).
  `let a :: List[Int] = [1, 2, 3, 4, 5];`.
- `UnwindToken[ResultType]` - token used for unwinding with unsindable block having type `ResultType`
- `Any` - anything. Should usually be used with indirection like `&Any` (becomes `void*` in C)
- `@context` - type of implicit context object

## Defining custom types

```ks
const MyType = <type definition>;
```

### Structs

```ks
const MyStruct = struct {
    .a :: Int,
    .b :: String,
};

const main = () => (
    let foo :: MyStruct = {
        .a = 123,
        .b = "Hello",
    };
    let a :: Int32 = foo.a;
    let b :: String = foo.b;
);
```

### Enums

Enumerated types with no extra data

```ks
const MyEnum = enum {
    | :Variant1
    | :Variant2
    | :LastVariant
};

const MyEnum_Variant1 = () -> MyEnum => (
    :Variant1
);

const main = () => (
    let my_enum :: MyEnum = :Variant1;
    # == only works for enums (TODO might change it to `is` keyword)
    if my_enum == :Variant2 then ();
);
```

### Unions

Same as structs but all members share same memory (only single member is supposed to be used)

```ks
const MyUnion = struct {
    .a :: Int,
    .b :: String,
};

const main = () => (
    let foo :: MyUnion = { .a = value };
    let a = foo.a;
    # let b = foo.b; # This is undefined behavior!!!
)
```

### Native types

You can specify types already present in the target (for things like C interop):

```ks
@native
const Texture = @opaque_type;
```

### Type aliases

```ks
const AliasToInt = type Int;
```

## Functions

Defining top-level function:

```ks
const fib = (n :: Int) -> Int => (
    if less[Int](n, 2) then (
        1
    ) else (
        add[Int](fib(sub[Int](n, 1)), fib(sub[Int](n, 2)))
    )
);
```

MiniKast also supports closures:

```ks
let b :: Int = 456;
# construct a closure (b is going to be captured by reference by default)
let add_b = (a :: Int) -> Int => (
    # native exprs allow embedding target-specific code
    @native "\(a) + \(b)" # we can use interpolations in native exprs
);
```

## Templates

Templates are top level items which can have any amount of **type** arguments.

```ks
const GenericStruct = [T] {
    .field :: T,
};

const sqr = [T] (arg :: T) -> T => (
    mul[T](arg, arg)
);
```

Templates are not type checked until instantiated:

```ks
let four :: Int = sqr[Int](2);
let nine :: Float32 = sqr[Float32](3);
```

## Expressions

Like Kast, MiniKast is an expression based language -
there is no distinction between statements and expressions.

```ks
let unit :: () = ();
let x :: Int = uninitialized; # Must explicitly say is we want data to be uninitialized
let ref_to_x :: &Int = &x;
ref_to_x^ = 10;

let s :: String = if true then (
    "condition was true"
) else (
    "condition was false"
);

let list :: List[Int] = [1, 2, 3, 4, 5];

# only infinite loops are present
@loop (
    some_function(arg1, arg2, arg3); # calling a fn
);

# in order to break/continue loops, return from fns or similar use unwinding
let result :: Int = unwindable main_loop (
    @loop (
        if need_to_break then (
            unwind main_loop with 123;
        );
    );
    456 # if control flow reached the end of unwindable block, this would be result
);
```

## Defer

`defer` keyword can be used to run code at the end of the current scope

```ks
let x = 1;
(
    defer (
        x = 2;
    );
    x = 3;
    print(x); # prints 3
);
print(x); # prints 2
```

## Context system

MiniKast, same as Kast has implicit context system.
Unlike Kast it is not checked at compile time and should be used carefully.

```ks
const MyContext = @context Int; # specify the context

const f = () => (
    let current_value = @current MyContext; # This is UB if MyContext was not initialied yet
);

const main = () => (
    (
        with MyContext = 123; # provide value for context for duration of the scope
        f();
    );
    # f() # this would result in UB
);
```

Every context is becoming a field in the implicit `@context` object which can be referred to explicitly.
Techincally `@context` is stored behind a reference,
and each function (default `@call` convention) has implicit argument - reference to current `@context`.

```ks
# save current implicit context state
let saved_context :: @context = @context;
# since implicit context is technically stored as reference,
# we can assign to that reference (might change?)
let &@context = saved_context;
# this provides a way to introduce context system from scratch
# (like in `@call "C"` functions, to be able to call regular functions)
let &@context = uninitialized;
@context.MyContext = 123;
```

## Compilation Targets

MiniKast is supposed to be target indenpendent. Currently there is:

- Transpiler to C
- Transpiler to JavaScript (probably broken atm)

Other targets are planned in the future

## Example code

If you want to see example code, check out this simple game made for Ludum Dare 59:

<https://github.com/kuviman/megahonk>

Uses raylib, transpiles to C and works in browser via emscripten.
