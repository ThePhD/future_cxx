---
title: Not-So-Magic - typeof(...) in C
date: October 26th, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd (Shepherd's Oasis) \<<shepherd@soasis.org>\>
layout: paper
redirect_from:
  - /vendor/future_cxx/papers/source/n2593.html
  - /vendor/future_cxx/papers/source/n26X1.html
hide: true
---

_**Document**_: n26XX  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Compiler/Tooling Developers  
_**Latest Revision**_: [https://thephd.github.io/vendor/future_cxx/papers/source/n2593.html](https://thephd.github.io/vendor/future_cxx/papers/source/n2593.html)

<div class="text-center">
<h6>Abstract:</h6>
<p>
Getting the type of an expression in Standard C code.
</p>
</div>

<div class="pagebreak"></div>




# Introduction & Motivation

`typeof` is a extension featured in many implementations of the C standard to get the type of an expression. It works similarly to `sizeof`, which runs the expression in an "unevaluated context" to understand the final type, and thusly produce a size. `typeof` stops before producing a byte size and instead just yields a type name, usable in all the places a type currently is in the C grammar.

There are many uses for `typeof` that have come up over the intervening decades since its first introduction in a few compilers, most notably GCC. It can, for example, help produce a type-safe generic printing function that even has room for user extension (see: https://slbkbs.org/tmp/fmt/fmt.h). It can also help write code that can use the expansion of a macro expression as the return type for a function, or used within a macro itself to correctly cast to the desired result of a specific computation's type (for width and precision purposes). The use cases are vast and endless, and many people have been locking themselves into implementation-specific vendorship that have locked them out of other compilers (for example, Microsoft's Visual C Compiler).




# Implementation & Existing Practice

Every implementation in existence since C89 has an implementation of `typeof`. Some compilers (GCC, Clang, EDG, tcc, and many, many more) expose this with the implementation extension `typeof`. But, the Standard already requires `typeof` to exist. Notably, with emphasis (not found in the standard) added:

> The `sizeof` operator yields the size (in bytes) of its operand, which may be an expression or the parenthesized name of a type. **The size is determined from the type of the operand.**
> — [N2573, Programming Languages C - Working Draft, §6.5.3.4 The `sizeof` and `_Alignof` operators, Semantics](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf)

Any implementation that can process `sizeof("foo")` is already doing `sizeof(typeof("foo"))` internally. This feature is the most "existing practice"-iest feature to be proposed to the C Standard, possibly in the entire history of the C standard.

Furthermore, [putting a type or a VLA-type computation results in an idempotent](https://godbolt.org/z/3hqr6x) type computation that simply yields that type in most implementations that support the feature.




# Wording

The following wording is relative to [N2573](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf).

**Add a keyword to the §6.4.1 Keywords**

<blockquote>
<p>
&emsp; &emsp; <b><code>_Thread_local</code></b><br/>
<ins>&emsp; &emsp; <b><code>_Typeof</code></b></ins><br/>
</p>
</blockquote>


**Adjust the Syntax grammar of §6.7.2 Type specifiers**

<blockquote>
<p>
<i>type-specifier</i>:<br/>
&emsp; &emsp; <b><code>void</code></b><br/>
&emsp; &emsp; ...<br/>
&emsp; &emsp; <i>typedef-name</i><br/>
<ins>&emsp; &emsp; <i>typeof-specifier</i></ins>
</p>
</blockquote>


**Add a new §6.7.2.5 The Typeof specifier**

<blockquote>
<ins>
<p><h3><b>§6.7.2.5 &emsp; &emsp; The Typeof specifier</b></h3></p>

<p><h4><b>Syntax</b></h4></p>

<div class="numbered">
<p>
<i>typeof-specifier</i>:<br/>
&emsp; &emsp; <code><b>_Typeof</b></code> <i>unary-expression</i><br/>
&emsp; &emsp; <code><b>_Typeof</b></code> <b>(</b> <i>type-name</i> <b>)</b>
</p>
</div>

<p><h4><b>Constraints</b></h4></p>

<div class="numbered">
<p>The <i>typeof-specifier</i> shall not be applied to an expression that has function type or an incomplete type, to the parenthesized name of such a type, or to an expression that designates a bit-field member.</p>
</div>

<p><h4><b>Semantics</b></h4></p>

<div class="numbered">
<p>The <i>typeof-specifier</i> applies the <code><b>_Typeof</b></code> operator to a <i>unary-expression</i> (6.5.3) or a <i>type-specifier</i>. If the <code><b>_Typeof</b></code> operator is applied to a <i>unary-expression</i>, it yields the <i>type-name</i> representing the type of its operand<sup>11�0)</sup>. Otherwise, it produces the <i>type-name</i> with any nested <i>typeof-specifier</i> evaluated <sup>11�1)</sup>. If the type of the operand is a variable length array type, the operand are evaluated; otherwise, the operand is not evaluated.</p>
</div>

<div class="numbered">
<p>Type qualifiers (6.7.3) of the type from the result of a <code><b>_Typeof</b></code> operation are preserved.</p>
</div>

<p><sup>11�0)</sup><sub> When applied to a parameter declared to have array or function type, the <code><b>_Typeof</b></code> operator yields the adjusted (pointer) type (see 6.9.1).</sub></p>
<p><sup>11�1)</sup><sub> If the operand is a <code><b>_Typeof</b></code> operator, the operand will be evaluated before evaluating the current <code>_Typeof</code> operation. This happens recursively until a <i>typeof-specifier</i> is no longer the operand.</sub></p>
</ins>
</blockquote>

