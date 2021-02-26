---
title: Not-So-Magic - typeof(...) in C | r1
date: December 4th, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis) \<<shepherd@soasis.org>\>
layout: paper
redirect_from:
  - /_vendor/future_cxx/papers/source/n2593.html
  - /_vendor/future_cxx/papers/source/n2619.html
hide: true
---

_**Document**_: n2619  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Compiler/Tooling Developers  
_**Latest Revision**_: [https://thephd.github.io/_vendor/future_cxx/papers/source/C%20-%20typeof.html](https://thephd.github.io/_vendor/future_cxx/papers/source/C%20-%20typeof.html)

<div class="text-center">
<h6>Abstract:</h6>
<p>
Getting the type of an expression in Standard C code.
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 2 - January 23rd, 2021

- Focus on `remove_quals` spelling.
- Fix up some of the section talking about macro-generic facilities for later.



## Revision 1 - December 5th, 2020

- Completely Reformulate Paper based on community, GCC, and LLVM implementation feedback.
- Address major implementation contention of qualifiers with both `_Typeof` (or appropriate flavor) and `_Remove_quals`.
- Note that variably modified types are their own special nightmare.
- Add section about not using C++'s `decltype` identifier for this and other compatibility issues.
- Completely rewrite the wording section.



## Revision 0 - October 25th, 2020

- Initial release.




# Introduction & Motivation

`typeof` is a extension featured in many implementations of the C standard to get the type of an expression. It works similarly to `sizeof`, which runs the expression in an "unevaluated context" to understand the final type, and thusly produce a size. `typeof` stops before producing a byte size and instead just yields a type name, usable in all the places a type currently is in the C grammar.

There are many uses for `typeof` that have come up over the intervening decades since its first introduction in a few compilers, most notably GCC. It can, for example, help produce a type-safe generic printing function that even has room for user extension (see [example implementation](https://slbkbs.org/tmp/fmt/fmt.h)). It can also help write code that can use the expansion of a macro expression as the return type for a function, or used within a macro itself to correctly cast to the desired result of a specific computation's type (for width and precision purposes). The use cases are vast and endless, and many people have been locking themselves into implementation-specific vendorship. This keeps their code out of other compilers (for example, Microsoft's Visual C Compiler) and weakens the ISO C ecosystem overall.




# Implementation & Existing Practice

Every implementation in existence since C89 has an implementation of `typeof`. Some compilers (GCC, Clang, EDG, tcc, and many, many more) expose this with the implementation extension `typeof`. But, the Standard already requires `typeof` to exist. Notably, with emphasis (not found in the standard) added:

> The `sizeof` operator yields the size (in bytes) of its operand, which may be an expression or the parenthesized name of a type. **The size is determined from the type of the operand.**
> — [N2596, Programming Languages C - Working Draft, §6.5.3.4 The `sizeof` and `_Alignof` operators, Semantics](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf)

Any implementation that can process `sizeof("foo")` is already doing `sizeof(typeof("foo"))` internally. This feature is the most "existing practice"-iest feature to be proposed to the C Standard, possibly in the entire history of the C standard. The feature was also mentioned in an "extension round up" paper that went over the state of C Extensions in 2007[^N1229]. `typeof` was also considered an important extension during the discussion of that paper, but nobody brought forth the paper previously to make it a reality[^N1267].



## Corner cases: Variably-Modified Types and VLAs

[Putting a normal or VLA-type computation results in an idempotent](https://godbolt.org/z/3hqr6x) type computation that simply yields that type in most implementations that support the feature. If the compiler supports Variable Length Arrays, then `__typeof` -- if it is similar to GCC, Clang, tcc, and others -- then it is already supported with these semantics. These semantics also match how `sizeof` would behave (computing the expression or having an internal placeholder "VLA" type), so we propagate that same ability in an identical manner.

Notably, this is how current implementations evaluate the semantics as well. Note that the standard claims that whether or not any computation done for Variably Modified Types -- with side effects -- is actually unspecified behavior, so there's no additional guarantees about the evaluation for such types.



## Why not "decltype"?

C++ has a feature it calls `decltype(...)`, which serves most of the same purpose. "Most" is because it has a subtle difference which would wreak havoc on C code if it was employed in shared header code:


```cpp
int value = 20;

#define GET_TARGET_VALUE (value)

inline decltype(GET_TARGET_VALUE) g () {
	return value;
}

int main () {
	int& r = g();
	return r;
}
```

The return type of `g` would be `int&` in C++, and `int` in C. Other expressions, such as array indexing and pointer dereferencing, also have this same issue. This is due to the parentheses in the expression. Macros in both languages frequently see extra parentheses employed around expressions to prevent mixing of precedence or other shenanigans from token-based macro expansion and subsequent language parsing; this would be a footgun of large proportions for C and C++ users, and create a divergence in standard use that would rise to the level of a liaison issue that may become unfixable. This is also part of the reason why `decltype` was given that keyword in C++, and not `typeof`: they did not want this kind of subtle and brutal change to afflict C and C++ code. `typeof` does not have this problem because -- if a Sister Paper ever proposes it for C++ -- it will have identical behavior to `std::remove_reference_t<decltype(T)>`.

This was also addressed when C++ was itself trying to introduce `dectlype` and competing with `typeof` in WG21 for C++[^N1607].



## C++ Compatibility

A similar feature should be proposed in C++, albeit it will likely take the keyword name `typeof` rather than `_Typeof`. This paper intends to have a similar paper brought before the C++ Committee -- WG21 -- through its Liaison Study Group, if this paper is successful.



## Qualifiers

There is some discussion about what happens with qualifiers, both standard and implementation-defined. For example, ["Named Address Space" qualifiers](https://gcc.gnu.org/onlinedocs/gcc-7.1.0/gcc/Named-Address-Spaces.html) are subject to issues with GCC"s `typeof` extension, as shown [here](https://gcc.gnu.org/pipermail/gcc/2020-November/234119.html)[^named-address-space-bug]. The intention of one of the GCC maintainers from that thread is:

> Well, I think we should fix typeof to not retain the address space. It's
> probably our implementation detail of having those in TYPE_QUALS
> that exposes the issue... — [Richard Biener, GCC Maintainer, November 5th, 2020](https://gcc.gnu.org/pipermail/gcc/2020-November/234125.html)

There is also some disagreement between implementations about what qualifiers are worth keeping with respect to `_Atomic` between implementations. Therefore, `typeof` as proposed does not *strips all qualifiers from the computed type result*. The reason for this is that a user can add specifiers and qualifications to a type, but can not take them away once they are part of the expression. For example, consider the specification of `<complex.h>` that contains macro-provided constants like `_Imaginary_I`. These constants have the type `const float _Imaginary`: should all `typeof(_Imaginary_I)` expressions therefore result in a `const float _Imaginary`, or a `float _Imaginary`? What about `volatile`? And so on, and so forth.

There is an argument to strip all type qualifiers (`_Atomic`, `const`, `restrict`, and `volatile`) from the final type expression is because they can be added back by the programmer easily. However, the opposite is not true: you cannot add back qualifiers or create macros where those qualifiers can be taken in as parameters and re-applied to the function. This does leave some room to be desired: some folk may want to deliberately propagate the `const`-ness, `volatile`-ness, or `_Atomic`-ness of an expression to its end users.


### Qualifiers - The Solution

Originally, the idea of a `_Typeof` and an `_Unqual_typeof` was explored. This was a tempting direction but ultimately unsuitable as it duplicated functionality with a slight caveat and did not have a targeted purpose. A much better set name for the functionality is `_Typeof` and `remove_quals`. `_Typeof` is an all-qualifier-preserving type reproduction of the expression (or pass-through if a type is given) . It suitably envelopes the total space of existing practice. The only reason `_Unqual_typeof` would exist is to... well, remove qualifiers. It only makes sense to just name it appropriately by using `remove_quals` as a keyword. The benefits of choosing this name are also clear:

- there are no search hits for `remove_quals` in searching the ACT database (catalogue of Debian/Fedora/etc. open source packages and their code) (December 5th, 2020); and,
- there are no search hits for `remove_quals` in the entirety of GitHub save for 4 instances of Python Code (December 5th, 2020).

This means that we need not entertain the idea of needing a header or some other choice and can simply directly name `remove_quals` as a keyword in the code instead, saving ourselves a massive debate about what should and should not be a keyword.


### In General

Separately, we should consider a Macro Programming facility for C that can address larger questions. This paper strives to focus on the material gains from existing practice and the pitfalls of said existing practice. Therefore, this paper proposes only `_Typeof` (of some flavor) and `remove_quals`.

After this paper is handled, further research should be given to handling qualifiers, function types, and arrays in Macros for generic programming. This paper focuses only on what we can find existing practice for.




# Proposed Changes

There is a choice that affects the wording here, to be voted on during the Virtual March WG14 - Programming Languages C meeting, contained below:



## Keyword Name Ideas

There are 3 options for names. We have wording for the options using find-and-replace on the `TYPEOF_KEYWORD_TOKEN` as well as the `REMOVE_QUALIFIERS_KEYWORD_TOKEN`. The option that provides the most consensus will be what is chosen:


### Option 1: `_Typeof` keyword, `<stdtypeof.h>` header

- `_Typeof` for the type of keyword
- `remove_quals` for the remove qualifications keyword

This is the relatively conservative option that uses a `_Typeof` keyword plus `<stdtypeof.h>` to get access to the convenient spelling. It prevents implementations that have already settled on the `typeof()` keyword in their extension modes from having to warn users or breakage or deal with that problem. Many have raised issues with this, annoyed at the constant spelling of keywords in fundamentally awkward and strange ways while requiring headers to fix up usage. This is consistent with other new keywords introduced in the Standard to avoid breakage at all costs, but suffers from strong lamentations in needing a header to access a common spelling.

This is the authors' status quo and compromise position.


### Option 2: `typeof` keyword

- `typeof` for the type of keyword
- `remove_quals` for the remove qualifications keyword

This is the relatively aggressive (but still milquetoast, overall) option. It takes over the extension that is used in non-conforming C modes in a few compilers, such as XL C and GCC. Maintainers/implementers from GCC and Clang have noted their approval for this option, but e.g. XL C maintainers and implementers are less enthused.

The reason some folks are against this change is because there are "bugs" in the implementation where some qualifiers are preserved, but other implementation-defined qualifiers are not. Most implementations agree that things like `_Atomic` and `volatile` should be preserved (and the compiler that did not implement it this way acknowledged that it was, more or less, a mistake). There are also qualifiers that are dropped on some implementations for their vendor-specific extensions. An argument can be made that implementations can continue to do whatever they want with implementation-defined qualifiers as far as `typeof` is concerned, as long as they preserve the standard qualifiers.

This option is the authors' overwhelmingly strong preference.


### Option 3: Use a completely new keyword spelling

This uses a completely novel name to avoid the problem altogether. These names take no interesting space from users or implementers and it is the safest option, though it risks obscurity in what is a commonly anticipated feature. Names for this include:

- `qual_typeof`
  `remove_quals`
- `qualified_typeof`
  `remove_qualifiers`
- `typeof_qual`
  `remove_quals`
- `typeof_qualified`
  `remove_qualifiers`

Choosing this options means picking one of these novel keywords and substituting it for the `TYPEOF_KEYWORD_TOKEN` spelling in the wording below.

This is the authors' least favorite option.



## Proposed Wording

The following wording is relative to [N2596](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf).


### Modify §6.3.2.1 Lvalues, arrays, and function designators, paragraphs 3 and 4 with footnote 68:

<blockquote>
<div class="wording-numbered wording-numbered-3">
<p>Except when it is the operand of the <del><code class="c-kw">sizeof</code> operator</del><ins><code class="c-kw">sizeof</code>, or typeof operators</ins>, or the unary <code>&</code> operator, or is a string literal used to initialize an array, an expression that has type "array of <i>type</i>" is converted to an expression with type "pointer to <i>type</i>" that points to the initial element of the array object and is not an lvalue. If the array object has register storage class, the behavior is undefined.</p>
</div>
<div class="wording-numbered wording-numbered-4">
<p>A <i>function designator</i> is an expression that has function type. Except when it is the operand of the <del><code class="c-kw">sizeof</code> operator</del><ins><code class="c-kw">sizeof</code> operator, a typeof operator</ins><sup>69)</sup>or the unary <code>&</code> operator, a function designator with type "function returning <i>type</i>" is converted to an expression that has type "pointer to function returning <i>type</i>".</p>
</div>

<div><sub><sup>69)</sup>Because this conversion does not occur, the operand of the <code class="c-kw">sizeof</code> operator remains a function designator and violates the constraints in 6.5.3.4.</sub>
</div>
</blockquote>



**Add a keyword to the §6.4.1 Keywords:**

<blockquote>
<p>
&emsp; &emsp; <code class="c-kw">_Thread_local</code><br/>
<ins>&emsp; &emsp; <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code></ins><br/>
<ins>&emsp; &emsp; <code class="c-kw">REMOVE_QUALIFIERS_KEYWORD_TOKEN</code></ins><br/>
</p>
</blockquote>



### Modify §6.6 Constant expressions, paragraphs 6 and 8:

<blockquote>
<div class="wording-numbered wording-numbered-6">
<p>An integer constant expression<sup>125)</sup> shall have integer type and shall only have operands that are integer constants, enumeration constants, character constants, <code class="c-kw">sizeof</code> expressions whose results are integer constants, <code class="c-kw">_Alignof</code> expressions, and floating constants that are the immediate operands of casts. Cast operators in an integer constant expression shall only convert arithmetic types to integer types, except as part of an operand to the <del><code class="c-kw">sizeof</code></del><ins>typeof operators, <code class="c-kw">sizeof</code> operator,</ins> or <code class="c-kw">_Alignof</code> operator.</p>
</div>

<p>...</p>

<div class="wording-numbered wording-numbered-8">
<p>An arithmetic constant expression shall have arithmetic type and shall only have operands that are integer constants, floating constants, enumeration constants, character constants,<code class="c-kw">sizeof</code> expressions whose results are integer constants, and <code class="c-kw">_Alignof</code> expressions. Cast operators in an arithmetic constant expression shall only convert arithmetic types to arithmetic types, except as part of an operand to the <del><code class="c-kw">sizeof</code></del><ins>typeof operators, <code class="c-kw">sizeof</code> operator,</ins> or <code class="c-kw">_Alignof</code> operator.
</p></div>
</blockquote>



### Adjust the Syntax grammar of §6.7.2 Type specifiers, the paragraph 2 list, and paragraph 4 Semantics:

<blockquote>
<p>
<i>type-specifier</i>:<br/>
&emsp; &emsp; <code class="c-kw">void</code><br/>
&emsp; &emsp; ...<br/>
&emsp; &emsp; <i>typedef-name</i><br/>
<ins>&emsp; &emsp; <i>typeof-specifier</i></ins>
</p>
</blockquote>

...

<blockquote>
<p>
<ul>
	<li class="c">enum specifier</li>
	<li class="c">typedef name</li>
	<ins><li class="c">typeof specifier</li></ins>
</ul>
</p>
</blockquote>

<blockquote>
<div class="wording-numbered wording-numbered-4">
<p>Specifiers for <del>structures, unions, enumerations, and atomic types</del><ins>structures, unions, enumerations, atomic types, and typeof specifiers</ins> are discussed in 6.7.2.1 through <del>6.7.2.4</del><ins>6.7.2.5</ins>. Declarations of typedef names are discussed in 6.7.8. The characteristics of the other types are discussed in 6.2.5.</p>
</div>
</blockquote>



### Adjust the footnote 133) in §6.7.2.1 Structure and union specifiers:

<blockquote>
<p>
<sup>133)</sup><sub>As specified in 6.7.2 above, if the actual type specifier used is <code class="c-kw">int</code> or a typedef-name defined as <code class="c-kw">int</code>, then it is implementation-defined whether the bit-field is signed or unsigned. <ins>This includes an <code class="c-kw">int</code> type specifier produced by the use of the typeof specifier (6.7.2.5).</ins></sub>
</p>
</blockquote>



### Add a new §6.7.2.5 The Typeof specifiers:

<blockquote>
<ins>
<p><h3><b>§6.7.2.5 &emsp; &emsp; The Typeof specifiers</b></h3></p>

<p><h4><b>Syntax</b></h4></p>

<div class="wording-numbered">
<p>
<i>typeof-specifier</i>:<br/>
&emsp; &emsp; <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code> <b>(</b> <i>expression</i> <b>)</b><br/>
&emsp; &emsp; <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code> <b>(</b> <i>type-name</i> <b>)</b><br/>
&emsp; &emsp; <code class="c-kw">REMOVE_QUALIFIERS_KEYWORD_TOKEN</code> <b>(</b> <i>expression</i> <b>)</b><br/>
&emsp; &emsp; <code class="c-kw">REMOVE_QUALIFIERS_KEYWORD_TOKEN</code> <b>(</b> <i>type-name</i> <b>)</b>
</p>
</div>

<div class="wording-numbered">
<p>The <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code> and <code class="c-kw">REMOVE_QUALIFIERS_KEYWORD_TOKEN</code> operators are collectively called the <i>typeof operators</i>.</p>
</div>

<p><h4><b>Constraints</b></h4></p>

<div class="wording-numbered">
<p>The <i>typeof operators</i> shall not be applied to an expression that designates a bit-field member.</p>
</div>

<p><h4><b>Semantics</b></h4></p>

<div class="wording-numbered">
<p>The <i>typeof-specifier</i> applies the typeof operators to an <i>expression</i> (6.5) or a <i>type-name</i>. If the typeof operators are applied to an <i>expression</i>, they yield the <i>type-name</i> representing the type of their operand<sup>11�0)</sup>. Otherwise, they produce the <i>type-name</i> with any nested <i>typeof-specifier</i> evaluated <sup>11�1)</sup>. If the type of the operand is a variably modified type, the operand is evaluated; otherwise, the operand is not evaluated.</p>
</div>

