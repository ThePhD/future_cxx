---
title: Transparent Function Aliases
date: May 15th, 2021
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis, LLC) \<<shepherd@soasis.org>\>
layout: paper
hide: true
---

_**Document**_: n2729  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Library Developers, Long-Life Upgradable Systems Developers, ABI Opinion Havers  
_**Latest Revision**_: [https://thephd.dev/_vendor/future_cxx/papers/C%20-Transparent%20Function%20Aliases.html](https://thephd.dev/_vendor/future_cxx/papers/C%20-Transparent%20Function%20Aliases.html)

<div class="pagebreak"></div>

<div class="text-center">
<h6>Abstract:</h6>
<p>
This paper attempts to solve 2 intrinsic problems with Library Development in C, including its Standard Library. The first is the ability to have type definitions that are just aliases without functions that can do the same. The second is ABi issues resulting from the inability to provide a small, invisible indirection layer.
</p>
<p>
This proposal provides a simple, no-cost way to indirect a function's identifier from the actual called function, opening the door to a C Standard Library that can be implemented without fear of backwards compatibility/ABI problems. It also enables general developers to upgrade their libraries seamlessly and without interruption. 
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 0 - May 15th, 2021

- Initial release. ✨




# Introduction & Motivation

After at least 3 papers were burned through attempting to [solve the intmax_t problem](https://thephd.dev/intmax_t-hell-c++-c), a number of issues were unearthed with each individual solution[^N2465] [^N2498] [^N2425] [^N2525]. Whether it was having to specifically lift the ban that §7.1.4 places on macros for standard library functions, or having to break the promise that `intmax_t` can keep expanding to fit larger integer types, the Committee and the community at large had a problem providing this functionality.

Thankfully, progress is being made. With Robert Seacord's "Specific-width length modifier" paper was approved for C23[^N2680], we solved one of the primary issues faced with `intmax_t` improvements, which was that there was no way to print out a integral expression with a width greater than `long long`. Seacord's addition to the C standard also prevented a security issue that commonly came from printing incorrectly sized integers as well: there's a direct correlation between the bits of the supported types and the bits of the given in the formatting string now, without having to worry about the type beyond a `sizeof(...)` check. This solved 1 of the 2 core problems.



## Remaining Core Problem - Typedefs, ABI, and Macros

Library functions in a "very vanilla" implementation of a C Standard Library (e.g., simply a sequence of function declarations/definitions of the exact form given in the C Standard) have a strong tie between the name of the function (e.g., `imaxabs`) and the symbol present in the final binary (e.g., `_imaxabs`). This symbol is tied to a specific numeric type (e.g., `typedef long long intmax_t`), and upgrading that type breaks old binaries that still call the old symbol (`_imaxabs` being handed a `__int128_t` instead of a `long long` in a world where things are upgraded can result in the wrong registers being used, or worse). Thusly, because the Standard Library is bound by these rules and because implementations rely on functions with `typedef`-based types in them to resolve to a very specific symbol, we cannot upgrade any of the `typedef`s (e.g., what `intmax_t` is) or change anything about the functions (e.g., change `imaxabs`'s declaration in any way non-inconsequential way).

Furthermore, macros cannot be used to "smooth" over the "real function call" because §7.1.4 specifically states that a user of the standard library has the right to deploy macro-suppressing techniques (e.g., `(imaxabs)(24)`) to call a library function (unless the call is designed to be a macro). This also includes preventing their existence as a whole with `#undef imaxabs`: every call after that `#undef` directive to `imaxabs(...)` must work and compile according to the Standard. While this guarantees users that they can always get a function pointer or a "real function name" from a given C Standard library function name, it also refuses implementations the ability to provide backwards compatibility shims using the only Standards-applicable tool in C++.



## Liaison Issue - Stopping C++ Improvements

This is both a C Standard Library issue and a C++ Standard Library issue. Not only is it impossible to change the C Standard Library, but because of these restrictions and because the C Standard Library is included by-reference into C++, we cannot make any of the necessary changes to solve this problem in C++. This elevates the level of this problem to a **liaison issue** that must be fixed if we are to make forward progress in both C and C++.



## Standardizing Existing Practice

While the C Standard Committee struggles with this issue, many other libraries that have binary interfaces communicated through shared or dynamically linked libraries have solved this problem. MSVC uses a complex versioning and symbol resolution scheme with its DLLs, which we will not be (and cannot) properly standardize. But, other implementations have been using implementation-defined aliasing techniques that effectively change the symbol used in the final binary that is different from the "normal" symbol that would be produced by a given function declaration.

These techniques, expanded upon in the design section as to why we chose the syntax we did for this proposal, have existed for at least 15 years in the forms discussed before, and longer with linker-specific hacks.



## C Issue - Prevented Evolution

Not fixing this issue also comes with a grave problem without considering C++ at all. We have no way of seamlessly upgrading our libraries without forcing end-users to consider ABI breakage inherit in changes type definitions or having library authors jump through implementation-specific and fraught hoops for creating (transparent) layers of indirection between a function call and the final binary. This means large swaths of C's standard library, due to §7.1.4, are entirely static and non-upgradeable, even if we write functions that use type definitions that can change.

This is, by itself, a completely untenable situation that hampers the growth of C. If we cannot even change type definitions due to constraints such as linkage names from old code without needing a computer-splitting architectural change (e.g., the change from `i686` "32-bit" architectures to `x86_64` "64-bit" architectures that allowed for `size_t` to change), with what hope could be possibly have in having C evolve to meet current hardware specifications and software needs? Users have been raging on about the lack of an `int128_t` in C, or a maximum integer type, and some implementers and platform users have stated:

> I am unreasonably angry about this, because the `intmax_t` situation has kept me from enabling completely-working first-class `int128` support out of clang for a decade. In that decade, I personally would have used 128b literals more times in personal and professional projects than the entire world has used intmax_t to beneficial effect, ever, in total.
>
> — [Steve Canon, Mathematician & Clang Developer](https://twitter.com/stephentyrone/status/1329796144193556482)

At the surface of this issue and as illustrated by the many failed — and one successful — papers for `intmax_t` is that we need a better way of type definitions that get used for interfaces in the C standard. Underlying it is a growing, tumescent cancer that has begun to metastasize in the presence of not having a reason to invent wildly new architectures that necessitate fundamentally recompiling the world. Our inability to present a stable interface for users in a separable and Standards-Compliant way from the binary representation of a function that we cherish so deeply is becoming a deepening liability. If every function (the fundamental unit of doing work) essentially becomes impossible to change in any way, shape, or form, then what we are curating is not a living and extensible programming language but a dying system that is unequivocally doomed to general failure and eventual replacement.




# Design

Our goal with this feature is to create a no-cost, zero-overhead function abstraction layer that prevents a type definition or other structure from leaking into a binary. From the motivation and analysis above, we need the following properties:

- It must be a concrete name, not a macro.
- It must be able to decay to a function pointer when referenced by name, like a normal function declaration, and that value must be consistent and usable in constant expressions.
- It should not require producing a symbol on non-interpreter implementations of C.
- It should allow for an implementation to upgrade or change the arguments or return type without requiring a detectable binary break on any C implementation.

To fill these requirements, we propose the a new _transparent-function-alias_ construct that, in general, would be used like such:

```cpp
extern long long __glibc_imaxabs228(long long);
extern __int128_t __glibc_imaxabs229(__int128_t);

/* ... */

#if __GNU_LIBC <= 228
	using imaxabs = __glibc_imaxabs228; // !!
#else
	using imaxabs = __glibc_imaxabs229; // !!
#endif

/* ... */

int main () {
	intmax_t x = imaxabs(-50);
	return (int)x;
}
```

It is composed of the `using` keyword, followed by an _identifier_, the `equal`s token, and then another _identifier_. The identifier on the right hand side must be either a previously declared _transparent-function-alias_ or name a function declaration. Below, we explore the merits of this design and its origins.



## Transparency - "Type Definitions, but for Functions"

We call this **transparent** because it is, effectively, unobservable from the position of a library consumer, that this mechanism has been deployed. The following code snippet illustrates the properties associated with Transparent Function Aliases:

```cpp
#include <assert.h>

int other_func (double d, int i) {
	return (int)(d + i) + 1;
}

int real_func (double d, int i) {
	return (int)(d + i);
}

using alias_func = real_func;
// No Constraint Violation
_Static_assert(&alias_func == &real_func);

/* The below are Constration Violations. You cannot redeclare */
/* a function alias with ANY signature. */
//void alias_func(double d, int i);
//void alias_func(void);

/* No Constraint Violation: redeclaration of an alias pointing
/* to the same declaration is fine. */
using alias_func = real_func;

/* Constraint Violation: redeclaration of an alias pointing */
/* to a different declaration than the first one is not */
/* allowed. */
//using alias_func = other_func;

int main ([[maybe_unused]] int argc, [[maybe_unused]] char* argv[]) {
	typedef int(real_func_t)(double, int);
	real_func_t* real_func_ptr = alias_func; // decays to function pointer to real_func
	real_func_t* real_func_ptr2 = &alias_func; // function pointer to real_func
	[[maybe_unused]] int is_3 = alias_func(2.0, 1); // invokes real_func directly
	[[maybe_unused]] int is_4 = real_func_ptr(3.0, 1); // invokes real_func through it's function pointer
	[[maybe_unused]] int is_5 = real_func_ptr2(3.0, 2); // invokes real_func through it's function pointer
	assert(is_3 == 3); // no constraint violation
	assert(is_4 == 4); // no constraint violation
	assert(is_5 == 5); // no constraint violation
	assert(real_func_ptr == &real_func); // no constraint violation
	assert(real_func_ptr == &alias_func); // no constraint violation
	assert(real_func_ptr2 == &real_func); // no constraint violation
	assert(real_func_ptr2 == &alias_func); // no constraint violation
	return 0;
}
```

The notable properties are:

- `alias_func` always "forwards" its calls to `real_func` without needing the end-user to call "`real_func`" directly;
- `alias_func` can be used in constant expressions, just like normal functions with their address taken;
- `alias_func`, like any other function call, cannot be redeclared as a normal function declaration of any form;
- `alias_func` cannot be re-aliased to a different function call after the first;
- any function pointer obtained from `real_func` is identical to a function pointer obtained `alias_func`; and,
- `real_func` and `alias_func` have identical addresses.

In short, `alias_func` works like any other function declaration would, but is not allowed to have its own function definition. It is simply an "alias" to an existing function at the language level. Given these properties, no implementation would need to emit a whole new function address for the given type; any binary-producing implementation would produce the same code whether the function was called through `alias_func` or `real_func`. It gets around the requirement of not being able to define C functions as macros, while maintaining all the desirable properties of a real C function declaration.

It also serves as a layer of indirection to the "real function".



## Inspiration: Existing Practice

It is not a coincidence in the initial example that we are using `__glibc` prefixes for the 2 `imaxabs` function calls. Tying a function to a name it does not normally "mangle" to in the linker is a common implementation technique among more advanced C Standard Library Implementations, such as musl-libc and glibc. It is also a common technique deployed in many allocators to override symbols found in downstream binary artefacts, albeit this proposal does not cover the "weak symbol" portion of the alias techniques deployed by these libraries since that is sometimes limited to specific link-time configurations, binary artefact distributions, and platform architecture.

Particularly, this library is focusing on the existing GCC-style attribute and a Clang-style attribute. The GCC attribute[^gcc-attribute] follows this proposal most closely, by effectively allowing for an existing function declaration to have its final output symbol "renamed":

```cpp
void __real_function (void) { /* real work here... */; }
void function_decl(void) __attribute__ ((alias ("__real_function")));
```

This code will set up `function_decl` to emit only the symbol `__real_function` when it is used or has its address taken. It is common implementation practice amongst compilers that are GCC-compatible and that focus on binary size reduction and macro-less, transparent, zero-cost indirection. For example, here is documentation from the Keil's armcc compiler[^keil-attribute]:

> ```cpp
> static int oldname(int x, int y) {
>      return x + y;
> }
> static int newname(int x, int y) __attribute__((alias("oldname")));
> int caller(int x, int y) {
>      return oldname(x,y) + newname(x,y);
> }
> ```
> 
> This code compiles to:
> 
> ```cpp
> AREA ||.text||, CODE, READONLY, ALIGN=2
> newname                  ; Alternate entry point
> oldname PROC
>      MOV      r2,r0
>      ADD      r0,r2,r1
>      BX       lr
>      ENDP
> caller PROC
>      PUSH     {r4,r5,lr}
>      MOV      r3,r0
>      MOV      r4,r1
>      MOV      r1,r4
>      MOV      r0,r3
>      BL       oldname
>      MOV      r5,r0
>      MOV      r1,r4
>      MOV      r0,r3
>      BL       oldname
>      ADD      r0,r0,r5
>      POP      {r4,r5,pc}
>      ENDP
> ```

There are many compilers which implement exactly this behavior with exactly this GCC-extension syntax such as Oracle's C Compiler, the Intel C Compiler, the Tiny C Compiler, and Clang.[^oracle-attribute] [^intel-attribute]. Clang also features its own `asm`-style attribute, where the function's name is "mangled" without needing to provide an initial [^clang-attribute]. Microsoft Visual C uses a (slightly more complex) stateful pragma mechanisms and external compiler markup[^msvc-attribute].



### Other Existing Practice: `asm(...)` and `#pragma`

There are 2 other proofs of practice in the industry today. One was an MSVC-like `#pragma` behavior/`EXPORT`-file specification. The other was a Clang-like `asm()`-attribute that rename behavior. When evaluated as potential alternatives to the syntaxes chosen here, there were a number of deficiencies for providing backwards compatibility. Notably, there are 2 chief concerns at play:

- the function entity/entities the end-user must interact with from a given library; and,
- valid interpretations of the directive in a non-binary world.

Clang's `asm(...)` and MSVC's `#pragma`-based approach are harder to standardize because each mechanism relies too heavily on the linker and the details of binary artefacts. Whereas the GCC-style attribute is tied to a front-end entity and, therefore, abstracts away binary changes as a means left to the implementation, Clang and MSVC's approaches are not tied to any entity that exists in the program in general. Export `#pragma`s and `asm(...)` attributes can be used to reference any symbol, by unchecked string, that can be resolved at any later stage of compilation (possibly during linking and code generation). There is no good way to standardize such behavior because there are no meaningful semantic constraints that can be placed on their designs that are enforceable within the boundaries of the Abstract Machine.

Contrast this to GCC's attribute. It **requires** that a previous, in-language declaration exists. If that declaration does not exist, the program has a constraint violation:

```cpp
#if 0
extern inline int foo () { return 1; }
#endif

int bar () __attribute__((alias("foo")));
// <source>:5:27: error: alias must point to a defined variable or function
// int bar () __attribute__((alias("foo")));
//                           ^

int main () {
	return bar();
}
```


GCC's design is more suitable for Standard C, since we do not want to specify this in terms of effects on a binary artefact or "symbols". GCC's design makes no imposition on what may or may not happen to the exported symbols, only ties one entity to another in what is typically known as an implementation's "front end". Whether or not final binary artefacts do the right thing is still up to an implementation (and always will be, because the Standard cannot specify such). This gives us proper semantics without undue burden on either specification or implementation.



## Why not an `[[attribute]]`?

At this point in time, one might wonder why we do not propose an attribute or similar for the task here. After all, almost all prior art uses an attribute-like or literal `__attribute__` syntax. Our reasons are 2-fold:


### Standard Attributes may be ignored.

The ability to ignore an attribute and still have a conforming program is disastrous for this feature. It reduces portability of libraries that want to defend against binary breakages. Note that this is, effectively, the situation we are in now: compilers effectively ruin any implementation-defined extension by simply refusing to support that extension or coming up with one of their own. Somewhat ironically, those same vendors will attend C Committee meetings and complain about binary breakages. We then do not change anything related to that feature area, due to the potential of binary breakages.

The cycle continues and will continue ad nauseum until Standard C provides a common-ground solution.


### There is no such thing as "mangled name" or "symbol name" in the Standard.

Any attempt at producing normative text for such a construct is incredibly fraught with peril and danger. Vendors deserve to have implementation freedom with respect to their what their implementation produces (or not). Solving this problem must be done without needing to draft specification for what a "binary artefact" or similar may be and how an attribute or attribute-like construct could affect it. If this feature relies primarily on non-normative encouragement or notes to provide ABI protection, then it is not fit for purpose.

Therefore, we realize that the best way to achieve this is to effectively allow for a transparent aliasing technique for functions, similar to type definitions. It must be in the language and it must be Standard, otherwise we can never upgrade any of our type definitions without waiting for an enormous architectural break (like 32-bit to 64-bit).



## Backwards-Compatibility with "Vanilla" C Standard Libraries

One of the driving goals behind this proposal is the ability to allow "vanilla" C Standard Library Implementations to use Standards-only techniques to provide the functions for their end-user. Let us consider an implementation — named `vanilla`, that maybe produces a `vanilla.so` binary — that, up until today, has been shipping a `extern intmax_t imaxabs(intmax_t value);` function declaration for the last 2 decades. Using this feature, we can provide an _entirely backwards compatible_, binary-preserving upgraded implementation of `vanilla.so` that decides to change it's `imaxabs` function declarations. For example, it can use 2 translation units `inttypes_compatibility.c` and `inttypes.c` and one header, `inttypes.h`, to produce a conforming Standard Library implementation that also provides a backwards-compatible:


**`inttypes.c`**:
```cpp
#include <inttypes.h>

__int128_t __imaxabs_vanilla_v2(__int128_t __value) {
	if (__value < 0)
		return -__value;
	return __value;
}
```

**`inttypes_compatibility.c`**:
```cpp
extern inline long long imaxabs(long long __value) {
	if (__value < 0)
		return -__value;
	return __value;
}
```

**`inttypes.h`**:
```cpp
/* upgraded from long long in v2 */
typedef __int128_t intmax_t;

extern intmax_t __imaxabs_vanilla_v2(intmax_t);

using imaxabs = __imaxabs_vanilla_v2;
```

As long as `inttypes_compatibility.c` is linked with the final binary artefact `vanilla.so`, the presumed mangled symbol `_imaxabs` will always be there. Meanwhile, the "standard" `inttypes.h` will have the normal `imaxabs` symbol that is tied in a transparent way to the "Version 2" of the vanilla implementation, `__imaxabs_vanilla_v2`. This produces a perfectly backwards compatible interface for the previous users of `vanilla.so`. It allows typedefs to be seamlessly upgraded, without breaking already-compiled end user code. Newly compiled code will directly reference the v2 functions with no performance loss or startup switching, getting an upgraded `intmax_t`. Older programs compiled with the old `intmax_t` continue to reference old symbols left by compatibility translation units in the code.

This means that both C Standard Libraries will have a language-capable medium of upgrading their code in a systemic and useful fashion.



## The `using a = b` syntax

We use the word `using` as there was very little option to create a keyword that more appropriately mirrors "`typedef` but for functions". `funcdef` is already a prominent identifier in C codebases, and reusing `typedef` is not a very good idea for something that does not declare a type.

C++ took the keywording `using`, and so far it seems to have made most C and C++ developers stay away from the keyword altogether. Nevertheless, the wording uses a stand-in `USING-TOKEN` here, and we eagerly await for community suggestions. At the moment, the only suggestion we have for the token is:

- `using`




# Wording

The following wording is registered against [N2596](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf).



## Add a new keyword to "§6.4.1 Keywords", Syntax, paragraph 1

<blockquote>

<div class="wording-numbered wording-numbered-1">
_keyword_: one of<br/>
<p>…</p>
<p><ins>USING-TOKEN</ins></p>
</div>
</blockquote>




## Modify "§6.7 Declarations" as follows...


### Syntax, paragraph 1, with a new "declaration" production

<blockquote>
<div class="wording-numbered wording-numbered-1">
<dl>
	<dt>_declaration:_</dt>
	<dd>…</dd>
	<dd><emsp/><ins>_function-alias_ **;**</ins></dd>
</dl>
</div>
</blockquote>


### Constraints, paragraphs 2 and 3

<blockquote>
<div class="wording-numbered wording-numbered-2">
A declaration other than a static_assert or attribute declaration shall declare at least a declarator (other than the parameters of a function or the members of a structure or union), a tag<ins>, a function alias</ins>, or the members of an enumeration.
</div>
<div class="wording-numbered">
If an identifier has no linkage, there shall be no more than one declaration of the identifier (in a declarator or type specifier) with the same scope and in the same name space, except that:

- a typedef name may be redefined to denote the same type as it currently does, provided that type is not a variably modified type;
- <ins>a function alias name may be redeclared as defined in 6.7.12; and</ins>
- tags may be redeclared as specified in 6.7.2.3.

</div>
</blockquote>


### Semantics, paragraph 5

<blockquote>
<div class="wording-numbered wording-numbered-5">
A declaration specifies the interpretation and properties of a set of identifiers. A definition of an identifier is a declaration for that identifier that:

- for an object, causes storage to be reserved for that object;
- for a function, includes the function body;129)
- for an enumeration constant, is the (only) declaration of the identifier;
- for a typedef name, is the first (or only) declaration of the identifier<del>.</del><ins>; or</ins>
- <ins>for a function alias name, is the first (or only) declaration of the identifier.</ins>
</div>
</blockquote>




## Add a new sub-clause "§6.7.12 Function alias"

<blockquote>
<ins>
<h3><ins>6.7.12 Function alias</ins></h3>

<h6>Syntax</h6>
<div class="wording-numbered wording-numbered-1">
<dl>
	<dt>_function-alias:_</dt>
	<dd><emsp/>**USING-TOKEN** _identifier_ **=** _identifier_</dd>
</dl>
</div>
<div class="wording-numbered">
Let the identifier on the left hand side be the <i>function alias name</i> and the identifier on the right hand side be the <i>function alias target</i>.
</div>

<h6>Constraints</h6>
<div class="wording-numbered">
A function alias target must refer to a preceding function alias or a preceding function declaration. A function alias being redeclared shall refer to the same function declaration<sup>1⭐⭐</sup>.
</div>

<h6>Semantics</h6>
<div class="wording-numbered">
A function alias refers to an existing function declaration, either directly or through another function alias. A function alias does not produce a new function declaration; it is only a synonym for the function alias target specified. A function alias name shares the same name space as other identifiers declared in ordinary declarators. If the function alias target is another function alias, it is evaluated to determine the function declaration to which the function alias target is a synonym for.
</div>
<div class="wording-numbered">
A function alias is a function designator (6.3.2.1). If its address is taken with the unary address operator (6.5.3.2), it yields the address of the function declaration to which its function alias target's function declaration refers. If it is called using the postfix operator for function calls (6.5.2.2), it calls the function to which its function alias target's function declaration refers.
</div>
<div class="wording-numbered">
**EXAMPLE 1** The following program contains no constraint violations:

> ```cpp
> void do_work(void);
> void take_nap(void);
> 
> USING-TOKEN work_alias = do_work;
> USING-TOKEN nap_alias = take_nap;
> USING-TOKEN alias_of_work_alias = work_alias;
> USING-TOKEN alias_of_nap_alias = nap_alias;
> 
> int main () {
> 	_Static_assert(&do_work == &work_alias);
> 	_Static_assert(&do_work == &alias_of_work_alias);
> 	_Static_assert(&work_alias == &alias_of_work_alias);
> 
> 	_Static_assert(&take_nap == &nap_alias);
> 	_Static_assert(&take_nap == &alias_of_nap_alias);
> 	_Static_assert(&nap_alias == &alias_of_nap_alias);
> 
> 	_Static_assert(&take_nap != &work_alias);
> 	_Static_assert(&do_work != &alias_of_nap_alias);
> 
> 	USING-TOKEN local_work_alias = alias_of_work_alias;
> 	_Static_assert(&local_work_alias == &alias_of_work_alias);
> 
> 	do_work();
> 	work_alias(); // calls do_work
> 	alias_of_work_alias(); // calls do_work
> 	local_work_alias(); // calls do_work
> 
> 	take_nap();
> 	nap_alias(); // calls take_nap
> 	alias_of_nap_alias(); // calls take_nap
> 
> 	return 0;
> }
> ```

</div>
<div class="wording-numbered">
**EXAMPLE 2** Valid redeclarations:

> ```cpp
> int zzz(int requested_sleep_time);
> 
> USING-TOKEN sleep_alias = zzz;
> USING-TOKEN sleep_alias = sleep_alias;
> USING-TOKEN sleep_alias_alias = zzz;
> USING-TOKEN sleep_alias = sleep_alias_alias;
> ```
</div>

<div class="wording-numbered">
**EXAMPLE 3** Invalid redeclarations:

> ```cpp
> int zzz(int requested_sleep_time);
> int truncated_zzz(int requested_sleep_time);
> 
> USING-TOKEN sleep_alias = sleep_alias; // constraint violation: alias does
>                                  // not exist
> USING-TOKEN zzz = truncated_zzz; // constraint violation: cannot hide
>                            // existing declaration
> USING-TOKEN truncated_zzz = truncated_zzz; // constraint violation: cannot change function declaration
>                                      // to function alias
> 
> USING-TOKEN valid_sleep_alias = zzz;
> int valid_sleep_alias(int requested_sleep_time); // constraint violation: redeclaring
>                                                  // function alias
> ```
</div>

<div class="wording-footnote">
<sup>1⭐⭐)</sup> <sub>If the function alias target points to another function alias, then the alias target is first resolved. The resolution occurs recursively until a function declaration is the alias target. Equality between two alias names determines whether or not they ultimately refer to the same function declaration. Resolution of a function alias target happens before the synonym is declared or redeclared, meaning a function alias name may refer to itself when it is being redeclared, but not when it is first declared.</sub>
</div>

<h6>Recommended Practice</h6>
<div class="wording-numbered">
Implementations and programs may use this feature as a way to produce stability for in translation units which rely on specific function declaration names being present while aliasing a common name to a useful default. It may be particularly helpful for those which use type definitions (6.7.8) in return and parameter types.
</div>

<div class="wording-numbered">
**EXAMPLE 4**

> ```cpp
> extern intmax_t __imaxabs_32ish(__int32 value);
> extern intmax_t __imaxabs_64ish(__int64 value);
> extern intmax_t __imaxabs_128ish(__int128 value);
> 
> typedef __int128_t intmax_t;
> USING-TOKEN imaxabs = __imaxabs_128ish;
> ```

</div>
</ins>
</blockquote>



# Reference

[^N2680]: Seacord, Robert. "Specific-width length modifier". ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2680.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2680.pdf).  
[^N2465]: Seacord, Robert. "intmax t, a way forward." ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2465.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2465.pdf)  
[^N2425]: Gustedt, Jens. "intmax_t, a way out v.2". ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf)  
[^N2498]: Uecker, Martin. "intmax_t, again". ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf)  
[^N2525]: Krause, Philipp Klaus. "Remove the `fromfp`, `ufromfp`, `fromfpx`, `ufromfpx`, and other intmax_t functions". ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2525.htm](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2525.htm)
[^gcc-attribute]: GNU Compiler Collection. "Function attributes: alias". GNU Compiler Collection Maintainers, Free Software Foundation. [https://clang.llvm.org/docs/AttributeReference.html#asm](https://clang.llvm.org/docs/AttributeReference.html#asm)
[^clang-attribute]: Clang. "Attributes: `asm`". LLVM Foundation. [https://clang.llvm.org/docs/AttributeReference.html#asm](https://clang.llvm.org/docs/AttributeReference.html#asm)
[^keil-attribute]: armcc Compiler. "`__attribute__((alias))` function attribute". Keil. [https://www.keil.com/support/man/docs/armcc/armcc_chr1359124973698.htm](https://www.keil.com/support/man/docs/armcc/armcc_chr1359124973698.htm)
[^msvc-attribute]: Microsoft Visual C++. "EXPORTS \| Microsoft Docs". Microsoft. [https://docs.microsoft.com/en-us/cpp/build/reference/exports](https://docs.microsoft.com/en-us/cpp/build/reference/exports)
[^oracle-attribute]: Oracle Solaris Studio. "2.9 Supported Attributes". Oracle. [https://docs.oracle.com/cd/E24457_01/html/E21990/gjzke.html#scrolltoc](https://docs.oracle.com/cd/E24457_01/html/E21990/gjzke.html#scrolltoc)
[^intel-attribute]: Intel Compiler Collection. "Documentation: attribute". Intel. [https://software.intel.com/content/www/us/en/develop/articles/download-documentation-intel-compiler-current-and-previous.html](https://software.intel.com/content/www/us/en/develop/articles/download-documentation-intel-compiler-current-and-previous.html)