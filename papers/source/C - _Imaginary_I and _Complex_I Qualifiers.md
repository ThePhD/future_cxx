---
title: _Imaginary_I and _Complex_I Qualifiers | r0
date: February 26th, 2021
author:
  - JeanHeyd Meneide \<<wg14@soasis.org>\>
layout: paper
hide: true
---

_**Document**_: n26XX  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Compiler/Tooling Developers  
_**Latest Revision**_: [https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20_Imaginary_I%20and%20_Complex_I%20Qualifiers.html](https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20_Imaginary_I%20and%20_Complex_I%20Qualifiers.html)

<div class="text-center">
<h6>Abstract:</h6>
<p>
This paper fixes some strange qualifiers on imaginary and complex macro expressions leftover from C99.
</p>
</div>

<div class="pagebreak"></div>




# Introduction & Motivation

It was noted in discussion around the Typeof papers that `_Complex_I` and `_Imaginary_I` both are specifically expanded to a `const` r-value, which seems strangely specified considering almost no other macro expansions are like this. Digging into archives failed to yield any particularly enlightening reasoning for this constant, of all the constants, was marked as `const` particular. The constants were introduced in C99, and have always been `const` qualified.

Because it may become possible to observe types in the (very near) future, we should remove the `const` qualification from these macro productions. Current analysis indicates that this should affect no code, as all current generic facilities perform l-value conversion and the type of these macros are expressions (r-values), and thusly cannot have their address taken directly to expose it.




# Wording

The following wording is relative to [N2596](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2596.pdf).

**Remove `const` from 7.3.1 paragraph 4 and 5**

<blockquote>
<p><sup>4</sup> ...; the macro

> ```cpp
>      _Complex_I
> ```

expands to a constant expression of type <del><b>const float _Complex</b></del><ins><b>float _Complex</b></ins>, with the value of the imaginary unit.
</blockquote>

<blockquote>
<p><sup>5</sup> The macros

> ```cpp
> imaginary
> ```

and

> ```cpp
> _Imaginary_I
> ```

are defined if and only if the implementation supports imaginary types;<sup>210)</sup> if defined, they expand to `_Imaginary` and a constant expression of type <del><b>const float _Imaginary</b></del><ins><b>float _Imaginary</b></ins> with the value of the imaginary unit.
</blockquote>


**Remove `const` from G.6 paragraph 1**

<blockquote>
<p><sup>1</sup> ... <br/>

... are defined, respectively, as <b>_Imaginary</b> and a constant expression of type <del><b>const float _Imaginary</b></del><ins><b>float _Imaginary</b></ins> with the value of the imaginary unit.</p>
</blockquote>