<div class="wording-numbered">
<p>All qualifiers (6.7.3) on the type from the result of a <code class="c-kw">REMOVE_QUALIFIERS_KEYWORD_TOKEN</code> operation are removed, including <code class="c-kw">_Atomic</code>. Otherwise, for <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code> operations, all qualifiers are preserved.</p>
</div>

<p><sup>11�0)</sup><sub> When applied to a parameter declared to have array or function type, the <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code> operator yields the adjusted (pointer) type (see 6.9.1).</sub></p>
<p><sup>11�1)</sup><sub> If the operand is a typeof operator, the operand will be evaluated before evaluating the current typeof operation. This happens recursively until a <i>typeof-specifier</i> is no longer the operand.</sub></p>
</ins>
</blockquote>


### Add the following examples to new §6.7.2.5 The Typeof specifier:

> <ins><sup>5</sup> **EXAMPLE 1** Type of an expression.<br/></ins>
> 
> <ins>The following program:</ins>
> 
> > ```c
> > TYPEOF_KEYWORD_TOKEN(1+1) main () {
> > 	return 0;
> > }
> > ```
> 
> <ins>is equivalent to this program:</ins>
> 
> > ```c
> > int main() {
> > 	return 0;
> > }
> > ```
> 
> <ins><sup>6</sup> **EXAMPLE 2** Types and qualifiers.<br/></ins>
> 
> <ins>The following program:</ins>
> 
> > ```c
> > const _Atomic int purr = 0;
> > const int meow = 1;
> > const char* const mew[] = {
> > 	"aardvark",
> > 	"bluejay",
> > 	"catte",
> > };
> > 
> > TYPEOF_KEYWORD_TOKEN(purr) main (int argc, char* argv[]) {
> > 	REMOVE_QUALIFIERS_KEYWORD_TOKEN(purr)                    lain_purr;
> > 	TYPEOF_KEYWORD_TOKEN(_Atomic TYPEOF_KEYWORD_TOKEN(meow)) atomic_meow;
> > 	TYPEOF_KEYWORD_TOKEN(mew)                                mew_array;
> > 	REMOVE_QUALIFIERS_KEYWORD_TOKEN(mew)                     mew2_array;
> > 	return 0;
> > }
> > ```
> 
> <ins>is equivalent to this program:</ins>
> 
> > ```c
> > const _Atomic int purr = 0;
> > const int meow = 1;
> > const char* const mew[] = {
> > 	"aardvark",
> > 	"bluejay",
> > 	"catte",
> > };
> > 
> > int main (int argc, char* argv[]) {
> > 	int               plain_purr;
> > 	const _Atomic int atomic_meow;
> > 	const char* const mew_array[3];
> > 	const char*       mew2_array[3];
> > 	return 0;
> > }
> > ```
> 
> 
> <ins><sup>7</sup> **EXAMPLE 3** Equivalence of `sizeof` and `typeof`.</ins>
> 
> > ```c
> > int main (int argc, char* argv[]) {
> > 	// this program has no constraint violations
> > 
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN('p')) == sizeof(int));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN('p')) == sizeof('p'));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN((char)'p')) == sizeof(char));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN((char)'p')) == sizeof((char)'p'));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN("meow")) == sizeof(char[5]));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN("meow")) == sizeof("meow"));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN(argc)) == sizeof(int));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN(argc)) == sizeof(argc));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN(argv)) == sizeof(char**));
> > 	_Static_assert(sizeof(TYPEOF_KEYWORD_TOKEN(argv)) == sizeof(argv));
> > 
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN('p')) == sizeof(int));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN('p')) == sizeof('p'));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN((char)'p')) == sizeof(char));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN((char)'p')) == sizeof((char)'p'));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN("meow")) == sizeof(char[5]));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN("meow")) == sizeof("meow"));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN(argc)) == sizeof(int));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN(argc)) == sizeof(argc));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN(argv)) == sizeof(char**));
> > 	_Static_assert(sizeof(REMOVE_QUALIFIERS_KEYWORD_TOKEN(argv)) == sizeof(argv));
> > 	return 0;
> > }
> > ```
> 
> <ins><sup>8</sup> **EXAMPLE 4** Nested `TYPEOF_KEYWORD_TOKEN(...)`.<br/></ins>
> 
> <ins>The following program:</ins>
> 
> > ```c
> > int main (int argc, char*[]) {
> > 	float val = 6.0f;
> > 	return (TYPEOF_KEYWORD_TOKEN(REMOVE_QUALIFIERS_KEYWORD_TOKEN(TYPEOF_KEYWORD_TOKEN(argc))))val;
> > }
> > ```
> 
> <ins>is equivalent to this program:</ins>
> 
> 
> > ```c
> > int main (int argc, char*[]) {
> > 	float val = 6.0f;
> > 	return (int)val;
> > }
> > ```
> 
> <ins><sup>9</sup> **EXAMPLE 5** Variable Length Arrays and typeof operators.</ins>
> 
> > ```c
> > #include <stddef.h>
> > 
> > size_t vla_size (int n) {
> > 	typedef char vla_type[n + 3];
> > 	vla_type b; // variable length array
> > 	return sizeof(
> > 		REMOVE_QUALIFIERS_KEYWORD_TOKEN(b)
> > 	); // execution-time sizeof, translation-time typeof operation
> > }
> > 
> > int main () {
> > 	return (int)vla_size(10); // vla_size returns 13
> > }
> > ```
> 
> <ins><sup>10</sup> **EXAMPLE 6** Nested typeof operators, arrays, and pointers.</ins>
> 
> > ```c
> > int main () {
> > 	TYPEOF_KEYWORD_TOKEN(TYPEOF_KEYWORD_TOKEN(const char*)[4]) y = {
> > 		"a",
> > 		"b",
> > 		"c",
> > 		"d"
> > 	}; // 4-element array of "const pointer to char"
> > 	return 0;
> > }
> > ```
> 
> <ins><sup>11</sup> **EXAMPLE 7** Function types, pointer types, and array types.</ins>
> 
> > ```c
> > void f(int);
> > 
> > typeof(f(5)) g(double x) {          // g has type "void(double)"
> > 	 	printf("value %g\n", x);
> > }
> > 
> > typeof(g)* h;                      // h has type "void(*)(double)"
> > typeof(true ? g : NULL) k;         // k has type "void(*)(double)"
> > 
> > void j(double A[5], typeof(A)* B); // j has type "void(double*, double**)"
> > 
> > extern typeof(double[]) D;         // D has an incomplete type
> > typeof(D) C = { 0.7, 99 };         // C has type "double[2]"
> > 
> > typeof(D) D = { 5, 8.9, 0.1, 99 }; // D is now completed to "double[4]"
> > typeof(D) E;                       // E has type "double[4]" from D's completed type
> > ```




