Repository for assignment 3 in CASPL university course.

In this assignment, we implemented user-level threads which are called co-routines.
purely in x86 assembly and some basic C standard library functions (like `malloc`, `free` and `printf`).
We also used floating point x86 registers to do some calculations.

As there are user-level threads, we had to implement a scheduler.
The scheduler also operated on a user-level thread and its policy was round robin.
As all the threads were user-level, each thread had to manually give up control back to the scheduler.

[Full assignment description](https://www.cs.bgu.ac.il/~caspl202/Assignments/Assignment_3)  
[Course assignments descriptions](https://www.cs.bgu.ac.il/~caspl202/Assignments)
