module:
let fib = (n :: Int32) -> Int32 => (
    if n < 2 then (
        1
    ) else (
        fib(n - 1) + fib(n - 2)
    )
);