### Modify §6.7.3 Type specifiers, paragraph 6:

<blockquote>
<div class="wording-numbered wording-numbered-6">
If the same qualifier appears more than once in the same specifier-qualifier list or as declaration specifiers, either directly<ins>, via one or more typeof specifiers,</ins> or via one or more <code class="c-kw">typedef</code>s, the behavior is the same as if it appeared only once. If other qualifiers appear along with the <code class="c-kw">_Atomic</code> qualifier the resulting type is the so-qualified atomic type.
</div>
</blockquote>


### Modify §6.7.6.2 Array declarators, paragraph 5:

<blockquote>
<div class="wording-numbered wording-numbered-5">
<p>If the size is an expression that is not an integer constant expression: if it occurs in a declaration at function prototype scope, it is treated as if it were replaced by <code>*</code>; otherwise, each time it is evaluated it shall have a value greater than zero. The size of each instance of a variable length array type does not change during its lifetime. Where a size expression is part of the operand of a <ins>typeof or</ins> <code class="c-kw">sizeof</code> operator and changing the value of the size expression would not affect the result of the operator, it is unspecified whether or not the size expression is evaluated. Where a size expression is part of the operand of an <code class="c-kw">_Alignof</code> operator, that expression is not evaluated.</p>
</div>
</blockquote>


