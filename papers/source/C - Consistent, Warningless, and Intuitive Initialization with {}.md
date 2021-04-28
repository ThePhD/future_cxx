---
title: Consistent, Warningless, and Intuitive Initialization with {} | r0
date: April 12th, 2021
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
layout: paper
hide: true
---

_**Document**_: n26XX  
_**Previous Revisions**_: None  
_**Audience**_: WG14  
_**Proposal Category**_: Change Request, Feature Request  
_**Target Audience**_: General Developers, Library Developers  
_**Latest Revision**_: [https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Consistent,%20Warningless,%20and%20Intuitive%20Initialization%20with%20%7B%7D.html](https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20Consistent,%20Warningless,%20and%20Intuitive%20Initialization%20with%20%7B%7D.html)

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

The use of `{ 0 }` to initialize structures, unions, and arrays is a long-standing pillar of C. But, for a long time it has caused some confusion amongst developers. Whether it was initializing arrays of integers and using `{ 1 }` and thinking it would initialize all integers with the value `1` (and being wrong), or getting warnings on some implementations for complicated structures and designated initializers that did not initialize every element, the usage of `{ 0 }` has caused quite a bit of confusion.

Furthermore, this has created great confusion about how initializers are supposed to work. Is the `0` the special element that initializes everything to be `0`? For example, some people will initialize the below given structure as follows and have the following expectations after initialization:

```cpp

```

This is also a longstanding compatibility risk with C++, where shared header code that relies on `= {}`, thinking it is viable C code, find out that its not allowed. This is the case with GCC, where developers, [even as recent as April 6th, 2021](), say things like:

> today i learned.  gcc allows this, i’ve used it for years!

Indeed, the use is so ubiquitous that most compilers allow it as an extension and do so quietly until warning level and pedantic checkers are turned on for most compilers and static analyzers! Thankfully for this proposal, every compiler deploying this extension applies the same initialization behavior; perform the identical behavior of static initialization for every active sub-object/element of the scalar/struct/union.



## Static Initialization

