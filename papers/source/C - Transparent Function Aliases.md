---
title: Transparent Function Aliases
date: April 29th, 2021
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



## Revision 0 - April 26th, 2021

- Initial release.




# Introduction

After at least 3 papers were burned through attempting to [solve the intmax_t problem](https://thephd.github.io/intmax_t-hell-c++-c), a number of issues were unearthed with each individual solution[^N2465][^N2498][^N2425]. Whether it was having to specifically lift the ban that §7.1.4 places on macros for standard library functions, or having to break the promise that `intmax_t` can keep expanding to fit larger integer types, the Committee and the community at large had a problem providing this functionality.

After Robert Seacord's "Specific-width length modifier" paper was approved for C23[^N2680], we solved one of the primary issues faced with `intmax_t` improvements, which was that there was no way to print out a integral expression with a width greater than `long long`. Seacord's addition to the C standard also prevented a security issue that commonly came from printing incorrectly sized integers as well: there's a direct correlation between the bits of the supported types and the bits of the given in the formatting string now, without having to worry about the type beyond a `sizeof()` check. This solved 1 of the 3 core problems. The other 2 core problems are:

- Library functions in a "very vanilla" implementation of a C standard library have a strong tie between the name of the function (e.g., `imaxabs`) and the symbol present in the final binary (e.g., `_imaxabs`). This symbol is tied to a specific numeric type (e.g., `typedef long long intmax_t`), and upgrading that type breaks old binaries.
- Macros cannot be used to "smooth" over the "real function call" because §7.1.4 specifically states that 



## Motivation

The 


# Reference

[^N2680]: Seacord, Robert. Specific-width length modifier. ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2680.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2680.pdf).  
[^N2465]: Seacord, Robert. intmax t, a way forward. ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2465.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2465.pdf)  
[^N2498]: Uecker, Martin. intmax_t, again. ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf)  
[^N2425]: Gustedt, Jens. intmax_t, a way out v.2. ISO/IEC JTC1 SC22 WG14 - Programming Languages C. [http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf](http://www.open-std.org/jtc1/sc22/wg14/www/docs/n2498.pdf)  
