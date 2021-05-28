---
title: Consistent, Warningless, and Intuitive Initialization with {} | r0
date: May 15th, 2021
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis) \<<shepherd@gmail.com>\>
layout: paper
hide: true
---

_**Document**_: n2727  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: Change Request, Feature Request  
_**Target Audience**_: General Developers, Library Developers  
_**Latest Revision**_: [https://thephd.dev/_vendor/future_cxx/papers/C%20-%20Consistent,%20Warningless,%20and%20Intuitive%20Initialization%20with%20%7B%7D.html](https://thephd.dev/_vendor/future_cxx/papers/C%20-%20Consistent,%20Warningless,%20and%20Intuitive%20Initialization%20with%20%7B%7D.html)

<div class="text-center">
<h6>Abstract:</h6>
<p>
This proposal fills out the grammar term in C for an empty brace list `{}`, allowing initialization of all the same types in both regular initializers and designated initializers while retaining compatibility with C++ code.
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 0

- Initial release! 🎉




# Introduction & Motivation

The use of "`= { 0 }`" to initialize structures, unions, and arrays is a long-standing pillar of C. But, for a long time it has caused some confusion amongst developers. Whether it was initializing arrays of integers and using "`= { 1 }`" and thinking it would initialize all integers with the value `1` (and being wrong), or getting warnings on some implementations for complicated structures and designated initializers that did not initialize every element, the usage of "`{ 0 }`" has caused quite a bit of confusion.

Furthermore, this has created great confusion about how initializers are supposed to work. Is the `0` the special element that initializes everything to be `0`? Or is it the braces with the `0`? What about nested structures? How come "`struct my_struct_with_nested_struct ms = { 0 };`" is okay, but "`struct my_struct_with_nested_struct ms2 = { 0, 0 };`" start producing warnings about not initializing elements correctly? This confusion leads to people having very poor ideas about how exactly they need to zero-initialize a structure and results in folks either turning off sometimes helpful warnings[^zcash-warning-disable] or other issues. It also leads people to do things like fallback to using `memset(&ms, 0, sizeof(ms))` or similar patterns rather than just guaranteeing a clear initialization pattern for all structures.

This is also a longstanding compatibility risk with C++, where shared header code that relies on "`= {}`", thinking it is viable C code, find out that its not allowed. This is the case with GCC, where developers as prominent as the chief security maintainer for musl-libc [recently as April 6th, 2021](https://twitter.com/ariadneconill/status/1379579444365496321) say things like:

> today i learned.  gcc allows this, i’ve used it for years!

Indeed, the use is so ubiquitous that most compilers allow it as an extension and do so quietly until warning level and pedantic checkers are turned on for most compilers and static analyzers! Thankfully for this proposal, every compiler deploying this extension applies the same initialization behavior; perform the identical behavior of static initialization for every active sub-object/element of the scalar/`struct`/`union`.




# Design

As hinted at in the last paragraph of the motivation, there is no special design to be engaging in here. Accepting `= {}` is not only a part of C++, but is existing extension practice in almost every single C compiler that has a shared C/C++ mode, and many other solely-C compilers as an extension (due to its prolific use in many projects). Providing `{}` as an initializer has the unique benefit of being unambiguous. For example, consider the following nested structures:

```cpp
struct core {
	int a;
	double b;
};

struct inner {
	struct core c;
};

struct outer {
	struct inner d;
	int e;
};
```

With this proposal, this code...

```cpp
int main () {
	struct outer0 o0 = { 0 };
	struct outer1 o1 = { 0, 1 }; // warnings about brace elision confusion, but compiles
	// ^ "did I 0-initialize inner, and then give "e" the 1 value?"
	return 0;
}
```

can instead be written like this code:

```cpp
int main () {
	struct outer0 o0 = { }; // completely empty
	struct outer1 o1 = { { }, 1 };
	// ^ much less ambiguous about what "1" is meant to fill in here
	// without "do I need the '0'?" ambiguity
	return 0;
}
```



## Static Initialization

Every single compiler which was surveyed, that implements this extension, agrees that "`= { }`" should be the same as "`= { 0 }`", just without the confusing `0` value within the braces. It performs what the C standard calls _static initialization_. Therefore, the wording (and, with minor parsing updates, implementation) burden is minimal since we are not introducing a new class of initialization to the language, just extending an already-in-use syntax.




# Wording

The following wording is relative to N2596[^N2596].



## Modify §6.7.9 paragraph 1's grammar.

<p>
<dl>
	<dt>_initializer:_</dt>
	<dd><ins>**{** **}**</ins></dd>
	<dd>**{** _initializer-list_ **}**</dd>
</dl>
</p>



## Modify §6.7.9 paragraph 11.

<p><del>The initializer for a scalar shall be a single expression, optionally enclosed in braces.</del><ins>The initializer for a scalar shall be a single expression, optionally enclosed in braces, or it shall be an empty brace pair. If the initializer is the empty brace pair, then the scalar is initialized the same as a scalar that has static storage duration. Otherwise,</ins><del>The</del>the initial value of the object is that of the expression (after conversion); …</p>



## Modify §6.7.9 paragraph 22.

<p>If an array of unknown size is initialized, its size is determined by the largest indexed element with an explicit initializer. <ins>An array of unknown size shall not be initialized by an empty brace pair.</ins> The array type is completed at the end of its initializer list.</p>



## Modify §6.9.2 paragraph 2.

<p>… If a translation unit contains one or more tentative definitions for an identifier, and the translation unit contains no external definition for that identifier, then the behavior is exactly as if the translation unit contains a file scope declaration of that identifier, with the composite type as of the end of the translation unit, with an initializer equal to <code>{ 0 }</code><ins> or <code>{ }</code></ins>.</p>




# Acknowledgements

Thank you to the C community for the push to write this paper!



# References

[^zcash-warning-disable]: yaahc, zcash Foundation. _Disable Missing Initializer Warnings_. GitHub. URL: [https://github.com/ZcashFoundation/zcash_script/pull/17/commits/d8e6e1815bac91eef8134d1b79223c15241cd4ec#diff-d0d98998092552a1d3259338c2c71e118a5b8343dd4703c0c7f552ada7f9cb42R84](https://github.com/ZcashFoundation/zcash_script/pull/17/commits/d8e6e1815bac91eef8134d1b79223c15241cd4ec#diff-d0d98998092552a1d3259338c2c71e118a5b8343dd4703c0c7f552ada7f9cb42R84)
[^N2596]: ISO/IEC JTC1 SC22 WG14 - Programming Languages, C. _N2596. C Standard Working Draft_. Open Standard. URL: [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf)