### Modify §6.9 External definitions, paragraphs 3 and 5:

<blockquote>
<div class="wording-numbered wording-numbered-3">
<p>There shall be no more than one external definition for each identifier declared with internal linkage in a translation unit. Moreover, if an identifier declared with internal linkage is used in an expression <del>(other than as a part of the operand of a <code class="c-kw">sizeof</code> or <code class="c-kw">_Alignof</code> operator whose result is an integer constant), </del>there shall be exactly one external definition for the identifier in the translation unit<del>.</del><ins>, unless it is:</ins></p>
<ins>
<ul>
	<li class="c-list">part of the operand of a <code class="c-kw">sizeof</code> operator whose result is an integer constant,</li>
	<li class="c-list">part of the operand of a <code class="c-kw">_Alignof</code> operator whose result is an integer constant,</li>
	<li class="c-list">or, part of the operand of any typeof operator whose result is not a variably modified type.</li>
</ul>
</ins>
</div>

<p>...</p>

<div class="wording-numbered wording-numbered-5">
<p>An <i>external definition</i> is an external declaration that is also a definition of a function (other than an inline definition) or an object. If an identifier declared with external linkage is used in an expression (other than as a part of the operand of a <del><code class="c-kw">sizeof</code>,</del><ins>typeof operator whose result is not a variably modified type, or a <code class="c-kw">sizeof</code></ins> or <code class="c-kw">_Alignof</code> operator whose result is an integer constant), somewhere in the entire program there shall be exactly one external definition for the identifier; otherwise, there shall be no more than one.<sup>173)</sup></p>
</div>
</blockquote>


