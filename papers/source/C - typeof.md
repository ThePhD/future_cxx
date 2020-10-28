---
title: Not-So-Magic - typeof(...) in C
layout: page
date: October 26th, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
redirect_from:
  - /vendor/future_cxx/papers/source/n2593.html
hide: true
---

<style>
pre {
  margin-top: 0px;
  margin-bottom: 0px;
}
.ins, ins, ins *, span.ins, span.ins * {
  background-color: rgb(200, 250, 200);
  color: rgb(0, 136, 0);
  text-decoration: underline;
}
.del, del, del *, span.del, span.del * {
  background-color: rgb(250, 200, 200);
  color: rgb(255, 0, 0);
  text-decoration: line-through;
  text-decoration-color: rgb(255, 0, 0);
}
math, span.math {
  font-family: serif;
  font-style: italic;
}
ul {
  list-style-type: "— ";
}
blockquote {
  counter-reset: paragraph;
}
div.numbered, div.newnumbered {
  margin-left: 2em;
  margin-top: 1em;
  margin-bottom: 1em;
}
div.numbered:before, div.newnumbered:before {
  position: absolute;
  margin-left: -2em;
  display-style: block;
}
div.numbered:before {
  content: counter(paragraph);
  counter-increment: paragraph;
}
div.newnumbered:before {
  content: "�";
}
div.numbered ul, div.newnumbered ul {
  counter-reset: list_item;
}
div.numbered li, div.newnumbered li {
  margin-left: 3em;
}
div.numbered li:before, div.newnumbered li:before {
  position: absolute;
  margin-left: -4.8em;
  display-style: block;
}
div.numbered li:before {
  content: "(" counter(paragraph) "." counter(list_item) ")";
  counter-increment: list_item;
}
div.newnumbered li:before {
  content: "(�." counter(list_item) ")";
  counter-increment: list_item;
}
</style>

_**Document**_: n2593  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Compiler/Tooling Developers  
_**Latest Revision**_: [https://thephd.github.io/vendor/future_cxx/papers/source/n2593.html](https://thephd.github.io/vendor/future_cxx/papers/source/n2593.html)

<p style="text-align: center">
<span style="font-style: italic; font-weight: bold">Abstract:</span>
<p>Getting the type of an expression in Standard C code.</p>
</p>

<div class="pagebreak"></div>




# Introduction & Motivation

`typeof` is a extension featured in many implementations of the C standard to get the type of an expression. It works similarly to `sizeof`, which runs the expression in an "unevaluated context" to understand the final type, and thusly produce a size. `typeof` stops before producing a byte size and instead just yields a type name, usable in all the places a type currently is in the C grammar.

There are many uses for `typeof` that have come up over the intervening decades since its first introduction in a few compilers, most notably GCC. It can, for example, help produce a type-safe generic printing function that even has room for user extension (see: https://slbkbs.org/tmp/fmt/fmt.h). It can also help write code that can use the expansion of a macro expression as the return type for a function, or used within a macro itself to correctly cast to the desired result of a specific computation's type (for width and precision purposes). The use cases are vast and endless, and many people have been locking themselves into implementation-specific vendorship that have locked them out of other compilers (for example, Microsoft's Visual C Compiler).




# Implementation & Existing Practice

Every implementation in existence since C89 has an implementation of `typeof`. Some compilers (GCC, Clang, EDG, tcc, and many, many more) expose this with the implementation extension `typeof`. But, the Standard already requires `typeof` to exist. Notably, with underlined emphasis added,

> The `sizeof` operator yields the size (in bytes) of its operand, which may be an expression or the parenthesized name of a type. __The size is determined from the type of the operand.__
> — [N2573, §6.5.3.4 The `sizeof` and `_Alignof` operators, Semantics](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf)

Any implementation that can process `sizeof("foo")` is already doing `sizeof(typeof("foo"))` internally. This feature is the most "existing practice"-iest feature to be proposed to the C Standard, possibly in the entire history of the C standard.

Furthermore, [putting a type or a VLA-type computation results in an idempotent](https://godbolt.org/z/3hqr6x) type computation that simply yields that type in most implementations that support the feature.




# Wording

The following wording is relative to [N2573](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2573.pdf).

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
