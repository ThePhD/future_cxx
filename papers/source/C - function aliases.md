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
This paper attempts to solve 2 intrinsic problems with Library Development in C, including its Standard Library. The first is the ability to have type definitions that are just aliases without functions that can do the same. The second is ABi issues resulting from the inability to provide a small, invisible indirection layer.
</p>
<p>
This proposal provides a simple, no-cost way to indirect a function's identifier from the actual called function, opening the door to a C Standard Library that can be implemented without fear of backwards compatibility/ABI problems. It also enables general developers to upgrade their libraries seamlessly and without interruption. 
</p>
</div>

<div class="pagebreak"></div>




# Changelog



## Revision 0 - February 27th, 2020

- Initial release.




# Introduction

After at least 3 papers were burned through attempting to [solve the intmax_t problem](https://thephd.github.io/intmax_t-hell-c++-c)[^N2465][^N2498][^N2425], a number of issues were unearthed with each individual solution. Whether it was having to specifically lift the ban that § places on macros for standard library functions, or having to break the promise that `intmax_t` can keep expanding to fit larger integer types, we always had issues.



## Motivation


