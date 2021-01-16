---
title: Function Aliases
date: December 1st, 2020
author:
  - JeanHeyd Meneide \<<phdofthehouse@gmail.com>\>
  - Shepherd \<<shepherd@soasis.org>\>
layout: paper
hide: true
---

_**Document**_: WG14 n26XX  
_**Previous Revisions**_: None  
_**Audience**_: WG14, WG21  
_**Proposal Category**_: New Features  
_**Target Audience**_: General Developers, Library Developers, Long-Life Upgradable Systems Developers  
_**Latest Revision**_: [https://thephd.github.io/_vendor/future_cxx/papers/C%20-%20function%20aliases.html](https://thephd.github.io/_vendor/future_cxx/papers/C%20function%20aliases.html)

<div class="pagebreak"></div>

<div class="text-center">
<h6>Abstract:</h6>
<p>
Pulling binary data into a program often involves external tools and build system coordination. Many programs need binary data such as images, encoded text, icons and other data in a specific format. Current state of the art for working with such static data in C includes creating files which contain solely string literals, directly invoking the linker to create data blobs to access through carefully named extern variables, or generating large brace-delimited lists of integers to place into arrays. As binary data has grown larger, these approaches have begun to have drawbacks and issues scaling. From parsing 5 megabytes worth of integer literal expressions into AST nodes to arbitrary string literal length limits in compilers, portably putting binary data in a C program has become an arduous task that taxes build infrastructure and compilation memory and time.
</p>
<p>
This proposal provides a flexible preprocessor directive for making this data available to the user in a straightforward manner.
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 0 - December 27th, 2020

- Initial release.




# Introduction

After at least 3 papers were burned through attempting to [solve the intmax_t problem](https://thephd.github.io/intmax_t-hell-c++-c)[^N2465][^N2498][^N2425], a number of issues were unearthed with each individual solution.



## Motivation