**Add the following examples to the new Typeof section**

> <ins><sup>5</sup> **EXAMPLE 1** Type of an expression.<br/></ins>
> 
> <ins>The following program:</ins>
> 
> > ```c
> > _Typeof(1) main () {
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
> 
> <ins><sup>6</sup> **EXAMPLE 2** Equivalence of `sizeof` and `typeof`.</ins>
> 
> > ```c
> > int main (int argc, char* argv[]) {
> > 	// this program has no constraint violations
> > 	_Static_assert(sizeof(_Typeof('p')) == sizeof(char));
> > 	_Static_assert(sizeof(_Typeof('p')) == sizeof('p'));
> > 	_Static_assert(sizeof(_Typeof("meow")) == sizeof(char[5]));
> > 	_Static_assert(sizeof(_Typeof("meow")) == sizeof("meow"));
> > 	_Static_assert(sizeof(_Typeof(argc)) == sizeof(int));
> > 	_Static_assert(sizeof(_Typeof(argc)) == sizeof(argc));
> > 	_Static_assert(sizeof(_Typeof(argv)) == sizeof(char**));
> > 	_Static_assert(sizeof(_Typeof(argv)) == sizeof(argv));
> > 	return 0;
> > }
> > ```
> 
> <ins><sup>7</sup> **EXAMPLE 3** Nested `_Typeof(...)`.</ins>
> 
> > ```c
> > int main (int argc, char*[]) {
> > 	float val = 6.0f;
> > 	// equivalent to a cast and return
> > 	return (_Typeof(_Typeof(_Typeof(argc))))val;
> > 	// return (int)val;
> > }
> > ```
> 
> <ins><sup>8</sup> **EXAMPLE 4** Variable Length Arrays and `_Typeof`.</ins>
> 
> > ```c
> > #include <stddef.h>
> > 
> > size_t vla_size (int n) {
> > 	typedef char vla_type[n + 3];
> > 	vla_type b; // variable length array
> > 	return sizeof(
> > 		_Typeof(b)
> > 	); // execution-time sizeof, translation-time _Typeof
> > }
> > 
> > int main () {
> > 	return (int)vla_size(10); // vla_size returns 13
> > }
> > ```


**Modify §6.3.2.1 Lvalues, arrays, and function designators, paragraphs 3 and 4 with footnote 68**

<blockquote>
<div class="numbered numbered-3">
<p>Except when it is the operand of the <del><b><code>sizeof</code></b> operator</del><ins><b><code>sizeof</code></b> or <b><code>_Typeof</code></b> operators</ins>, or the unary <code>&</code> operator, or is a string literal used to initialize an array, an expression that has type "array of <i>type</i>" is converted to an expression with type "pointer to <i>type</i>" that points to the initial element of the array object and is not an lvalue. If the array object has register storage class, the behavior is undefined.</p>
</div>
<div class="numbered numbered-4">
<p>A <i>function designator</i> is an expression that has function type. Except when it is the operand of the <del><b><code>sizeof</b></code> operator</del><ins><b><code>sizeof</code></b> operator, the <b><code>_Typeof</code></b> operator</ins><sup>68)</sup>or the unary <code>&</code> operator, a function designator with type "function returning <i>type</i>" is converted to an expression that has type "pointer to function returning <i>type</i>".</p>
</div>

<div><sub><sup>68)</sup>Because this conversion does not occur, the operand of the <del><b><code>sizeof</b></code> operator</del><ins><b><code>sizeof</code></b> and <b><code>_Typeof</code></b> operators</ins> remains a function designator and violates the constraints in 6.5.3.4.</sub>
</blockquote>


**Modify §6.6 Constant expressions, paragraphs 6 and 8**

<blockquote>
<div class="numbered numbered-6">
<p>An integer constant expression<sup>125)</sup> shall have integer type and shall only have operands that are integer constants, enumeration constants, character constants, <code><b>sizeof</b></code> expressions whose results are integer constants, <code><b>_Alignof</b></code> expressions, and floating constants that are the immediate operands of casts. Cast operators in an integer constant expression shall only convert arithmetic types to integer types, except as part of an operand to the <del><code><b>sizeof</b></code></del><ins><code><b>_Typeof</b></code>, <code><b>sizeof</b></code>,</ins> or <code><b>_Alignof</b></code> operator.</p>
</div>

<p>...</p>

<div class="numbered numbered-8">
<p>An arithmetic constant expression shall have arithmetic type and shall only have operands that are integer constants, floating constants, enumeration constants, character constants,<code><b>sizeof</b></code> expressions whose results are integer constants, and <code><b>_Alignof</b></code> expressions. Cast operators in an arithmetic constant expression shall only convert arithmetic types to arithmetic types, except as part of an operand to a <del><code><b>sizeof</b></code></del><ins><code><b>_Typeof</b></code>, <code><b>sizeof</b></code>,</ins> or <code><b>_Alignof</b></code> operator.</p>
</div>
</blockquote>


**Modify §6.7.6.2 Array declarators, paragraph 5**

<blockquote>
<div class="numbered numbered-5">
<p>If the size is an expression that is not an integer constant expression: if it occurs in a declaration at function prototype scope, it is treated as if it were replaced by <code>*</code>; otherwise, each time it is evaluated it shall have a value greater than zero. The size of each instance of a variable length array type does not change during its lifetime. Where a size expression is part of the operand of a <ins><code><b>_Typeof</b></code> or</ins><code><b>sizeof</b></code> operator and changing the value of the size expression would not affect the result of the operator, it is unspecified whether or not the size expression is evaluated. Where a size expression is part of the operand of an <code><b>_Alignof</b></code> operator, that expression is not evaluated.</p>
</div>
</blockquote>


**Modify §6.9 External definitions, paragraphs 3 and 5**

<blockquote>
<div class="numbered numbered-3">
<p>There shall be no more than one external definition for each identifier declared with internal linkage in a translation unit. Moreover, if an identifier declared with internal linkage is used in an expression(other than as a part of the operand of a <del><code><b>sizeof</b></code></del><ins><code><b>_Typeof</b></code>, <code><b>sizeof</b></code>,</ins> or <code><b>_Alignof</b></code> operator whose result is an integer constant), there shall be exactly one external definition for the identifier in the translation unit.</p>
</div>

<p>...</p>

<div class="numbered numbered-5">
<p>An <i>external definition</i> is an external declaration that is also a definition of a function (other than an inline definition) or an object. If an identifier declared with external linkage is used in an expression (other than as a part of the operand of a <del><code><b>sizeof</b></code></del><ins><code><b>_Typeof</b></code>, <code><b>sizeof</b></code>,</ins> or <code><b>_Alignof</b></code> operator whose result is an integer constant), somewhere in the entire program there shall be exactly one external definition for the identifier; otherwise, there shall be no more than one.<sup>173)</sup></p>
</div>
</blockquote>


**Add a new §7.� Typeof `<stdtypeof.h>`**

<blockquote>
<ins>
<div class="numbered">
<p>The header <code>&lt;stdtypeof.h&gt;</code> defines two macros.</p>
</div>

<div class="numbered">
<p>The macro</p>
<p>
<blockquote>
<code>typeof</code>
</blockquote>
</p>
<p>expands to <code><b>_Typeof</b></code>.</p>
</div>

<div class="numbered">
<p>The macro</p>
<p>
<blockquote>
<code>__typeof_is_defined</code>
</blockquote>
</p>
<p>is suitable for use in <code><b>#if</b></code> preprocessing directives. It expands to the integer constant <code>1</code>.</p>
</div>
</ins>
</blockquote>
