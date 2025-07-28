# Kernel's source code


# Index

- [main.zig](./main.zig)
>   Program root and logical entry

- [interrupts.zig](./interrupts.zig)
>   Implementation of main Exeptions and general
>   interruptions

- [adam.zig](./adam.zig)
>   Hypertask implementation


- [auth/](./auth/)
>   Authentication Service \
>   Provides access to users data and permitions

- [boot/](./boot/)
>   Routines right after booting

- [debug/](./debug/)
>   Debugging utils

- [devices/](/devices/)
>   Devices Service \
>   Handles general device protocols

- [fs/](./fs/)
>   File System Service \
>   Provides access to virtual and physical
>   files and drivers

- [gl/](./gl/)
>   Provisory Graphics Library \
>   Draws text in the screen

- [interop/](./interop/)
>   Interoperability utilities \
>   Provides utilities to interoperate with C
>   and C-based ABI

- [mem/](./mem/)
>   Memory \
>   Virtual memory managing and allocation

- [modules/](./modules/)
>   Modules Service \
>   Manage modules, drivers and extensions

- [system/](./system/)
>   System-dependent General Implementations \
>   Support for low level operations specific for \
>   different systems, such as x86_64 and aarch64

- [threading/](./threading/)
>   Threading Service \
>   Manage processes, tasks and multitheading

- [utils/](./utils/)
>   Utilities and Miscelaneous

- [os/](./os/)
>   Zig freestanding overridings