### Add a new §7.� Typeof `<stdtypeof.h>` (**IF AND ONLY IF: Option 1 is not chosen**):

<blockquote>
<ins>
<div class="wording-numbered">
<p>The header <code>&lt;stdtypeof.h&gt;</code> defines two macros.</p>
</div>

<div class="wording-numbered">
<p>The macro</p>
<p>
<blockquote>
<code>typeof</code><br/>
</blockquote>
</p>
<p>expands to <code class="c-kw">TYPEOF_KEYWORD_TOKEN</code>.</p>
</div>

<div class="wording-numbered">
<p>The macro</p>
<p>
<blockquote>
<code>STDC_TYPEOF_IS_DEFINED</code><br/>
</blockquote>
</p>
<p>is suitable for use in <code class="c-kw">#if</code> preprocessing directives. It expands to the integer constant <code>1</code>.</p>
</div>
</ins>
</blockquote>

[^N1607]: Jaakko Järvi and Bjarne Stroustrup. Decltype and auto (revision 3). ISO/IEC JTC1 SC22 WG21 - Programming Languages C++. [http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2004/n1607.pdf](http://www.open-std.org/jtc1/sc22/wg21/docs/papers/2004/n1607.pdf)

[^N1229]: Nick Stoughton. Potential Extensions For Inclusion In a Revision of ISO/IEC 9899. ISO/IEC SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1229.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1229.pdf)

[^N1267]: ISO/IEC JTC1 SC22 WG14. Meeting Minutes April 2007. ISO/IEC SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1267.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n1267.pdf)

[^named-address-space-bug]: Uros Bizjak. typeof and operands in named address spaces. GNU Compiler Collection. [https://gcc.gnu.org/pipermail/gcc/2020-November/234119.html](https://gcc.gnu.org/pipermail/gcc/2020-November/234119.html)
